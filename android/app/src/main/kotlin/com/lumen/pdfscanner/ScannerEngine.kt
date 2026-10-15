package com.lumen.pdfscanner

import android.app.Activity
import android.content.Intent
import android.graphics.*
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.Normalizer
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.*

/** File-backed pipeline. Raster workers are serial and never cross the Dart bridge. */
class ScannerEngine(private val activity: Activity, messenger: BinaryMessenger): MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val channel = MethodChannel(messenger, "com.lumen.pdfscanner/engine")
    private val eventChannel = EventChannel(messenger, "com.lumen.pdfscanner/progress")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val prefs = activity.getSharedPreferences("lumen",0)
    private val root = File(activity.filesDir,"lumen").apply { mkdirs() }
    private val cancelled = AtomicBoolean(false)
    private var sink: EventChannel.EventSink? = null
    private var pending: MethodChannel.Result? = null
    @Volatile private var exporting = false
    init { channel.setMethodCallHandler(this); eventChannel.setStreamHandler(this) }
    override fun onListen(args: Any?, events: EventChannel.EventSink?) {sink=events}
    override fun onCancel(args: Any?) {sink=null}
    fun close() {cancelled.set(true); pending?.error("cancelled",null,null);pending=null;channel.setMethodCallHandler(null);eventChannel.setStreamHandler(null);worker.shutdown()}
    private fun success(r: MethodChannel.Result,v:Any?) {main.post {r.success(v)}}
    private fun error(r: MethodChannel.Result,e:Throwable) {
        val code=when { e is Failure->e.code; e is SecurityException->"folder"; e is OutOfMemoryError->"memory"; e is java.io.FileNotFoundException->"missing"; e.message?.contains("ENOSPC")==true->"storage"; else->"operation" }
        main.post {r.error(code,null,null)}
    }
    private class Failure(val code:String):Exception()
    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall,r: MethodChannel.Result) {
        val a=(call.arguments as? Map<String,Any?>) ?: emptyMap()
        if(call.method=="cancel") {cancelled.set(true);r.success(null);return}
        if(call.method=="scan") {scan((a["limit"] as Number).toInt(),r);return}
        if(call.method=="chooseFolder") {chooseFolder(r);return}
        if(call.method=="export" && exporting) {r.error("busy",null,null);return}
        if(call.method=="export") {exporting=true;cancelled.set(false)}
        worker.execute {
            try {
                val value:Any?=when(call.method) {
                    "initialise" -> initialise()
                    "privateFolder" -> {prefs.edit().remove("tree").apply();location()}
                    "stage" -> stage(a["session"] as String,a["paths"] as List<String>)
                    "preview" -> preview(a)
                    "export" -> export(a)
                    "discard", "acknowledge" -> {session(a["session"] as String).deleteRecursively();null}
                    "open","share" -> {share(a,call.method=="share");null}
                    "pdfPage" -> pdfPage(a)
                    "rename" -> rename(a)
                    "delete" -> {delete(a);null}
                    "usage" -> usage()
                    "cleanCache" -> {File(root,"previews").deleteRecursively();File(activity.cacheDir,"shares").deleteRecursively();null}
                    else -> throw Failure("unsupported")
                }
                success(r,value)
            } catch(e:Throwable) {error(r,e)}
            finally {if(call.method=="export") exporting=false}
        }
    }
    private fun safeId(id:String):String {if(!Regex("[A-Za-z0-9-]{1,64}").matches(id)) throw Failure("invalid");return id}
    private fun session(id:String)=File(root,"drafts/${safeId(id)}").apply {mkdirs()}
    private fun checked(path:String):File {
        val file=File(path).canonicalFile
        if(!file.path.startsWith(root.canonicalPath+File.separator)) throw Failure("invalid")
        return file
    }
    private fun location():String = prefs.getString("tree",null)?.let {"Selected local folder · PDF Scanner"} ?: "App storage · PDF Scanner"
    private fun privateRoot()=File(activity.getExternalFilesDir(null) ?: activity.filesDir,"PDF Scanner").apply {mkdirs()}
    private fun initialise():Map<String,Any?> {
        privateRoot();File(root,"receipts").mkdirs()
        // Interrupted jobs publish into their own pending directory. Roll back
        // journalled handles when no commit receipt exists.
        File(root,"jobs").listFiles()?.forEach {job->
            val receipt=File(root,"receipts/${job.name}.json")
            var clean=true
            if(!receipt.exists()) {
                val journal=File(job,"published.json")
                if(journal.exists()) {
                    clean=runCatching { JSONArray(journal.readText()).let { j-> for(i in 0 until j.length()) removeUri(j.getString(i)) } }.isSuccess
                }
            }
            // Keep the recovery journal if a provider is still disconnected.
            if(clean)job.deleteRecursively()
        }
        val receipts=File(root,"receipts").listFiles()?.filter {it.extension=="json"}?.mapNotNull {
            runCatching {jsonMap(JSONObject(it.readText()))}.getOrNull()
        } ?: emptyList()
        return mapOf("location" to location(),"receipts" to receipts)
    }
    private fun scan(limit:Int,r:MethodChannel.Result) {
        if(pending!=null) {r.error("busy",null,null);return}
        pending=r
        val options=GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(false)
            .setPageLimit(limit.coerceIn(1,50)).setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener {sender->
                try {activity.startIntentSenderForResult(sender,701,null,0,0,0)}
                catch(e:Exception) {pending=null;r.error("unsupported",null,null)}
            }.addOnFailureListener {pending=null;r.error("unsupported",null,null)}
    }
    private fun chooseFolder(r:MethodChannel.Result) {
        if(pending!=null || exporting) {r.error("busy",null,null);return}
        pending=r
        val intent=Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        activity.startActivityForResult(intent,702)
    }
    fun activityResult(code:Int,result:Int,data:Intent?):Boolean {
        if(code!=701 && code!=702) return false
        val r=pending ?: return true;pending=null
        if(result!=Activity.RESULT_OK || data==null) {r.error("cancelled",null,null);return true}
        try {
            if(code==701) {
                val pages=GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages ?: emptyList()
                r.success(pages.map {it.imageUri.toString()})
            } else {
                val uri=data.data ?: throw Failure("folder")
                // The core product promises on-device storage. Cloud document
                // providers can appear in the picker; do not label them local.
                if(uri.authority!="com.android.externalstorage.documents")throw Failure("localFolder")
                activity.contentResolver.takePersistableUriPermission(uri,data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                val selected=DocumentFile.fromTreeUri(activity,uri) ?: throw Failure("folder")
                if(!selected.canWrite()) throw Failure("folder")
                val folder=if(selected.name=="PDF Scanner") selected else selected.findFile("PDF Scanner") ?: selected.createDirectory("PDF Scanner") ?: throw Failure("folder")
                // Persist the original grant URI separately from the child URI.
                prefs.edit().putString("tree",folder.uri.toString()).putString("grant",uri.toString()).apply()
                r.success(location())
            }
        }catch(e:Throwable) {error(r,e)}
        return true
    }
    private fun input(path:String)= if(path.startsWith("content:")) activity.contentResolver.openInputStream(Uri.parse(path)) ?: throw Failure("missing") else File(Uri.parse(path).path ?: path).inputStream()
    private fun decode(path:String,maxEdge:Int=4096):Bitmap {
        val b=BitmapFactory.Options().apply {inJustDecodeBounds=true}
        input(path).use {BitmapFactory.decodeStream(it,null,b)}
        if(b.outWidth<=0 || b.outHeight<=0 || b.outWidth.toLong()*b.outHeight>400_000_000L) throw Failure("unsupported")
        var sample=1
        while(max(b.outWidth,b.outHeight)/sample>maxEdge) sample*=2
        val opts=BitmapFactory.Options().apply {inSampleSize=sample;inPreferredConfig=Bitmap.Config.ARGB_8888}
        return input(path).use {BitmapFactory.decodeStream(it,null,opts)} ?: throw Failure("unsupported")
    }
    private fun jpeg(bitmap:Bitmap,file:File,quality:Int=92) {file.parentFile?.mkdirs();file.outputStream().use {if(!bitmap.compress(Bitmap.CompressFormat.JPEG,quality,it)) throw Failure("write")}}
    private fun stage(id:String,paths:List<String>):List<Map<String,Any?>> {
        if(paths.size>50) throw Failure("limit")
        val dir=session(id);val staged=mutableListOf<Map<String,Any?>>()
        try {for(path in paths) {
            var b=decode(path)
            val orientation=input(path).use {runCatching {ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION,1)}.getOrDefault(1)}
            val matrix=Matrix()
            when(orientation) {
                2->matrix.setScale(-1f,1f);3->matrix.setRotate(180f);4->matrix.setScale(1f,-1f)
                5->{matrix.setRotate(90f);matrix.postScale(-1f,1f)};6->matrix.setRotate(90f)
                7->{matrix.setRotate(270f);matrix.postScale(-1f,1f)};8->matrix.setRotate(270f)
            }
            if(!matrix.isIdentity) {val next=Bitmap.createBitmap(b,0,0,b.width,b.height,matrix,true);if(next!==b)b.recycle();b=next}
            try {
                val page=UUID.randomUUID().toString();val file=File(dir,"$page.jpg");val thumb=File(dir,"$page-thumb.jpg")
                jpeg(b,file,95);val scale=256.0/max(b.width,b.height);val small=Bitmap.createScaledBitmap(b,max(1,(b.width*scale).toInt()),max(1,(b.height*scale).toInt()),true)
                try {jpeg(small,thumb,82)} finally {if(small!==b) small.recycle()}
                staged.add(mapOf("id" to page,"path" to file.path,"thumb" to thumb.path,"width" to b.width,"height" to b.height))
            }finally{b.recycle()}
        }}catch(e:Throwable) {staged.forEach {File(it["path"] as String).delete();File(it["thumb"] as String).delete()};throw e}
        return staged
    }
    @Suppress("UNCHECKED_CAST")
    private fun render(p:Map<String,Any?>,edge:Int):Bitmap {
        var b=decode(checked(p["path"] as String).path,edge)
        try {
            val c=(p["corners"] as? List<Number>)?.map {it.toFloat()} ?: listOf(0f,0f,1f,0f,1f,1f,0f,1f)
            if(c.size!=8 || c.any {!it.isFinite() || it<0 || it>1}) throw Failure("invalid")
            var area=0f
            for(i in 0..3) {
                val j=(i+1)%4;val k=(i+2)%4
                val cross=(c[j*2]-c[i*2])*(c[k*2+1]-c[j*2+1])-(c[j*2+1]-c[i*2+1])*(c[k*2]-c[j*2])
                if(cross<=0f)throw Failure("invalid")
                area+=c[i*2]*c[j*2+1]-c[j*2]*c[i*2+1]
            }
            if(area/2<0.02f)throw Failure("invalid")
            fun dist(a:Int,d:Int)=hypot((c[a*2]-c[d*2])*b.width,(c[a*2+1]-c[d*2+1])*b.height)
            val w=max(1,max(dist(0,1),dist(3,2)).roundToInt());val h=max(1,max(dist(0,3),dist(1,2)).roundToInt())
            val src=FloatArray(8) {i-> c[i]*(if(i%2==0)b.width else b.height)}
            val dst=floatArrayOf(0f,0f,w.toFloat(),0f,w.toFloat(),h.toFloat(),0f,h.toFloat())
            val transform=Matrix();if(!transform.setPolyToPoly(src,0,dst,0,4)) throw Failure("invalid")
            val corrected=Bitmap.createBitmap(w,h,Bitmap.Config.ARGB_8888)
            Canvas(corrected).apply {drawColor(Color.WHITE);drawBitmap(b,transform,Paint(Paint.FILTER_BITMAP_FLAG))};b.recycle();b=corrected
            val rotation=(p["rotation"] as? Number)?.toInt() ?: 0
            if(rotation%90!=0) throw Failure("invalid")
            if(rotation%360!=0) {val m=Matrix().apply{postRotate(rotation.toFloat())};val next=Bitmap.createBitmap(b,0,0,b.width,b.height,m,true);if(next!==b)b.recycle();b=next}
            val filter=p["filter"] as? String ?: "original"
            if(filter!="original") {
                val cm=ColorMatrix()
                if(filter=="greyscale" || filter=="bw") cm.setSaturation(0f)
                if(filter=="enhanced") cm.set(floatArrayOf(1.15f,0f,0f,0f,8f,0f,1.15f,0f,0f,8f,0f,0f,1.15f,0f,8f,0f,0f,0f,1f,0f))
                val next=Bitmap.createBitmap(b.width,b.height,Bitmap.Config.ARGB_8888)
                Canvas(next).drawBitmap(b,0f,0f,Paint().apply{colorFilter=ColorMatrixColorFilter(cm)});b.recycle();b=next
                if(filter=="bw") binarize(b)
            }
            return b
        }catch(e:Throwable){b.recycle();throw e}
    }
    /** Otsu threshold: true B&W; never presented as adaptive shadow removal. */
    private fun binarize(b:Bitmap) {
        val row=IntArray(b.width);val hist=LongArray(256)
        for(y in 0 until b.height){b.getPixels(row,0,b.width,0,y,b.width,1);for(v in row)hist[Color.red(v)]++}
        val total=b.width.toLong()*b.height;var sum=0.0;for(i in 0..255)sum+=i*hist[i]
        var weight=0L;var partial=0.0;var best=-1.0;var threshold=128
        for(i in 0..254) {weight+=hist[i];if(weight==0L)continue;val rest=total-weight;if(rest==0L)break;partial+=i*hist[i];val diff=partial/weight-(sum-partial)/rest;val score=weight.toDouble()*rest*diff*diff;if(score>best){best=score;threshold=i}}
        for(y in 0 until b.height){b.getPixels(row,0,b.width,0,y,b.width,1);for(x in row.indices)row[x]=if(Color.red(row[x])>threshold)Color.WHITE else Color.BLACK;b.setPixels(row,0,b.width,0,y,b.width,1)}
    }
    private fun preview(p:Map<String,Any?>):String {
        val out=File(checked(p["path"] as String).parentFile,"preview-${UUID.randomUUID()}.jpg");val b=render(p,1024)
        try{jpeg(b,out,85)}finally{b.recycle()};return out.path
    }
    private fun tree():DocumentFile? {
        val uri=prefs.getString("grant",null) ?: return null
        if(prefs.getString("tree",null)==null) return null
        val selected=DocumentFile.fromTreeUri(activity,Uri.parse(uri)) ?: throw Failure("folder")
        val folder=if(selected.name=="PDF Scanner")selected else selected.findFile("PDF Scanner") ?: throw Failure("folder")
        if(!folder.exists() || !folder.canWrite()) throw Failure("folder")
        return folder
    }
    private fun dir(base:DocumentFile,path:String):DocumentFile {
        var current=base
        for(part in path.split('/')) current=current.findFile(part) ?: current.createDirectory(part) ?: throw Failure("folder")
        return current
    }
    private fun publish(source:File,subdir:String,name:String,mime:String,published:MutableList<String>,job:File):String {
        checkCancelled()
        val folder=tree()
        val uri=if(folder!=null) {
            val parent=dir(folder,subdir)
            var candidate=name;var n=2
            while(parent.findFile(candidate)!=null) {candidate="${name.substringBeforeLast('.')}__${n++}.${name.substringAfterLast('.')}"}
            val target=parent.createFile(mime,candidate) ?: throw Failure("folder")
            val value=target.uri.toString();published.add(value);journal(job,published)
            activity.contentResolver.openOutputStream(target.uri,"w")?.use {o->source.inputStream().use{it.copyTo(o)}} ?: throw Failure("folder")
            value
        } else {
            val parent=File(privateRoot(),subdir).apply{mkdirs()};var target=File(parent,name);var n=2
            while(!target.createNewFile()) target=File(parent,"${name.substringBeforeLast('.')}__${n++}.${name.substringAfterLast('.')}")
            val value=Uri.fromFile(target).toString();published.add(value);journal(job,published)
            source.inputStream().use {i->target.outputStream().use{i.copyTo(it)}};value
        }
        return uri
    }
    private fun journal(job:File,published:List<String>) {File(job,"published.json").writeText(JSONArray(published).toString())}
    private fun checkCancelled(){if(cancelled.get())throw Failure("cancelled")}
    private fun progress(phase:String,done:Int,total:Int){main.post{sink?.success(mapOf("phase" to phase,"completed" to done,"total" to total))}}
    @Suppress("UNCHECKED_CAST")
    private fun export(a:Map<String,Any?>):Map<String,Any?> {
        val id=safeId(a["id"] as String)
        val committed=File(root,"receipts/$id.json")
        if(committed.exists())return jsonMap(JSONObject(committed.readText()))
        val pages=a["pages"] as List<Map<String,Any?>>
        if(pages.isEmpty() || pages.size>50)throw Failure("limit")
        val job=File(root,"jobs/$id")
        val prior=File(job,"published.json")
        if(prior.exists()) {
            val old=JSONArray(prior.readText());for(i in 0 until old.length())removeUri(old.getString(i))
            job.deleteRecursively()
        }
        job.mkdirs();File(job,"request.json").writeText(JSONObject(a).toString())
        val published=mutableListOf<String>();val imageUris=mutableListOf<String>()
        val file=File(job,"output.pdf");val pdf=JpegPdfWriter(file,pages.size,stem(a["title"] as String))
        val dpi=(a["dpi"] as Number).toInt().coerceIn(100,300)
        val quality=(a["quality"] as Number).toInt().coerceIn(50,98)
        val margin=(a["margin"] as Number).toDouble()*72/25.4
        try {
            for((index,p) in pages.withIndex()) {
                checkCancelled();progress("Processing pages",index,pages.size)
                val b=render(p,min(4096,ceil(11.7*dpi).toInt()))
                try {
                    var w=if(a["format"]=="letter")612.0 else 595.28;var h=if(a["format"]=="letter")792.0 else 841.89
                    if(a["format"]=="fit"){w=b.width*72.0/dpi;h=b.height*72.0/dpi}
                    else if(a["landscape"]==true){val temp=w;w=h;h=temp}
                    val effectiveMargin=if(a["format"]=="fit")0.0 else margin
                    val img=File(job,"page-${index+1}.jpg");jpeg(b,img,quality)
                    pdf.addPage(img,b.width,b.height,w,h,effectiveMargin)
                    if(a["saveImages"]==true)imageUris.add(publish(img,"Images/Processed/$id","page-${(index+1).toString().padStart(3,'0')}.jpg","image/jpeg",published,job))
                    img.delete()
                }finally{b.recycle()}
                if(a["keepOriginals"]==true)imageUris.add(publish(checked(p["path"] as String),"Images/Originals/$id","page-${(index+1).toString().padStart(3,'0')}.jpg","image/jpeg",published,job))
                progress("Processing pages",index+1,pages.size)
            }
            checkCancelled();progress("Writing PDF",pages.size,pages.size)
            pdf.finish()
        }catch(e:Throwable){published.forEach{runCatching{removeUri(it)}};throw e}
        finally{pdf.close()}
        try {
            checkCancelled();progress("Checking PDF",pages.size,pages.size)
            ParcelFileDescriptor.open(file,ParcelFileDescriptor.MODE_READ_ONLY).use{fd->PdfRenderer(fd).use{reader->
                if(reader.pageCount!=pages.size)throw Failure("verify")
                for(i in pages.indices){reader.openPage(i).use {page->val check=Bitmap.createBitmap(32,32,Bitmap.Config.ARGB_8888);try{page.render(check,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)}finally{check.recycle()}}}
            }}
            progress("Saving to your folder",pages.size,pages.size)
            val title=stem(a["title"] as String)
            val uri=publish(file,"PDFs","$title.pdf","application/pdf",published,job)
            checkCancelled()
            // Verify the final destination, not just staging.
            activity.contentResolver.openFileDescriptor(Uri.parse(uri),"r")!!.use{fd->PdfRenderer(fd).use{if(it.pageCount!=pages.size)throw Failure("verify")}}
            val thumb=File(root,"thumbs/$id.jpg");thumb.parentFile?.mkdirs();checked(pages.first()["thumb"] as String).copyTo(thumb,true)
            val receipt=mapOf("id" to id,"session" to a["session"],"title" to title,"uri" to uri,"thumb" to thumb.path,"pages" to pages.size,"bytes" to file.length(),"createdAt" to a["createdAt"],"location" to location(),"images" to imageUris)
            saveReceipt(id,receipt)
            job.deleteRecursively();return receipt
        }catch(e:Throwable){published.forEach{runCatching{removeUri(it)}};throw e}
    }
    private fun stem(s:String)=Normalizer.normalize(s,Normalizer.Form.NFC).replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"),"").trim().trim('.').take(100).ifEmpty{"Scan"}
    private fun saveReceipt(id:String,a:Map<String,Any?>) {
        val dir=File(root,"receipts").apply{mkdirs()};val part=File(dir,"$id.part")
        part.outputStream().use{it.write(JSONObject(a).toString().toByteArray());it.fd.sync()}
        if(!part.renameTo(File(dir,"$id.json")))throw Failure("write")
    }
    private fun jsonMap(j:JSONObject):Map<String,Any?> = j.keys().asSequence().associateWith {key->
        val v=j.get(key);when(v){JSONObject.NULL->null;is JSONObject->jsonMap(v);is JSONArray->(0 until v.length()).map{v.get(it)};else->v}
    }
    private fun share(a:Map<String,Any?>,share:Boolean) {
        val dir=File(activity.cacheDir,"shares").apply{mkdirs()};val copy=File(dir,"${stem(a["title"] as String)}.pdf")
        activity.contentResolver.openInputStream(Uri.parse(a["uri"] as String))?.use {i->copy.outputStream().use{i.copyTo(it)}} ?: throw Failure("missing")
        val uri=FileProvider.getUriForFile(activity,"${activity.packageName}.files",copy)
        val intent=if(share)Intent(Intent.ACTION_SEND).setType("application/pdf").putExtra(Intent.EXTRA_STREAM,uri)
        else Intent(Intent.ACTION_VIEW).setDataAndType(uri,"application/pdf")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val done=java.util.concurrent.CountDownLatch(1)
        var launchError:Throwable?=null
        main.post {
            try {activity.startActivity(if(share)Intent.createChooser(intent,"Share PDF") else intent)}
            catch(e:Throwable){launchError=e}
            finally{done.countDown()}
        }
        if(!done.await(10,java.util.concurrent.TimeUnit.SECONDS) || launchError!=null)throw Failure("share")
    }
    private fun pdfPage(a:Map<String,Any?>):Map<String,Any?> {
        val fd=activity.contentResolver.openFileDescriptor(Uri.parse(a["uri"] as String),"r") ?: throw Failure("missing")
        fd.use{PdfRenderer(it).use{reader->
            val index=(a["index"] as Number).toInt().coerceIn(0,reader.pageCount-1)
            reader.openPage(index).use{p->
                val scale=1024.0/max(p.width,p.height);val b=Bitmap.createBitmap(max(1,(p.width*scale).toInt()),max(1,(p.height*scale).toInt()),Bitmap.Config.ARGB_8888)
                try{b.eraseColor(Color.WHITE);p.render(b,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);val out=File(root,"previews/pdf-${UUID.randomUUID()}.jpg");jpeg(b,out,85);return mapOf("path" to out.path,"count" to reader.pageCount)}finally{b.recycle()}
            }
        }}
    }
    private fun removeUri(uri:String) {
        val u=Uri.parse(uri)
        if(u.scheme=="file") {val f=File(u.path!!).canonicalFile;if(!f.path.startsWith(privateRoot().canonicalPath+File.separator))throw Failure("invalid");if(f.exists()&&!f.delete())throw Failure("delete")}
        else {val doc=DocumentFile.fromSingleUri(activity,u) ?: throw Failure("missing");if(doc.exists()&&!doc.delete())throw Failure("delete")}
    }
    private fun rename(a:Map<String,Any?>):Map<String,Any?> {
        val uri=Uri.parse(a["uri"] as String);val title=stem(a["newTitle"] as String);val name="$title.pdf"
        val newUri=if(uri.scheme=="file"){
            val from=File(uri.path!!);val target=File(from.parentFile,name);if(target.exists())throw Failure("collision");if(!from.renameTo(target))throw Failure("rename");Uri.fromFile(target).toString()
        } else {
            val file=DocumentFile.fromSingleUri(activity,uri) ?: throw Failure("missing")
            // Inspect siblings through the provider's canonical document path.
            // Refuse a rename if the provider cannot establish the parent.
            val path=android.provider.DocumentsContract.findDocumentPath(activity.contentResolver,uri)?.path ?: throw Failure("rename")
            if(path.size<2)throw Failure("rename")
            val children=android.provider.DocumentsContract.buildChildDocumentsUriUsingTree(uri,path[path.size-2])
            activity.contentResolver.query(children,arrayOf(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME),null,null,null)?.use {cursor->
                while(cursor.moveToNext())if(cursor.getString(0)==name)throw Failure("collision")
            } ?: throw Failure("rename")
            if(!file.renameTo(name))throw Failure("rename");file.uri.toString()
        }
        val result=a.toMutableMap().apply{remove("newTitle");put("uri",newUri);put("title",title)};saveReceipt(a["id"] as String,result);return result
    }
    private fun delete(a:Map<String,Any?>) {
        if(a["deleteImages"]==true)(a["images"] as? List<*>)?.forEach{removeUri(it as String)}
        removeUri(a["uri"] as String)
        File(root,"receipts/${safeId(a["id"] as String)}.json").delete()
    }
    private fun usage():Map<String,Any?> {
        fun size(file:File)=file.walkTopDown().filter{it.isFile}.sumOf{it.length()}
        return mapOf("privateBytes" to size(root),"libraryBytes" to size(privateRoot()),"location" to location())
    }
}

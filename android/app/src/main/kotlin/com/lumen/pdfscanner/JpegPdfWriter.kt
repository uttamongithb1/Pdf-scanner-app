package com.lumen.pdfscanner

import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.min

/**
 * Image-only PDF 1.4 writer. JPEG streams are copied straight from disk;
 * no page bitmap, compressed-image batch or final PDF buffer is retained.
 * The intentionally narrow output is verified by PdfRenderer before publish.
 */
internal class JpegPdfWriter(file: File, private val count: Int, title: String): Closeable {
    private val output = RandomAccessFile(file, "rw")
    private val infoId = 3 * count + 3
    private val offsets = LongArray(infoId + 1)
    private var written = 0
    private val titleHex = "FEFF" + title.toByteArray(StandardCharsets.UTF_16BE).joinToString("") { "%02X".format(it.toInt() and 255) }
    init {
        require(count in 1..50)
        output.setLength(0)
        text("%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n")
        obj(1, "<< /Type /Catalog /Pages 2 0 R >>")
    }
    private fun text(s: String) { output.write(s.toByteArray(StandardCharsets.ISO_8859_1)) }
    private fun start(id: Int) { offsets[id] = output.filePointer; text("$id 0 obj\n") }
    private fun obj(id: Int, body: String) { start(id); text("$body\nendobj\n") }
    private fun number(value: Double) = String.format(Locale.US,"%.4f",value)
    fun addPage(jpeg: File, pixelWidth: Int, pixelHeight: Int, width: Double, height: Double, margin: Double) {
        require(written < count && width > 0 && height > 0)
        require(pixelWidth > 0 && pixelHeight > 0 && margin >= 0 && width > margin*2 && height > margin*2)
        val page = 3 + written * 3; val image = page + 1; val contents = page + 2
        obj(page,"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${number(width)} ${number(height)}] /Resources << /XObject << /Im0 $image 0 R >> >> /Contents $contents 0 R >>")
        start(image)
        text("<< /Type /XObject /Subtype /Image /Width $pixelWidth /Height $pixelHeight /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.length()} >>\nstream\n")
        jpeg.inputStream().use { input ->
            val buffer=ByteArray(64*1024)
            while(true) {val size=input.read(buffer);if(size<0)break;output.write(buffer,0,size)}
        }
        text("\nendstream\nendobj\n")
        val scale=min((width-margin*2)/pixelWidth,(height-margin*2)/pixelHeight)
        val rw=pixelWidth*scale;val rh=pixelHeight*scale
        val commands="q\n${number(rw)} 0 0 ${number(rh)} ${number((width-rw)/2)} ${number((height-rh)/2)} cm\n/Im0 Do\nQ\n"
        start(contents);text("<< /Length ${commands.toByteArray(StandardCharsets.ISO_8859_1).size} >>\nstream\n$commands" + "endstream\nendobj\n")
        written++
    }
    fun finish() {
        check(written == count)
        val kids=(0 until count).joinToString(" ") { "${3+it*3} 0 R" }
        obj(2,"<< /Type /Pages /Count $count /Kids [$kids] >>")
        val stamp=SimpleDateFormat("yyyyMMddHHmmss",Locale.US).apply { timeZone=TimeZone.getTimeZone("UTC") }.format(Date())
        obj(infoId,"<< /Title <$titleHex> /Creator (PDF Scanner 0.1) /Producer (Lumen JPEG PDF Writer) /CreationDate (D:$stamp" + "Z) >>")
        val xref=output.filePointer
        text("xref\n0 ${offsets.size}\n0000000000 65535 f \n")
        for(id in 1 until offsets.size) {check(offsets[id]>0);text(String.format(Locale.US,"%010d 00000 n \n",offsets[id]))}
        text("trailer\n<< /Size ${offsets.size} /Root 1 0 R /Info $infoId 0 R >>\nstartxref\n$xref\n%%EOF\n")
        output.fd.sync()
    }
    override fun close() { output.close() }
}

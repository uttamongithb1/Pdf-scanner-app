package com.lumen.pdfscanner

import java.io.File

/** Runs on a plain JVM; no Android emulator or confidential fixtures needed. */
fun main(args: Array<String>) {
    val root=File(args[0])
    JpegPdfWriter(File(root,"smoke.pdf"),3,"विद्यालय — Invoice").use { writer ->
        writer.addPage(File(root,"red.jpg"),800,1200,595.28,841.89,14.1732)
        writer.addPage(File(root,"green.jpg"),1200,800,792.0,612.0,0.0)
        writer.addPage(File(root,"blue.jpg"),500,500,180.0,180.0,0.0)
        writer.finish()
    }
    JpegPdfWriter(File(root,"fifty.pdf"),50,"Fifty pages").use { writer ->
        for(i in 0 until 50) writer.addPage(File(root,"red.jpg"),800,1200,595.28,841.89,14.1732)
        writer.finish()
    }
    // A failed/incomplete writer must never produce a committed PDF trailer.
    JpegPdfWriter(File(root,"incomplete.part"),2,"Not published").use { writer ->
        writer.addPage(File(root,"red.jpg"),800,1200,595.28,841.89,14.1732)
    }
    check(!File(root,"incomplete.part").readText(Charsets.ISO_8859_1).contains("%%EOF"))
    println("Kotlin PDF writer completed three-page, fifty-page and incomplete-job checks.")
}

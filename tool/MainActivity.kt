package com.example.pdf_reader

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "pdf_reader/native"
    private var fileDescriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "openPdf" -> {
                            closeDocument()
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("Missing PDF path")
                            fileDescriptor = ParcelFileDescriptor.open(
                                File(path), ParcelFileDescriptor.MODE_READ_ONLY
                            )
                            renderer = PdfRenderer(fileDescriptor!!)
                            result.success(renderer!!.pageCount)
                        }
                        "renderPage" -> {
                            val index = call.argument<Int>("index") ?: 0
                            val maxWidth = call.argument<Int>("maxWidth") ?: 1600
                            val pdf = renderer ?: throw IllegalStateException("No PDF is open")
                            if (index !in 0 until pdf.pageCount) {
                                throw IndexOutOfBoundsException("Invalid page")
                            }
                            val page = pdf.openPage(index)
                            val scale = (maxWidth.toFloat() / page.width)
                                .coerceAtMost(2.5f)
                            val width = (page.width * scale).toInt().coerceAtLeast(1)
                            val height = (page.height * scale).toInt().coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(
                                width, height, Bitmap.Config.ARGB_8888
                            )
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, Matrix(), PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            page.close()
                            val output = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                            bitmap.recycle()
                            result.success(output.toByteArray())
                        }
                        "closePdf" -> {
                            closeDocument()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("PDF_ERROR", error.message, null)
                }
            }
    }

    private fun closeDocument() {
        renderer?.close()
        renderer = null
        fileDescriptor?.close()
        fileDescriptor = null
    }

    override fun onDestroy() {
        closeDocument()
        super.onDestroy()
    }
}

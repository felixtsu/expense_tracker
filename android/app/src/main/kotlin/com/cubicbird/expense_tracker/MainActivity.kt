package com.cubicbird.expense_tracker

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val OCR_CHANNEL = "expense_tracker/ocr_android"
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath == null) {
                            result.error("BAD_ARGS", "imagePath is required", null)
                            return@setMethodCallHandler
                        }
                        recognizeText(imagePath, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun recognizeText(imagePath: String, result: MethodChannel.Result) {
        val file = File(imagePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "Image not found: $imagePath", null)
            return
        }

        val image: InputImage
        try {
            image = InputImage.fromFilePath(context, Uri.fromFile(file))
        } catch (e: Exception) {
            result.error("IMAGE_ERROR", "Failed to load image: ${e.message}", null)
            return
        }

        recognizer.process(image)
            .addOnSuccess { visionText ->
                val rawText = visionText.text
                if (rawText.isEmpty()) {
                    result.success(mapOf<String, Any?>())
                    return
                }

                val amount = extractAmount(rawText)
                val merchant = extractMerchant(visionText.textBlocks)

                result.success(
                    mapOf(
                        "text" to rawText,
                        "amount" to amount,
                        "merchant" to merchant
                    )
                )
            }
            .addOnFailureListener { e ->
                result.error("OCR_FAILED", e.message, null)
            }
    }

    private fun extractAmount(text: String): String? {
        val patterns = listOf(
            Pattern.compile("[¥￥]?\\s*(\\d+\\.?\\d{0,2})"),
            Pattern.compile("(?:total|总计|合计|金额|总额)[:\\s]*[¥￥]?\\s*(\\d+\\.?\\d{0,2})", Pattern.CASE_INSENSITIVE)
        )

        var best: Double? = null
        for (pattern in patterns) {
            val matcher = pattern.matcher(text)
            while (matcher.find()) {
                val v = matcher.group(1)?.toDoubleOrNull()
                if (v != null && v > 0) {
                    if (best == null || v > best) best = v
                }
            }
        }
        return best?.let { String.format("%.2f", it) }
    }

    private fun extractMerchant(blocks: List<com.google.mlkit.vision.text.TextBlock>): String? {
        for (block in blocks) {
            val text = block.text.trim()
            if (text.length >= 4) return text
        }
        return null
    }
}

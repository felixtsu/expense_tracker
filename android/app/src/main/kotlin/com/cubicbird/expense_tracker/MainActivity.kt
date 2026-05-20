package com.cubicbird.expense_tracker

import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val OCR_CHANNEL = "expense_tracker/ocr_android"
    private val recognizer = com.google.mlkit.vision.text.TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

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

        val image = com.google.mlkit.vision.common.InputImage.fromFilePath(context, Uri.fromFile(file))

        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val rawText = visionText.text
                Log.d("MainActivity", "[OCR Raw] $rawText")
                if (rawText.isEmpty()) {
                    result.success(mapOf<String, Any?>())
                    return@addOnSuccessListener
                }

                val candidates = extractAmountCandidates(rawText)
                val merchant = visionText.textBlocks.firstOrNull()?.text?.trim()
                Log.d("MainActivity", "[OCR Result] candidates=${candidates.size} merchant=$merchant")
                for (c in candidates) {
                    Log.d("MainActivity", "[OCR Candidate] $c")
                }

                result.success(
                    mapOf(
                        "text" to rawText,
                        "amountCandidates" to candidates,
                        "merchant" to merchant
                    )
                )
            }
            .addOnFailureListener { e ->
                result.error("OCR_FAILED", e.message, null)
            }
    }

    private fun extractAmountCandidates(text: String): List<Map<String, Any?>> {
        val totalLinePattern = Pattern.compile(
            "(?:total|amount|總(?:額|计|計)|合计|总计|金额|总额|实付|应付|小计|小計)",
            Pattern.CASE_INSENSITIVE
        )
        val amountPattern = Pattern.compile(
            "((?:HKD|HK\\$|HK'\\$|HK＄|\\bHK(?!D)(?:['\\$＄])?|港(?:币|幣)|[¥￥＄]|\\$)\\s*)?" +
                "(\\d{1,3}(?:,\\d{3})*|\\d+)\\.(\\d{2})\\b",
            Pattern.CASE_INSENSITIVE
        )

        val seen = mutableSetOf<String>()
        val candidates = mutableListOf<Map<String, Any?>>()

        for (line in text.split(Regex("\\r?\\n"))) {
            val trimmed = line.trim()
            if (trimmed.isEmpty()) continue

            val isLikelyTotal = totalLinePattern.matcher(trimmed).find()
            val matcher = amountPattern.matcher(trimmed)
            while (matcher.find()) {
                val intPart = matcher.group(2)?.replace(",", "") ?: continue
                val decPart = matcher.group(3) ?: continue
                val valueDouble = "$intPart.$decPart".toDoubleOrNull() ?: continue
                val value = String.format("%.2f", valueDouble)
                val raw = matcher.group(0)?.trim() ?: continue
                val key = "$value|$raw|$trimmed"
                if (!seen.add(key)) continue

                val isSuspicious = isSuspiciousAmount(valueDouble)
                candidates.add(
                    mapOf(
                        "value" to value,
                        "raw" to raw,
                        "context" to trimmed,
                        "isLikelyTotal" to isLikelyTotal,
                        "isSuspicious" to isSuspicious
                    )
                )
            }
        }

        candidates.sortWith { a, b ->
            val aTotal = a["isLikelyTotal"] as? Boolean ?: false
            val bTotal = b["isLikelyTotal"] as? Boolean ?: false
            if (aTotal != bTotal) return@sortWith if (aTotal) -1 else 1

            val aSusp = a["isSuspicious"] as? Boolean ?: false
            val bSusp = b["isSuspicious"] as? Boolean ?: false
            if (aSusp != bSusp) return@sortWith if (aSusp) 1 else -1

            val av = (a["value"] as? String)?.toDoubleOrNull() ?: 0.0
            val bv = (b["value"] as? String)?.toDoubleOrNull() ?: 0.0
            bv.compareTo(av)
        }

        return candidates
    }

    private fun isSuspiciousAmount(value: Double): Boolean {
        val whole = kotlin.math.floor(value).toLong()
        if (whole < 1900 || whole > 2100) return false
        return kotlin.math.abs(value - whole) < 0.0001
    }
}

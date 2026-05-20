package com.cubicbird.expense_tracker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.io.File
import java.io.FileOutputStream
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val OCR_CHANNEL = "expense_tracker/ocr_android"
    private val recognizer = TextRecognition.getClient(
        ChineseTextRecognizerOptions.Builder().build()
    )

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
        val inputImage = loadInputImage(imagePath)
        if (inputImage == null) {
            Log.e("MainActivity", "[OCR] Failed to load image: $imagePath")
            result.error("IMAGE_LOAD_FAILED", "Could not decode image: $imagePath", null)
            return
        }

        Log.d("MainActivity", "[OCR] Processing image: $imagePath")

        recognizer.process(inputImage)
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
                Log.e("MainActivity", "[OCR] ML Kit failed", e)
                result.error("OCR_FAILED", e.message, null)
            }
    }

    /**
     * Decode gallery/camera images for ML Kit. Handles content:// URIs, HEIC/HEIF,
     * and falls back to a JPEG cache file when the platform decoder fails.
     */
    private fun loadInputImage(imagePath: String): InputImage? {
        return try {
            when {
                imagePath.startsWith("content://") -> {
                    val uri = Uri.parse(imagePath)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        val source = ImageDecoder.createSource(contentResolver, uri)
                        val bitmap = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                            decoder.isMutableRequired = false
                        }
                        InputImage.fromBitmap(bitmap, 0)
                    } else {
                        InputImage.fromFilePath(context, uri)
                    }
                }
                else -> {
                    val file = File(imagePath)
                    if (!file.exists()) {
                        Log.e("MainActivity", "[OCR] File not found: $imagePath")
                        return null
                    }
                    val lower = file.name.lowercase()
                    if (lower.endsWith(".heic") || lower.endsWith(".heif")) {
                        decodeHeicToInputImage(file)
                    } else {
                        InputImage.fromFilePath(context, Uri.fromFile(file))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "[OCR] loadInputImage error for $imagePath", e)
            try {
                val file = File(imagePath)
                if (!file.exists()) return null
                decodeHeicToInputImage(file)
            } catch (e2: Exception) {
                Log.e("MainActivity", "[OCR] HEIC fallback failed", e2)
                null
            }
        }
    }

    private fun decodeHeicToInputImage(file: File): InputImage? {
        val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val source = ImageDecoder.createSource(file)
                ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                    decoder.isMutableRequired = false
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "[OCR] ImageDecoder HEIC failed, trying BitmapFactory", e)
                BitmapFactory.decodeFile(file.absolutePath)
            }
        } else {
            BitmapFactory.decodeFile(file.absolutePath)
        }

        if (bitmap != null) {
            return InputImage.fromBitmap(bitmap, 0)
        }

        // Last resort: write JPEG to cache (emulator often lacks HEIC codecs).
        val jpeg = File(cacheDir, "ocr_${file.nameWithoutExtension}.jpg")
        val fallback = BitmapFactory.decodeFile(file.absolutePath)
            ?: return null
        FileOutputStream(jpeg).use { out ->
            fallback.compress(Bitmap.CompressFormat.JPEG, 92, out)
        }
        Log.d("MainActivity", "[OCR] Converted HEIC to JPEG cache: ${jpeg.absolutePath}")
        return InputImage.fromFilePath(context, Uri.fromFile(jpeg))
    }

    private fun extractAmountCandidates(text: String): List<Map<String, Any?>> {
        val totalLinePattern = Pattern.compile(
            "(?:total|amount|總(?:額|计|計)|合计|总计|金额|总额|实付|应付|小计|小計|payment|消费)",
            Pattern.CASE_INSENSITIVE
        )
        val amountPattern = Pattern.compile(
            "((?:HKD|HK\\$|HK'\\$|HK＄|\\bHK(?!D)(?:['\\$＄])?|港(?:币|幣)|[¥￥＄]|\\$)\\s*)?" +
                "(-)?(\\d{1,3}(?:,\\d{3})*|\\d+)\\.(\\d{2})\\b",
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
                val sign = matcher.group(2) ?: ""
                val intPart = matcher.group(3)?.replace(",", "") ?: continue
                val decPart = matcher.group(4) ?: continue
                val valueDouble = "$sign$intPart.$decPart".toDoubleOrNull() ?: continue
                val value = String.format("%.2f", kotlin.math.abs(valueDouble))
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
        val absValue = kotlin.math.abs(value)
        val whole = kotlin.math.floor(absValue).toLong()
        if (whole < 1900 || whole > 2100) return false
        return kotlin.math.abs(absValue - whole) < 0.0001
    }
}

import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerOcrPlugin(with: engineBridge.pluginRegistry)
  }

  private func registerOcrPlugin(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "OcrPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "expense_tracker/ocr",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeText",
            let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.recognizeText(imagePath: imagePath, result: result)
    }
  }

  private func recognizeText(imagePath: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: imagePath),
          let cgImage = image.cgImage else {
      result(FlutterError(code: "IMAGE_LOAD_FAILED",
                          message: "Could not load image at \(imagePath)",
                          details: nil))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        }
        return
      }

      guard let observations = request.results as? [VNRecognizedTextObservation],
            !observations.isEmpty else {
        DispatchQueue.main.async { result([:]) }
        return
      }

      var lines: [String] = []
      for observation in observations {
        if let topCandidate = observation.topCandidates(1).first {
          lines.append(topCandidate.string)
        }
      }

      let rawText = lines.joined(separator: "\n")
      let merchant = lines.first(where: { $0.count >= 4 })
      let candidates = Self.extractAmountCandidates(from: rawText)

      NSLog("[AppleVision OCR] raw Vision text (%d chars):\n%@", rawText.count, rawText)
      NSLog("[AppleVision OCR] merchant: %@", merchant ?? "(nil)")
      NSLog("[AppleVision OCR] candidates count: %d", candidates.count)
      for c in candidates {
        NSLog("[AppleVision OCR] candidate: %@", String(describing: c))
      }

      DispatchQueue.main.async {
        result([
          "text": rawText,
          "amountCandidates": candidates,
          "merchant": merchant as Any
        ])
      }
    }

    request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        }
      }
    }
  }

  private static func extractAmountCandidates(from text: String) -> [[String: Any]] {
    guard let totalLineRegex = try? NSRegularExpression(
      pattern: #"(?:total|amount|總(?:額|计|計)|合计|总计|金额|总额|实付|应付|小计|小計)"#,
      options: [.caseInsensitive]
    ) else {
      return []
    }
    guard let amountRegex = try? NSRegularExpression(
      pattern: #"((?:HKD|HK\$|HK'\$|HK＄|\bHK(?!D)(?:['\$＄])?|港(?:币|幣)|[¥￥＄]|\$)\s*)?(\d{1,3}(?:,\d{3})*|\d+)\.(\d{2})\b"#,
      options: [.caseInsensitive]
    ) else {
      return []
    }

    var seen = Set<String>()
    var candidates: [[String: Any]] = []

    let lines = text.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { continue }

      let nsLine = trimmed as NSString
      let lineRange = NSRange(location: 0, length: nsLine.length)
      let isLikelyTotal = totalLineRegex.firstMatch(in: trimmed, options: [], range: lineRange) != nil

      for match in amountRegex.matches(in: trimmed, options: [], range: lineRange) {
        guard match.numberOfRanges >= 4,
              match.range(at: 2).location != NSNotFound,
              match.range(at: 3).location != NSNotFound else {
          continue
        }

        let intPart = nsLine.substring(with: match.range(at: 2))
          .replacingOccurrences(of: ",", with: "")
        let decPart = nsLine.substring(with: match.range(at: 3))
        guard let valueDouble = Double("\(intPart).\(decPart)") else { continue }

        let value = String(format: "%.2f", valueDouble)
        let raw = nsLine.substring(with: match.range).trimmingCharacters(in: .whitespaces)
        let key = "\(value)|\(raw)|\(trimmed)"
        if seen.contains(key) { continue }
        seen.insert(key)

        let isSuspicious = isSuspiciousAmount(valueDouble)
        candidates.append([
          "value": value,
          "raw": raw,
          "context": trimmed,
          "isLikelyTotal": isLikelyTotal,
          "isSuspicious": isSuspicious
        ])
      }
    }

    candidates.sort { a, b in
      let aTotal = a["isLikelyTotal"] as? Bool ?? false
      let bTotal = b["isLikelyTotal"] as? Bool ?? false
      if aTotal != bTotal { return aTotal && !bTotal }

      let aSusp = a["isSuspicious"] as? Bool ?? false
      let bSusp = b["isSuspicious"] as? Bool ?? false
      if aSusp != bSusp { return !aSusp && bSusp }

      let av = Double(a["value"] as? String ?? "0") ?? 0
      let bv = Double(b["value"] as? String ?? "0") ?? 0
      return av > bv
    }

    return candidates
  }

  private static func isSuspiciousAmount(_ value: Double) -> Bool {
    let whole = floor(value)
    if whole < 1900 || whole > 2100 { return false }
    return abs(value - whole) < 0.0001
  }
}

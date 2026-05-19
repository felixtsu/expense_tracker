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

      DispatchQueue.main.async {
        result([
          "text": rawText,
          "merchant": merchant as Any
        ])
      }
    }

    request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
    request.usesLanguageCorrection = true

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
}

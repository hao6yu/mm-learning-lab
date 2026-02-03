import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var audioEngine: AVAudioEngine?
  var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    let eventChannel = FlutterEventChannel(name: "native_audio_stream_events", binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(self)

    let methodChannel = FlutterMethodChannel(name: "native_audio_stream", binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "start" {
            let args = call.arguments as? [String: Any]
            let sampleRate = args?["sampleRate"] as? Double ?? 16000
            self?.startAudioStream(sampleRate: sampleRate)
            result(nil)
        } else if call.method == "stop" {
            self?.stopAudioStream()
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    AVAudioSession.sharedInstance().requestRecordPermission { granted in
        print("Native mic permission granted: \(granted)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func startAudioStream(sampleRate: Double) {
    // 1. Configure and activate AVAudioSession BEFORE accessing inputNode
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
    } catch {
        print("Failed to configure AVAudioSession: \(error)")
        return
    }

    audioEngine = AVAudioEngine()
    let inputNode = audioEngine!.inputNode
    let bus = 0

    let hwFormat = inputNode.inputFormat(forBus: bus)
    print("[NativeAudioStream] Input HW format: sampleRate=\(hwFormat.sampleRate), channels=\(hwFormat.channelCount), format=\(hwFormat.commonFormat.rawValue)")

    if hwFormat.sampleRate == 0.0 || hwFormat.channelCount == 0 {
        print("[NativeAudioStream] ERROR: Input HW format is invalid. Aborting audio stream start.")
        return
    }

    // Install tap using the hardware format (no hardcoded sample rate or channel count)
    // NOTE: The format is device-dependent. If you need a specific format (e.g., 16kHz Int16), you must resample/convert in code.
    inputNode.installTap(onBus: bus, bufferSize: 1024, format: hwFormat) { (buffer, time) in
        let channelData = buffer.floatChannelData![0]
        let frameLength = Int(buffer.frameLength)
        let data = Data(buffer: UnsafeBufferPointer(start: channelData, count: frameLength))
        // Ensure eventSink is called on the main thread
        DispatchQueue.main.async {
            self.eventSink?(FlutterStandardTypedData(bytes: data))
        }
    }

    audioEngine!.prepare()
    do {
        try audioEngine!.start()
    } catch {
        print("[NativeAudioStream] Failed to start audioEngine: \(error)")
    }
  }

  func stopAudioStream() {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
  }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        stopAudioStream()
        return nil
    }
}

import Flutter
import UIKit
import AVFoundation
import AVKit

/// Audio Router Plugin for iOS
///
/// This plugin provides audio output routing control for VoIP and communication apps.
/// **Important**: This plugin does NOT configure AVAudioSession. The host app is responsible
/// for setting up the audio session (category, mode, options) before using this plugin.
///
/// Responsibilities:
/// - Monitoring current audio route via AVAudioSession.currentRoute
/// - Displaying native AVRoutePickerView for device selection
/// - Notifying Flutter side of route changes
///
/// Not responsible for:
/// - AVAudioSession category/mode setup
/// - Audio session activation
/// - Recording device selection

private struct AudioDeviceInfo {
  let id: String
  let type: String

  func toMap() -> [String: Any] {
    return [
      "id": id,
      "type": type
    ]
  }
}

private final class AudioRouterController: NSObject {
  static let shared = AudioRouterController()

  private var sinks: [UUID: FlutterEventSink] = [:]
  private var pluginCount: Int = 0

  private override init() {
    super.init()
  }

  func acquire() {
    pluginCount += 1
    if pluginCount == 1 {
      setupObservers()
    }
  }

  func release() {
    guard pluginCount > 0 else { return }
    pluginCount -= 1
    if pluginCount == 0 {
      teardownObservers()
      sinks.removeAll()
    }
  }

  func addSink(_ sink: @escaping FlutterEventSink) -> UUID {
    let handle = UUID()
    sinks[handle] = sink
    sendAudioStateUpdate(target: handle)
    return handle
  }

  func removeSink(handle: UUID?) {
    guard let handle else { return }
    sinks.removeValue(forKey: handle)
  }


  /// Sets up observers for audio route changes.
  /// Monitors AVAudioSession.routeChangeNotification to detect device changes.
  private func setupObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(audioRouteChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
  }

  private func teardownObservers() {
    NotificationCenter.default.removeObserver(self)
  }

  /// Shows the native iOS audio route picker (AVRoutePickerView).
  /// This allows the user to select between available audio output devices
  /// within the current audio session configured by the host app.
  func showAudioRoutePicker() {
    DispatchQueue.main.async {
      let routePickerView = AVRoutePickerView(frame: CGRect.zero)
      routePickerView.prioritizesVideoDevices = false

      // Add to window temporarily
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = windowScene.windows.first {
        window.addSubview(routePickerView)

        // Trigger the route picker button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          for subview in routePickerView.subviews {
            if let button = subview as? UIButton {
              button.sendActions(for: .touchUpInside)
              break
            }
          }

          // Remove after a delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            routePickerView.removeFromSuperview()
          }
        }
      }
    }
  }

  @objc private func audioRouteChanged(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    switch reason {
    case .newDeviceAvailable,
         .oldDeviceUnavailable,
         .categoryChange,
         .override,
         .routeConfigurationChange:  // Native picker selection
      sendAudioStateUpdate()
    default:
      break
    }
  }

  private func sendAudioStateUpdate(target handle: UUID? = nil) {
    let session = AVAudioSession.sharedInstance()

    // Get current device info from audio session
    var selectedDeviceMap: [String: Any]?
    if let currentOutput = session.currentRoute.outputs.first {
      let portType = currentOutput.portType

      if portType == .builtInSpeaker {
        selectedDeviceMap = AudioDeviceInfo(
          id: "builtin_speaker",
          type: "builtinSpeaker"
        ).toMap()
      } else if portType == .builtInReceiver {
        selectedDeviceMap = AudioDeviceInfo(
          id: "builtin_receiver",
          type: "builtinReceiver"
        ).toMap()
      } else if portType == .bluetoothA2DP || portType == .bluetoothHFP || portType == .bluetoothLE {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "bluetooth"
        ).toMap()
      } else if portType == .headphones {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "wiredHeadset"
        ).toMap()
      } else if portType == .usbAudio {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "usb"
        ).toMap()
      } else if portType == .carAudio {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "carAudio"
        ).toMap()
      } else if portType == .airPlay {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "airplay"
        ).toMap()
      } else {
        selectedDeviceMap = AudioDeviceInfo(
          id: currentOutput.uid,
          type: "unknown"
        ).toMap()
      }
    }

    let payload: [String: Any] = [
      "availableDevices": [],
      "selectedDevice": selectedDeviceMap as Any
    ]

    let targets: [FlutterEventSink]
    if let handle, let sink = sinks[handle] {
      targets = [sink]
    } else {
      targets = Array(sinks.values)
    }

    let deliver: () -> Void = {
      targets.forEach { sink in
        sink(payload)
      }
    }

    if Thread.isMainThread {
      deliver()
    } else {
      DispatchQueue.main.async {
        deliver()
      }
    }
  }

}

public class AudioRouterPlugin: NSObject, FlutterPlugin {
  private let controller: AudioRouterController
  private var sinkHandle: UUID?

  fileprivate init(controller: AudioRouterController) {
    self.controller = controller
    super.init()
    controller.acquire()
  }

  public override convenience init() {
    self.init(controller: .shared)
  }

  deinit {
    controller.removeSink(handle: sinkHandle)
    controller.release()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "audio_router", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "audio_router/events", binaryMessenger: registrar.messenger())

    let instance = AudioRouterPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showAudioRoutePicker":
      controller.showAudioRoutePicker()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension AudioRouterPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sinkHandle = controller.addSink(events)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    controller.removeSink(handle: sinkHandle)
    sinkHandle = nil
    return nil
  }
}

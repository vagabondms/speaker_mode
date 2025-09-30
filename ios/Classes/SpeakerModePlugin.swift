import Flutter
import UIKit
import AVFoundation
import CallKit

private enum SpeakerModeError: Error {
  case audioSession(String)
  case invalidDevice(String)
}

private extension SpeakerModeError {
  var flutterError: FlutterError {
    switch self {
    case .audioSession(let message):
      return FlutterError(
        code: "AUDIO_SESSION_ERROR",
        message: message,
        details: nil
      )
    case .invalidDevice(let message):
      return FlutterError(
        code: "INVALID_DEVICE",
        message: message,
        details: nil
      )
    }
  }
}

private struct AudioDeviceInfo {
  let id: String
  let name: String
  let type: String
  let isConnected: Bool

  func toMap() -> [String: Any] {
    return [
      "id": id,
      "name": name,
      "type": type,
      "isConnected": isConnected
    ]
  }
}

private final class SpeakerModeController: NSObject, CXCallObserverDelegate {
  static let shared = SpeakerModeController()

  private var isSpeakerModeOn: Bool = false
  private var isCallKitActive: Bool = false
  private var callObserver: CXCallObserver?
  private var sinks: [UUID: FlutterEventSink] = [:]
  private var pluginCount: Int = 0

  private let externalPorts: Set<AVAudioSession.Port> = [
    .headphones,
    .bluetoothA2DP,
    .bluetoothHFP,
    .bluetoothLE,
    .carAudio,
    .usbAudio
  ]

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
      isCallKitActive = false
      isSpeakerModeOn = getActualSpeakerModeState()
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

  func setSpeakerMode(enabled: Bool) -> Result<Bool, SpeakerModeError> {
    let session = AVAudioSession.sharedInstance()
    let shouldUseBuiltInSpeaker = enabled

    do {
      if isCallKitInUse() {
        let desiredOptions: AVAudioSession.CategoryOptions
        if shouldUseBuiltInSpeaker {
          desiredOptions = session.categoryOptions.union([.defaultToSpeaker])
        } else {
          desiredOptions = session.categoryOptions.subtracting([.defaultToSpeaker])
        }

        if desiredOptions != session.categoryOptions {
          try session.setCategory(session.category, mode: session.mode, options: desiredOptions)
        }
        try applyOutputOverride(session: session, useSpeaker: shouldUseBuiltInSpeaker)
      } else {
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
        if shouldUseBuiltInSpeaker {
          options.insert(.defaultToSpeaker)
        }

        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try session.setActive(true)
        try applyOutputOverride(session: session, useSpeaker: shouldUseBuiltInSpeaker)
      }

      isSpeakerModeOn = getActualSpeakerModeState()
      sendAudioStateUpdate()
      return .success(true)
    } catch {
      return .failure(.audioSession(makeAudioSessionErrorMessage(from: error)))
    }
  }

  func currentSpeakerMode() -> Bool {
    return getActualSpeakerModeState()
  }

  func isExternalDeviceConnected() -> Bool {
    return currentOutputPorts().contains(where: externalPorts.contains)
  }

  func getAvailableDevices() -> [AudioDeviceInfo] {
    var devices: [AudioDeviceInfo] = []
    let session = AVAudioSession.sharedInstance()
    let currentOutputs = currentOutputPorts()

    // Built-in speaker
    devices.append(AudioDeviceInfo(
      id: "builtin_speaker",
      name: "스피커",
      type: "builtinSpeaker",
      isConnected: true
    ))

    // Built-in receiver
    devices.append(AudioDeviceInfo(
      id: "builtin_receiver",
      name: "리시버",
      type: "builtinReceiver",
      isConnected: true
    ))

    // Check current route for connected devices
    for output in session.currentRoute.outputs {
      let portType = output.portType
      let portName = output.portName

      if portType == .bluetoothA2DP || portType == .bluetoothHFP || portType == .bluetoothLE {
        devices.append(AudioDeviceInfo(
          id: output.uid,
          name: portName,
          type: "bluetooth",
          isConnected: true
        ))
      } else if portType == .headphones {
        devices.append(AudioDeviceInfo(
          id: output.uid,
          name: portName,
          type: "wiredHeadset",
          isConnected: true
        ))
      } else if portType == .usbAudio {
        devices.append(AudioDeviceInfo(
          id: output.uid,
          name: portName,
          type: "usb",
          isConnected: true
        ))
      } else if portType == .carAudio {
        devices.append(AudioDeviceInfo(
          id: output.uid,
          name: portName,
          type: "carAudio",
          isConnected: true
        ))
      } else if portType == .airPlay {
        devices.append(AudioDeviceInfo(
          id: output.uid,
          name: portName,
          type: "airplay",
          isConnected: true
        ))
      }
    }

    return devices
  }

  func setAudioDevice(deviceId: String) -> Result<Bool, SpeakerModeError> {
    let session = AVAudioSession.sharedInstance()

    do {
      // Handle built-in devices
      if deviceId == "builtin_speaker" {
        return setSpeakerMode(enabled: true)
      } else if deviceId == "builtin_receiver" {
        return setSpeakerMode(enabled: false)
      }

      // For external devices, try to find and set the preferred input/output
      let availableInputs = session.availableInputs ?? []
      if let matchingInput = availableInputs.first(where: { $0.uid == deviceId }) {
        try session.setPreferredInput(matchingInput)
        isSpeakerModeOn = getActualSpeakerModeState()
        sendAudioStateUpdate()
        return .success(true)
      }

      // If device is in current route outputs, it's already active
      for output in session.currentRoute.outputs {
        if output.uid == deviceId {
          isSpeakerModeOn = getActualSpeakerModeState()
          sendAudioStateUpdate()
          return .success(true)
        }
      }

      return .failure(.invalidDevice("Device with ID \(deviceId) not found or not available."))
    } catch {
      return .failure(.audioSession(makeAudioSessionErrorMessage(from: error)))
    }
  }

  private func setupObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(audioRouteChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    setupCallObserver()
  }

  private func teardownObservers() {
    NotificationCenter.default.removeObserver(self)
    callObserver = nil
  }

  private func setupCallObserver() {
    callObserver = CXCallObserver()
    callObserver?.setDelegate(self, queue: nil)
    synchronizeCallKitActivity()
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
         .override:
      sendAudioStateUpdate()
    default:
      break
    }
  }

  @objc private func handleAudioSessionInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      isCallKitActive = true
    case .ended:
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        guard let self = self else { return }
        self.synchronizeCallKitActivity()
        self.sendAudioStateUpdate()
      }
    @unknown default:
      break
    }
  }

  private func sendAudioStateUpdate(target handle: UUID? = nil) {
    let outputs = currentOutputPorts()
    let isExternalConnected = outputs.contains(where: externalPorts.contains)
    let isCarAudioConnected = outputs.contains(.carAudio)
    let actualSpeakerMode = getActualSpeakerModeState()
    isSpeakerModeOn = actualSpeakerMode

    // Get available devices and selected device
    let availableDevices = getAvailableDevices()
    let availableDevicesMaps = availableDevices.map { $0.toMap() }

    // Determine selected device based on current route
    var selectedDeviceMap: [String: Any]?
    let session = AVAudioSession.sharedInstance()
    if let currentOutput = session.currentRoute.outputs.first {
      let portType = currentOutput.portType
      if portType == .builtInSpeaker {
        selectedDeviceMap = AudioDeviceInfo(
          id: "builtin_speaker",
          name: "스피커",
          type: "builtinSpeaker",
          isConnected: true
        ).toMap()
      } else if portType == .builtInReceiver {
        selectedDeviceMap = AudioDeviceInfo(
          id: "builtin_receiver",
          name: "리시버",
          type: "builtinReceiver",
          isConnected: true
        ).toMap()
      } else {
        // Find matching external device
        selectedDeviceMap = availableDevices.first(where: { $0.id == currentOutput.uid })?.toMap()
      }
    }

    let payload: [String: Any] = [
      "isSpeakerOn": actualSpeakerMode,
      "isExternalDeviceConnected": isExternalConnected,
      "isCarAudioConnected": isCarAudioConnected,
      "availableDevices": availableDevicesMaps,
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

  private func currentOutputPorts() -> [AVAudioSession.Port] {
    return AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType }
  }

  private func synchronizeCallKitActivity() {
    if let callObserver {
      isCallKitActive = callObserver.calls.contains { !$0.hasEnded }
    } else {
      isCallKitActive = false
    }
  }

  private func applyOutputOverride(session: AVAudioSession, useSpeaker: Bool) throws {
    guard session.category == .playAndRecord else {
      return
    }

    if useSpeaker {
      try session.overrideOutputAudioPort(.speaker)
    } else {
      try session.overrideOutputAudioPort(.none)
    }
  }

  private func makeAudioSessionErrorMessage(from error: Error) -> String {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let routeDescription: String
    if outputs.isEmpty {
      routeDescription = "no active audio route"
    } else {
      let portNames = outputs.map { $0.portType.rawValue }
      routeDescription = portNames.joined(separator: ", ")
    }

    let nsError = error as NSError
    if nsError.domain == "AVAudioSessionErrorDomain",
       let code = AVAudioSession.ErrorCode(rawValue: nsError.code) {
      switch code {
      case .insufficientPriority:
        return "Another audio session currently controls routing (route: \(routeDescription))."
      case .cannotInterruptOthers:
        return "Current call session does not permit speaker override (route: \(routeDescription))."
      default:
        break
      }
    }

    return "Failed to update speaker mode while routing to \(routeDescription): \(nsError.localizedDescription)"
  }

  private func getActualSpeakerModeState() -> Bool {
    let session = AVAudioSession.sharedInstance()

    if session.categoryOptions.contains(.defaultToSpeaker) {
      return true
    }

    return session.currentRoute.outputs.contains {
      $0.portType == .builtInSpeaker || $0.portType == .carAudio
    }
  }

  private func isCallKitInUse() -> Bool {
    if let callObserver, callObserver.calls.contains(where: { !$0.hasEnded }) {
      return true
    }

    return isCallKitActive
  }

  // MARK: - CXCallObserverDelegate
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    synchronizeCallKitActivity()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.sendAudioStateUpdate()
    }
  }
}

public class SpeakerModePlugin: NSObject, FlutterPlugin {
  private let controller: SpeakerModeController
  private var sinkHandle: UUID?

  fileprivate init(controller: SpeakerModeController) {
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
    let methodChannel = FlutterMethodChannel(name: "speaker_mode", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "speaker_mode/events", binaryMessenger: registrar.messenger())

    let instance = SpeakerModePlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSpeakerMode":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Arguments must contain 'enabled' boolean",
          details: nil
        ))
        return
      }

      switch controller.setSpeakerMode(enabled: enabled) {
      case .success(let value):
        result(value)
      case .failure(let error):
        result(error.flutterError)
      }
    case "setAudioDevice":
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Arguments must contain 'deviceId' string",
          details: nil
        ))
        return
      }

      switch controller.setAudioDevice(deviceId: deviceId) {
      case .success(let value):
        result(value)
      case .failure(let error):
        result(error.flutterError)
      }
    case "getAvailableDevices":
      let devices = controller.getAvailableDevices()
      let deviceMaps = devices.map { $0.toMap() }
      result(deviceMaps)
    case "getSpeakerMode":
      result(controller.currentSpeakerMode())
    case "isExternalDeviceConnected":
      result(controller.isExternalDeviceConnected())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension SpeakerModePlugin: FlutterStreamHandler {
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

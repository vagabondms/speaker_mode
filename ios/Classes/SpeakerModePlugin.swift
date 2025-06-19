import Flutter
import UIKit
import AVFoundation
import CallKit

public class SpeakerModePlugin: NSObject, FlutterPlugin {
  private var isSpeakerModeOn: Bool = false
  private var eventSink: FlutterEventSink?
  private var isCallKitActive: Bool = false
  private var callObserver: CXCallObserver?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "speaker_mode", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "speaker_mode/events", binaryMessenger: registrar.messenger())
    
    let instance = SpeakerModePlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    
    // 오디오 라우트 변경 알림 등록
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.audioRouteChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    
    // CallKit 상태 감지를 위한 CXCallObserver 설정
    instance.setupCallObserver()
    
    // 오디오 세션 인터럽션 알림 등록 (CallKit 감지에 도움)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }
  
  // CallKit 상태 감지를 위한 CXCallObserver 설정
  private func setupCallObserver() {
    callObserver = CXCallObserver()
    callObserver?.setDelegate(self, queue: nil)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSpeakerMode":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGUMENTS", 
                           message: "Arguments must contain 'enabled' boolean", 
                           details: nil))
        return
      }
      
      setSpeakerMode(enabled: enabled, result: result)
    case "getSpeakerMode":
      result(isSpeakerModeOn)
    case "isExternalDeviceConnected":
      result(isExternalDeviceConnected())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func setSpeakerMode(enabled: Bool, result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    
    // 외부 기기가 연결된 경우 스피커 모드를 활성화하지 않음
    if enabled && isExternalDeviceConnected() {
      result(FlutterError(code: "EXTERNAL_DEVICE_CONNECTED", 
                         message: "Cannot enable speaker mode when external audio device is connected", 
                         details: nil))
      return
    }
    
    do {
      // CallKit 호환성을 위한 처리
      if isCallKitInUse() {
        // CallKit이 활성화된 경우, 현재 세션 설정을 유지하면서 옵션만 변경
        var options = session.categoryOptions
        
        if enabled {
          // 스피커 모드 활성화
          options.insert(.defaultToSpeaker)
        } else {
          // 스피커 모드 비활성화
          options.remove(.defaultToSpeaker)
        }
        
        // 현재 카테고리와 모드를 유지하면서 옵션만 변경
        try session.setCategory(session.category, mode: session.mode, options: options)
        
        // 세션이 이미 활성화되어 있으므로 다시 활성화하지 않음
        isSpeakerModeOn = enabled
        
        // 상태 변경 이벤트 전송
        sendAudioStateUpdate()
        
        result(true)
      } else {
        // CallKit이 비활성화된 경우, 기존 방식대로 처리
        if enabled {
          // 스피커 모드 활성화
          try session.setCategory(.playAndRecord, options: [
            .defaultToSpeaker,
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay
          ])
          try session.setMode(.voiceChat)
        } else {
          // 스피커 모드 비활성화
          try session.setCategory(.playAndRecord, options: [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay
          ])
          try session.setMode(.voiceChat)
        }
        
        try session.setActive(true)
        isSpeakerModeOn = enabled
        
        // 상태 변경 이벤트 전송
        sendAudioStateUpdate()
        
        result(true)
      }
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR", 
                         message: error.localizedDescription, 
                         details: nil))
    }
  }
  
  private func isExternalDeviceConnected() -> Bool {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    
    for output in outputs {
      // 헤드폰, 블루투스, 카 오디오 등 외부 기기인지 확인
      switch output.portType {
      case .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio, .usbAudio:
        return true
      default:
        continue
      }
    }
    
    return false
  }
  
  // CallKit이 현재 사용 중인지 확인
  private func isCallKitInUse() -> Bool {
    // 1. 오디오 세션 모드 확인
    let session = AVAudioSession.sharedInstance()
    if session.mode == .voiceChat && session.category == .playAndRecord {
      // CallKit이 일반적으로 이 모드와 카테고리를 사용함
      return true
    }
    
    // 2. 현재 통화 중인지 확인
    if isCallKitActive {
      return true
    }
    
    return false
  }
  
  // 오디오 라우트 변경 감지
  @objc private func audioRouteChanged(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt else {
      return
    }
    
    let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
    
    // 라우트 변경 이유에 따라 처리
    switch reason {
    case .newDeviceAvailable, // 새 기기 연결됨
         .oldDeviceUnavailable, // 기존 기기 연결 해제됨
         .categoryChange, // 카테고리 변경됨
         .override: // 다른 앱에 의해 오버라이드됨
      // 상태 변경 이벤트 전송
      sendAudioStateUpdate()
    default:
      break
    }
  }
  
  // 오디오 세션 인터럽션 처리 (CallKit 감지에 도움)
  @objc private func handleAudioSessionInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt else {
      return
    }
    
    let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    
    switch type {
    case .began:
      // 인터럽션 시작 (통화가 시작될 수 있음)
      isCallKitActive = true
    case .ended:
      // 인터럽션 종료 (통화가 종료될 수 있음)
      // 약간의 지연 후 상태를 확인하여 업데이트
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.isCallKitActive = self?.isCallKitInUse() ?? false
        self?.sendAudioStateUpdate()
      }
    @unknown default:
      break
    }
  }
  
  // 현재 오디오 상태 이벤트 전송
  private func sendAudioStateUpdate() {
    guard let eventSink = self.eventSink else { return }
    
    let isExternalConnected = isExternalDeviceConnected()
    
    // 외부 기기가 연결된 경우 스피커 모드를 강제로 비활성화
    if isExternalConnected && isSpeakerModeOn {
      do {
        let session = AVAudioSession.sharedInstance()
        
        if isCallKitInUse() {
          // CallKit이 활성화된 경우, 옵션만 변경
          var options = session.categoryOptions
          options.remove(.defaultToSpeaker)
          try session.setCategory(session.category, mode: session.mode, options: options)
        } else {
          // CallKit이 비활성화된 경우, 기존 방식대로 처리
          try session.setCategory(.playAndRecord, options: [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay
          ])
          try session.setMode(.voiceChat)
          try session.setActive(true)
        }
        
        isSpeakerModeOn = false
      } catch {
        print("오디오 세션 업데이트 실패: \(error.localizedDescription)")
      }
    }
    
    // 이벤트 전송
    eventSink([
      "isSpeakerOn": isSpeakerModeOn,
      "isExternalDeviceConnected": isExternalConnected
    ])
  }
}

// MARK: - FlutterStreamHandler
extension SpeakerModePlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    
    // 초기 상태 전송
    sendAudioStateUpdate()
    
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

// MARK: - CXCallObserverDelegate
extension SpeakerModePlugin: CXCallObserverDelegate {
  public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    isCallKitActive = !call.hasEnded
    
    // 약간의 지연 후 상태 업데이트 (CallKit이 오디오 세션을 완전히 설정할 시간을 줌)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.sendAudioStateUpdate()
    }
  }
}

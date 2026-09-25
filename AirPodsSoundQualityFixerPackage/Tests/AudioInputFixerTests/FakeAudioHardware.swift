import AudioInputFixer
import CoreAudio

@MainActor
final class FakeAudioHardware: AudioHardware {
  var devices: [AudioDevice]
  var defaultInput: AudioDeviceID?
  private(set) var setDefaultInputCalls: [AudioDeviceID] = []
  private var onChange: (@MainActor () -> Void)?

  init(devices: [AudioDevice], defaultInput: AudioDeviceID?) {
    self.devices = devices
    self.defaultInput = defaultInput
  }

  func inputDevices() -> [AudioDevice] { devices }

  func defaultInputDeviceID() -> AudioDeviceID? { defaultInput }

  func setDefaultInputDevice(_ id: AudioDeviceID) {
    setDefaultInputCalls.append(id)
    defaultInput = id
  }

  func observeChanges(_ onChange: @escaping @MainActor () -> Void) -> AudioHardwareObservation {
    self.onChange = onChange
    return AudioHardwareObservation {}
  }

  func simulateChange() {
    onChange?()
  }
}

extension AudioDevice {
  static let builtIn = AudioDevice(id: 117, uid: "BuiltInMicrophoneDevice", name: "MacBook Pro Microphone", isBuiltIn: true)
  static let airPods = AudioDevice(id: 130, uid: "AA-BB-CC:input", name: "AirPods Pro", isBuiltIn: false)
  static let interface = AudioDevice(id: 62, uid: "USBInterface", name: "USB Interface", isBuiltIn: false)
}

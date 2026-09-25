import CoreAudio
import Foundation

public struct CoreAudioHardware: AudioHardware {
  private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  public init() {}

  public func inputDevices() -> [AudioDevice] {
    deviceIDs().compactMap(inputDevice)
  }

  public func defaultInputDeviceID() -> AudioDeviceID? {
    var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
    var deviceID = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &deviceID)
    return status == noErr && deviceID != kAudioObjectUnknown ? deviceID : nil
  }

  public func setDefaultInputDevice(_ id: AudioDeviceID) {
    var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
    var deviceID = id
    AudioObjectSetPropertyData(
      Self.systemObject, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID
    )
  }

  public func observeChanges(_ onChange: @escaping @MainActor () -> Void) -> AudioHardwareObservation {
    let selectors = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]
    let listener: AudioObjectPropertyListenerBlock = { _, _ in
      MainActor.assumeIsolated { onChange() }
    }
    for selector in selectors {
      var address = Self.address(selector)
      AudioObjectAddPropertyListenerBlock(Self.systemObject, &address, .main, listener)
    }
    return AudioHardwareObservation {
      for selector in selectors {
        var address = Self.address(selector)
        AudioObjectRemovePropertyListenerBlock(Self.systemObject, &address, .main, listener)
      }
    }
  }

  private func deviceIDs() -> [AudioDeviceID] {
    var address = Self.address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(Self.systemObject, &address, 0, nil, &size) == noErr else {
      return []
    }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &ids) == noErr else {
      return []
    }
    // The device list can shrink between the size query and the read.
    return Array(ids.prefix(Int(size) / MemoryLayout<AudioDeviceID>.size))
  }

  private func inputDevice(_ id: AudioDeviceID) -> AudioDevice? {
    var streamsAddress = Self.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
    var streamsSize: UInt32 = 0
    guard
      AudioObjectGetPropertyDataSize(id, &streamsAddress, 0, nil, &streamsSize) == noErr,
      streamsSize > 0,
      let uid = string(kAudioDevicePropertyDeviceUID, of: id),
      let name = string(kAudioObjectPropertyName, of: id)
    else { return nil }

    var address = Self.address(kAudioDevicePropertyTransportType)
    var transportType: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transportType)

    return AudioDevice(
      id: id, uid: uid, name: name, isBuiltIn: transportType == kAudioDeviceTransportTypeBuiltIn
    )
  }

  private func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
    var address = Self.address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
    return value?.takeRetainedValue() as String?
  }

  private static func address(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain
    )
  }
}

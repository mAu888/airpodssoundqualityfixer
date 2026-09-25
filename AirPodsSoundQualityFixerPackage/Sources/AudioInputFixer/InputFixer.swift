import CoreAudio
import Foundation
import Observation

/// Keeps the system default input on the preferred device, or on the built-in microphone when no
/// preferred device is connected, so that AirPods stay in their high-quality output mode.
@MainActor
@Observable
public final class InputFixer {
  public private(set) var devices: [AudioDevice] = []
  public private(set) var forcedDevice: AudioDevice?
  public var isPaused = false {
    didSet { refresh() }
  }

  @ObservationIgnored private let hardware: any AudioHardware
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var observation: AudioHardwareObservation?

  public init(hardware: any AudioHardware, defaults: UserDefaults = .standard) {
    self.hardware = hardware
    self.defaults = defaults
  }

  public func start() {
    observation = hardware.observeChanges { [weak self] in self?.refresh() }
    devices = hardware.inputDevices()
    migrateLegacyDeviceID()
    refresh()
  }

  public func select(_ device: AudioDevice) {
    defaults.set(device.uid, forKey: Keys.forcedDeviceUID)
    refresh()
  }

  private func refresh() {
    devices = hardware.inputDevices()
    forcedDevice = Self.deviceToForce(
      in: devices, preferredUID: defaults.string(forKey: Keys.forcedDeviceUID)
    )
    guard !isPaused, let forcedDevice, hardware.defaultInputDeviceID() != forcedDevice.id else {
      return
    }
    hardware.setDefaultInputDevice(forcedDevice.id)
  }

  static func deviceToForce(in devices: [AudioDevice], preferredUID: String?) -> AudioDevice? {
    devices.first { $0.uid == preferredUID } ?? devices.first(where: \.isBuiltIn)
  }

  /// The Objective-C releases stored a numeric `AudioDeviceID`, which CoreAudio can reassign after
  /// a reboot, so it is only trusted if a matching device is connected at the first launch.
  private func migrateLegacyDeviceID() {
    guard defaults.object(forKey: Keys.legacyDeviceID) != nil else { return }
    let legacyID = defaults.integer(forKey: Keys.legacyDeviceID)
    defaults.removeObject(forKey: Keys.legacyDeviceID)
    if defaults.string(forKey: Keys.forcedDeviceUID) == nil,
      let device = devices.first(where: { Int($0.id) == legacyID })
    {
      defaults.set(device.uid, forKey: Keys.forcedDeviceUID)
    }
  }

  enum Keys {
    static let forcedDeviceUID = "ForcedDeviceUID"
    static let legacyDeviceID = "Device"
  }
}

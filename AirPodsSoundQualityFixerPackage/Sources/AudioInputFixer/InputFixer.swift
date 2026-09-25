import CoreAudio
import Foundation
import Observation
import os

/// Keeps the system default input on the preferred device, or on the built-in microphone when no
/// preferred device is connected, so that AirPods stay in their high-quality output mode.
@MainActor
@Observable
public final class InputFixer {
  public private(set) var devices: [AudioDevice] = []
  public private(set) var forcedDevice: AudioDevice?
  /// The device the last forcing attempt could not make the default input.
  public private(set) var failedDevice: AudioDevice?
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
      failedDevice = nil
      return
    }
    if hardware.setDefaultInputDevice(forcedDevice.id) {
      failedDevice = nil
    } else {
      failedDevice = forcedDevice
      Logger().error("Could not make \(forcedDevice.name) the default input")
    }
  }

  static func deviceToForce(in devices: [AudioDevice], preferredUID: String?) -> AudioDevice? {
    devices.first { $0.uid == preferredUID } ?? devices.first(where: \.isBuiltIn)
  }

  enum Keys {
    static let forcedDeviceUID = "ForcedDeviceUID"
  }
}

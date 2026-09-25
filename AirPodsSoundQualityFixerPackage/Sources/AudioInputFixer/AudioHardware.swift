import CoreAudio

@MainActor
public protocol AudioHardware {
  func inputDevices() -> [AudioDevice]
  func defaultInputDeviceID() -> AudioDeviceID?
  func setDefaultInputDevice(_ id: AudioDeviceID)
  /// Calls `onChange` on the main queue when the device list or the default input device changes,
  /// until the returned observation is released.
  func observeChanges(_ onChange: @escaping @MainActor () -> Void) -> AudioHardwareObservation
}

public final class AudioHardwareObservation {
  private let cancel: () -> Void

  public init(cancel: @escaping () -> Void) {
    self.cancel = cancel
  }

  deinit {
    cancel()
  }
}

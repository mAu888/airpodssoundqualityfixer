import CoreAudio

public struct AudioDevice: Equatable, Identifiable, Sendable {
  public let id: AudioDeviceID
  /// Stable across reboots and reconnects, unlike `id`.
  public let uid: String
  public let name: String
  public let isBuiltIn: Bool

  public init(id: AudioDeviceID, uid: String, name: String, isBuiltIn: Bool) {
    self.id = id
    self.uid = uid
    self.name = name
    self.isBuiltIn = isBuiltIn
  }
}

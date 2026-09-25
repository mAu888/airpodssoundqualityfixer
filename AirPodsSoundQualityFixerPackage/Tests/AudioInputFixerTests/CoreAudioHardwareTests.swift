@testable import AudioInputFixer
import CustomDump
import Foundation
import Testing

@MainActor
struct CoreAudioHardwareTests {
  @Test func releasingObservationRemovesHandler() async {
    let initialCount = CoreAudioHardware.ListenerRegistry.count
    do {
      let observation = CoreAudioHardware().observeChanges {}
      expectNoDifference(CoreAudioHardware.ListenerRegistry.count, initialCount + 1)
      withExtendedLifetime(observation) {}
    }

    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }

    expectNoDifference(CoreAudioHardware.ListenerRegistry.count, initialCount)
  }
}

import AudioInputFixer
import CustomDump
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct InputFixerTests {
  let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: "AudioInputFixerTests")!
    defaults.removePersistentDomain(forName: "AudioInputFixerTests")
  }

  @Test func forcesBuiltInMicrophoneWithoutPreference() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, .builtIn)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func leavesDefaultInputAloneWhenAlreadyForced() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func forcesInputAgainWhenSystemSwitchesToAirPods() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()

    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func selectingDeviceForcesAndPersistsIt() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    fixer.select(.interface)

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.interface.id])

    let relaunched = InputFixer(hardware: hardware, defaults: defaults)
    relaunched.start()
    expectNoDifference(relaunched.forcedDevice, .interface)
  }

  @Test func fallsBackToBuiltInWhilePreferredDeviceIsDisconnected() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(.interface)

    hardware.devices = [.airPods, .builtIn]
    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .builtIn)

    hardware.devices = [.airPods, .builtIn, .interface]
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(
      hardware.setDefaultInputCalls,
      [AudioDevice.interface.id, AudioDevice.builtIn.id, AudioDevice.interface.id]
    )
  }

  @Test func doesNotForceWhilePaused() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.isPaused = true

    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()
    expectNoDifference(hardware.setDefaultInputCalls, [])

    fixer.isPaused = false
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func doesNotForceWithoutBuiltInOrPreferredDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, nil)
    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func migratesLegacyDeviceIDOfConnectedDevice() {
    defaults.set(Int(AudioDevice.interface.id), forKey: "Device")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(defaults.string(forKey: "ForcedDeviceUID"), AudioDevice.interface.uid)
    expectNoDifference(defaults.object(forKey: "Device") == nil, true)
  }

  @Test func dropsLegacyDeviceIDOfUnknownDevice() {
    defaults.set(Int(UInt32.max), forKey: "Device")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, .builtIn)
    expectNoDifference(defaults.string(forKey: "ForcedDeviceUID"), nil)
    expectNoDifference(defaults.object(forKey: "Device") == nil, true)
  }
}

import AudioInputFixer
import SwiftUI

struct MenuContent: View {
  @Bindable var fixer: InputFixer
  @Binding var isIconVisible: Bool
  @Environment(\.openURL) private var openURL

  var body: some View {
    Text(Self.version)
    Divider()
    Toggle("Pause", isOn: $fixer.isPaused)
    Divider()
    Picker("Forced input:", selection: forcedDeviceUID) {
      ForEach(fixer.devices) { device in
        Text(device.name).tag(Optional(device.uid))
      }
    }
    .pickerStyle(.inline)
    if let failedDevice = fixer.failedDevice {
      Text("Could not switch the input to \(failedDevice.name)")
    }
    Divider()
    LaunchAtLoginToggle()
    Divider()
    Button("Donate if you like the app") {
      openURL(URL(string: "https://paypal.me/milgra")!)
    }
    Button("Check for updates") {
      openURL(URL(string: "https://github.com/mAu888/airpodssoundqualityfixer/releases")!)
    }
    Button("Hide") {
      isIconVisible = false
    }
    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
  }

  private var forcedDeviceUID: Binding<String?> {
    Binding {
      fixer.forcedDevice?.uid
    } set: { uid in
      if let device = fixer.devices.first(where: { $0.uid == uid }) {
        fixer.select(device)
      }
    }
  }

  private static let version: String = {
    let info = Bundle.main.infoDictionary ?? [:]
    let shortVersion = info["CFBundleShortVersionString"] as? String ?? "?"
    let build = info["CFBundleVersion"] as? String ?? "?"
    return "Version \(shortVersion) (build \(build))"
  }()
}

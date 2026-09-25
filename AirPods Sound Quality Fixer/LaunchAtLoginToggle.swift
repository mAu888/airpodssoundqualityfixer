import ServiceManagement
import SwiftUI
import os

struct LaunchAtLoginToggle: View {
  @State private var isEnabled = Self.isRegistered

  var body: some View {
    Toggle("Open at login", isOn: Binding(get: { isEnabled }, set: setEnabled))
      // The user can also change the login item in System Settings while the app runs.
      .onAppear { isEnabled = Self.isRegistered }
  }

  private func setEnabled(_ enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      Logger().error("Updating login item failed: \(error)")
    }
    if service.status == .requiresApproval {
      SMAppService.openSystemSettingsLoginItems()
    }
    isEnabled = Self.isRegistered
  }

  private static var isRegistered: Bool {
    SMAppService.mainApp.status == .enabled
  }
}

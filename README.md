# AirPods Sound Quality Fixer And Battery Life Enhancer For MacOS

Fixes sound quality drops when using AirPods with Macs. 
It forces the default audio input to be the built-in microphone instead of AirPods' microphone so MacOS doesn't have to mix down the output. 
It also increases battery life because AirPods doesn't have to broadcast sound back.
If you have more input devices you can select which device you want to force over the AirPods microphone.

The app runs in the menu bar.

Download the compiled application from [releases](https://github.com/milgra/airpodssoundqualityfixer/releases/tag/1.0)

## Building

Requires macOS 14 or later.

Open `AirPodsSoundQualityFixerWorkspace.xcworkspace`, not the `.xcodeproj`.
The workspace contains the app target and the `AirPodsSoundQualityFixerPackage` Swift package, which holds the CoreAudio and device-forcing logic.

Run the tests with ⌘U in Xcode or `swift test` in `AirPodsSoundQualityFixerPackage`.

# Framework Detector

[中文](README_zh.md) | **English**

<p align="center">
  <img src="Framework detector/Assets.xcassets/AppIcon.appiconset/app_icon.png" width="128" alt="App Icon">
</p>

Framework Detector is a powerful and elegant macOS application built with SwiftUI that helps you quickly identify the CPU architectures of your installed applications and command-line tools.

## ✨ Features

- **Deep Architecture Detection**: Instantly know if an app is compiled for **Intel**, **Apple Silicon**, or **Universal**.
- **Package Manager Support**: Seamlessly scans software installed via **Homebrew** and **MacPorts**, resolving symlinks to inspect the actual Mach-O binaries.
- **Dynamic Hardware Icons**: The Apple Silicon icon dynamically adapts to match your current Mac model (MacBook, Mac mini, Mac Studio, iMac, Mac Pro).
- **Multi-language Support**: Fully localized in English, Simplified Chinese, and Traditional Chinese.
- **Auto-Updates**: Integrated with **Sparkle** for seamless, automatic OTA updates.
- **Quick Actions**: Right-click any app or package to reveal it in Finder or copy its path.

## 🚀 Installation

1. Download the latest `.zip` release from the [Releases](../../releases) page.
2. Unzip and drag the `Framework detector.app` into your `/Applications` folder.
3. Launch the app!

*(Note: If you encounter a Gatekeeper warning, go to System Settings -> Privacy & Security -> Open Anyway).*

## 🛠️ Build from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/YourUsername/FrameworkDetector.git
   ```
2. Open `Framework detector.xcodeproj` in Xcode 15 or later.
3. Ensure the target device is set to **My Mac**.
4. Press `Cmd + R` to build and run the application.

## 🔐 Permissions

To scan package managers like Homebrew and MacPorts, Framework Detector may require **Full Disk Access** due to macOS sandbox restrictions.
- The app will gently prompt you with instructions to grant this permission in `System Settings -> Privacy & Security -> Full Disk Access` if necessary.

## 🔄 Sparkle Updates

This app supports OTA updates via the [Sparkle Framework](https://sparkle-project.org). 
If you are compiling this project yourself and want to distribute it:
1. Ensure the Sparkle dependency is added via Swift Package Manager.
2. Generate your EdDSA keys (`generate_keys` tool) and place the **`SUPublicEDKey`** in your `Info.plist`.
3. Set your **`SUFeedURL`** in the `Info.plist` to point to your `appcast.xml` hosted on GitHub Pages or your own server.

## 📄 License

This project is licensed under the MIT License. Feel free to use, modify, and distribute it.

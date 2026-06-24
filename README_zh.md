# 架构检测器 (Framework Detector)

**中文** | [English](README.md)

<p align="center">
  <img src="Framework detector/Assets.xcassets/AppIcon.appiconset/app_icon.png" width="128" alt="App Icon">
</p>

架构检测器（Framework Detector）是一款强大且优雅的 macOS 原生应用程序，帮助你快速识别系统中已安装应用和命令行工具的 CPU 架构。

## ✨ 功能特性

- **深度架构检测**: 一键识别应用架构，轻松辨别应用是编译为 **Intel**、**Apple Silicon** 还是 **Universal**。
- **包管理器支持**: 完美支持扫描 **Homebrew** 与 **MacPorts** 软件包，可自动解析软链接读取底层的 Mach-O 二进制文件。
- **动态硬件图标**: “Apple Silicon”筛选标签会根据你当前使用的 Mac 型号（MacBook、Mac mini、Mac Studio、iMac、Mac Pro）自动显示对应的系统硬件图标。
- **多语言支持**: 完美内置**英文**、**简体中文**和**繁体中文**。
- **自动更新**: 内部整合了 **Sparkle** 框架，支持静默且安全的 OTA 自动升级。
- **快捷操作**: 右键点击任意应用或包，快速在 Finder 中显示文件或复制完整路径。

## 🚀 安装与使用

1. 在 [Releases](../../releases) 页面下载最新版本的 `.zip` 压缩包。
2. 解压并将 `Framework detector.app` 拖入你的 `/Applications` (应用程序) 文件夹。
3. 双击运行！

*(注意：如果遇到系统安全拦截提示“无法验证开发者”，请前往“系统设置 -> 隐私与安全性”中点击“仍要打开”)*

## 🛠️ 源码编译

1. 克隆此代码仓库:
   ```bash
   git clone https://github.com/Seamain/Framework-detector.git
   ```
2. 在 Xcode 15 或更高版本中打开 `Framework detector.xcodeproj`。
3. 确保你的目标设备（Target Device）选择的是 **My Mac**。
4. 按下 `Cmd + R` 编译并运行。

## 🔐 关于沙盒权限

由于 macOS 的沙盒安全机制，为了能够顺利扫描到 `/usr/local` 或 `/opt/homebrew` 内部的命令行工具，应用可能需要**完全磁盘访问权限 (Full Disk Access)**。
- 遇到权限不足时，应用会自动弹出友好的指引弹窗，协助你前往 `系统设置 -> 隐私与安全性` 中快速开启。

## 🔄 关于配置自动更新

本项目依赖 [Sparkle](https://sparkle-project.org) 提供 OTA 更新支持。
如果你想编译并二次分发这个项目：
1. 请确保在 Xcode 的 Swift Package Manager 中添加了 Sparkle 依赖。
2. 使用 Sparkle 的 `generate_keys` 工具生成 EdDSA 密钥对，并将生成的 **`SUPublicEDKey`** 添加到你的 `Info.plist` 中。
3. 将 `Info.plist` 中的 **`SUFeedURL`** 替换为你自己部署在 GitHub Pages 或私有服务器上的 `appcast.xml` 地址。

## 📄 开源协议

本项目基于 MIT 协议开源。欢迎自由学习、修改和分发。

# Panto

**自动缩放的屏幕录制工具。** 免费、开源、原生 macOS。

[English](README.md) · [Русский](README.ru.md)

![Panto demo](docs/demo.gif)

Screen Studio 卖 $89。Panto 只做大多数人真正会用的那一件事：把演示里重要的部分放大。

## 功能

- **按原生分辨率录制**任意显示器，不缩放、文字不糊。HEVC，60 fps，约 40 Mbps。
- **同时录制系统声音和麦克风**，两条独立音轨，导出时混合。
- **三种缩放触发**：点击、自定义快捷键（默认 `⌥⌘Z`）、或两者同时。
- **悬浮录制条**，带缩放和停止按钮，而且**不会出现在视频里**。
- **时间线编辑器**：拖动缩放块、点击画面添加缩放、删除、调整强度、重新导出。
- 导出 H.264 `.mp4`，原始 `.mov` 永远保留。无账号、无遥测、无 Electron。

## 安装

从 [Releases](../../releases/latest) 下载 `Panto.dmg`，拖进「应用程序」。

一行命令安装：

```sh
curl -fsSL https://raw.githubusercontent.com/USER/panto/main/install.sh | bash
```

Panto 还没有公证。如果 macOS 拒绝第一次启动，右键 → 打开；或者运行：

```sh
xattr -dr com.apple.quarantine /Applications/Panto.app
```

从源码构建（只需 Command Line Tools）：

```sh
git clone https://github.com/USER/panto.git
cd panto
./scripts/make_app.sh
open build/Panto.app
```

## 权限

| 权限 | 用途 | 是否必需 |
|---|---|---|
| 屏幕录制（含系统声音） | 录制画面和声音 | 必需 |
| 麦克风 | 解说音轨 | 可选 |
| 辅助功能 | 检测点击来自动缩放 | 可选（没有它就用快捷键） |

授权后需要退出并重新打开 Panto，macOS 才会应用权限。

## 使用

1. 选择显示器和缩放触发方式。
2. 点红色按钮开始录制，窗口会隐藏，出现悬浮控制条。
3. 需要放大时按 `⌥⌘Z`（或点悬浮条上的 **Zoom**）。
4. 停止后进入编辑器：点击画面放置缩放，拖动色块调整位置，点 **Export**。

文件保存在 `~/Movies/Panto/`。

## 开发

```sh
make app          # 构建 Panto.app
make selftest     # 用合成画面测试镜头算法，不需要任何权限
swift test        # 单元测试（需要完整 Xcode）
```

架构说明见 [docs/architecture.md](docs/architecture.md)，贡献指南见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT。

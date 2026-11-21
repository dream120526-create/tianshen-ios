# 天神辅助 · iOS 端

安卓版（`com.radar.local`，v3.1）的 iOS 原生重写：**无卡密、无账号、无服务器、无作者信息**，
模型全部离线跑在设备上，低配 / 中配 / 高配三档自选。

---

## 1 长什么样

- 全屏相机取景 + 实时目标框（四角括号 + 类别 + 置信度）
- 顶部状态胶囊：模型档位 · 目标数 · FPS · 方位角，点开是控制面板
- 可开关：方框 / 骨骼 / 雷达 / 射线
- 绘制模式：单人物（只画人）/ 多物品（按类别开关）
- 识别类别过滤：人、动物、车辆三组共 19 类
- 探测灵敏度滑杆（默认 22%，人额外要求 35%）
- 诊断面板：模型路径、推理耗时、帧率、可用档位

## 2 三档模型

| 档位 | 网络 | 输入 | 体积 | 适用 |
|---|---|---|---|---|
| 低配 | YOLOv8n | 416×416 | 12 MB | 老机型、长时间开 |
| 中配 | YOLOv8s | 416×416 | 43 MB | 大多数机型 |
| 高配 | YOLOv8m | 416×416 | 99 MB | A15 及以上 |

三档模型**都已内置进 App**（合计约 154 MB）：低配直接来自安卓版 `assets/yolov8n.onnx`，
中/高配由 `Tools/fetch_models.py` 从 Ultralytics 官方权重按 `imgsz=416 opset=12` 导出。

补中/高配：

```bash
pip install ultralytics
python Tools/fetch_models.py          # 只补缺失档位
```

或者手动导出后丢进 `TianShen/Resources/Models/`：

```bash
yolo export model=yolov8s.pt format=onnx imgsz=416 opset=12
yolo export model=yolov8m.pt format=onnx imgsz=416 opset=12
```

**文件名必须固定**：`yolov8n.onnx` / `yolov8s.onnx` / `yolov8m.onnx`。

不想改工程也行：App 运行后会把内置模型复制到
`文件 App → 我的 iPhone → 天神辅助 → Models`，把新的 `.onnx` 拖进去就能用（优先读这里）。

> 一定要按 `imgsz=416` 导出。用 640 的模型会在 letterbox 阶段被缩到 416，框会偏。

## 3 推理后端（重要）

**不依赖 SPM、不依赖 CocoaPods、不联网。**

`Vendor/onnxruntime.framework` 是官方 `pod-archive-onnxruntime-c-1.24.2` 里的 iOS 静态
framework（arm64，39 MB），已随仓库提供：

- `TianShen/Detection/ONNXBridge.h/.mm` 用 ONNX Runtime 的 **C++ API** 封了一层薄桥
  （加载 session、跑一次前向），只给 Swift 暴露两个方法
- Swift 侧通过桥接头 `TianShen-Bridging-Header.h` 使用，`Detector.swift` 里没有一行 C++
- 链接参数：`-lz -lc++`，并链 `CoreML` / `Accelerate`

> 为什么不用官方的 Swift Package：`microsoft/onnxruntime-swift-package-manager` 上游
> 仓库已经下线（2026-11-18），只剩第三方镜像；镜像随时可能消失，CI 会随机红。
> 把 39 MB 静态库放进仓库，构建过程就完全确定了。

**只有 arm64 真机切片**，模拟器（x86_64 / arm64-sim）跑不了，请直接上真机。

## 4 构建

### 4.1 没有 Mac（推荐）

把 `ios/` 目录下的内容作为新仓库的根目录推上去，Actions 会自动出包：

```
.github/workflows/build-ipa.yml   # macos-15 + Xcode 26.3 + XcodeGen，无需拉包
```

触发后取 `unsigned-ipa` artifact，得到 `TianShen-unsigned.ipa`。
签名按《iOS-IPA构建与签名指南》第 4 节（p12 转 3DES + profile 抽 entitlements + codesign）。

### 4.2 有 Mac

```bash
brew install xcodegen
xcodegen generate
open TianShen.xcodeproj
```

Xcode 里选真机 → 直接 Run。

### 4.3 本地静态检查（Windows 也能跑）

```bash
python Tools/check_swift.py
```

查括号配平、import、文件清单。编译只能在 macOS 上做。

## 5 目录

```
TianShen/
  App/         TianShenApp.swift、RootView.swift
  Camera/      CameraController（AVCaptureSession）、CameraPreview
  Detection/   Detector、ONNXBridge.h/.mm、DetectionPipeline（120ms 节流）
  Render/      DetectionOverlay（框 / 射线 / 雷达，SwiftUI Canvas）
  UI/          HUDView、NoticeView、FilterView、DiagView、Theme
  Core/        ModelTier、Catalog、SettingsStore、ModelStore、Compass
  Resources/Models/yolov8n.onnx
Vendor/        onnxruntime.framework（官方 1.24.2，静态库）
Tools/         fetch_models.py、check_swift.py
project.yml    XcodeGen 工程描述
```

## 6 与安卓版的差异

去掉：卡密登录、设备绑定、圣杯抽卡、管理员后台（"地球online"控制台）、作者相关文案、
WebView 架构、`libprotect.so` 的签名/DEX 校验。

保留：检测参数（416 letterbox、灰底 153、原生阈值 0.2、NMS IoU 0.45、120 ms 节流、
人 0.35 阈值）、19 类目标、绘制样式、雷达/射线观感、灵敏度与类别过滤语义。

架构变化：安卓是 WebView + JS 桥 + Java ONNX；iOS 是纯原生 SwiftUI + C++ 直连，
没有 JS 层，也没有 JPEG 编解码那一跳（直接吃 CVPixelBuffer）。

## 7 排错

| 现象 | 处理 |
|---|---|
| 链接报 `framework not found onnxruntime` | 确认 `Vendor/onnxruntime.framework` 在仓库里，且 `FRAMEWORK_SEARCH_PATHS` 含 `$(PROJECT_DIR)/Vendor` |
| 报一堆 `Undefined symbols: std::__1::...` | 没链 libc++，检查 `OTHER_LDFLAGS` 里的 `-lc++` |
| 模拟器跑不起来 | 设计如此，只有 arm64 真机切片 |
| 画面上框整体偏移 | 模型不是 `imgsz=416` 导出的，重新导出 |
| 一直提示「缺少模型文件」 | 确认文件名是 `yolov8n.onnx` 等三选一，放在 Documents/Models 或 Resources/Models |
| 装上去闪退 | 重签时漏了 `--generate-entitlement-der`（见指南 4.6） |

## 8 依赖

- onnxruntime 1.24.2 静态 framework（MIT，官方 pod-archive，已 vendor）
- YOLOv8 权重（AGPL-3.0，Ultralytics），仅本地推理
- 无网络请求、无统计 SDK、无第三方 UI 框架

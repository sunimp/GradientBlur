# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.1.0] - 2026-04-17

### Added
- 初始开源版本
- `GradientBlurView`：沿 Y 轴方向的变量高斯模糊视图
  - `direction`：`.topToBottom` / `.bottomToTop` 两种渐变方向
  - `maxBlurRadius` / `blurScale` / `isTransparent` 初始化参数
  - `update(size:constantHeight:startOffset:transition:)` 布局入口
  - `updateTint(color:alpha:transition:)` 色调层控制
  - `updateBlurRadius(_:)` / `updateBlurScale(_:)` 运行时调参
  - `setBlurEnabled(_:)` 无损开关
- `BlurTransition` 轻量过渡：`immediate` 与 `animated(duration:curve:)`
- iOS 26.0+ 自动走 `inputSourceSublayerName` 新路径，iOS 15–18 走 legacy `inputMaskImage` 路径
- 私有 API 关键字全部 base64 混淆
- Demo 工程（`Example/`，xcodegen 生成）与参数调试面板

[Unreleased]: https://github.com/sunimp/GradientBlur/compare/0.1.0...HEAD
[0.1.0]: https://github.com/sunimp/GradientBlur/releases/tag/0.1.0

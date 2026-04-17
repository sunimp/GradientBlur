# 贡献指南

欢迎为 GradientBlur 做贡献。本文说明本地构建、运行 Demo、代码规范和提交流程。

## 环境要求

- macOS 14 或更高
- Xcode 16 或更高（需要 Swift 6 工具链）
- [xcodegen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`，仅 Demo 工程生成需要）
- [swiftformat](https://github.com/nicklockwood/SwiftFormat)（`brew install swiftformat`）

## 本地构建

```bash
# 编译 SwiftPM 库
xcodebuild -scheme GradientBlur -destination 'generic/platform=iOS Simulator' build

# 跑单元测试
xcodebuild -scheme GradientBlur -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

## 运行 Demo

```bash
cd Example
xcodegen generate
open GradientBlurDemo.xcodeproj
```

Demo 是验证视觉改动的主要手段；任何影响 `GradientBlurView` 输出外观的改动**都必须**在 Demo 里跑通对应场景。

## 代码规范

### 文件头

每个新建的 `.swift` 文件必须包含版权信息头，日期为创建当天的实际日期：

```swift
//
//  <FileName>.swift
//  GradientBlur
//
//  Created by <Author> on <YYYY/M/D>.
//
```

### 注释

- 使用简体中文撰写注释，除非涉及外部 API 名称
- 默认不写注释；只在 **WHY 非显而易见** 时写（隐藏约束、不变量、对特定 bug 的规避、会让读者意外的行为）
- 不写 WHAT（变量名本身应该说明）

### 格式化

修改或新增 `.swift` 文件后，**必须**对该文件单独运行 `swiftformat`：

```bash
swiftformat Sources/GradientBlur/Internal/VariableBlurLayer.swift
```

**禁止**跑全项目 / 全模块格式化（`swiftformat .` / `swiftformat Sources/` 等）。只格式化自己改过的文件。

### 私有 API 约定

本库依赖 Apple 私有 API 时，所有关键字（类名、selector、filter 名、KVC 键）**必须**做 base64 混淆，经 `CAFilterBridge` / `CAFilterInputKey` 统一出口，避免源码和二进制里出现字面量。

新增私有 API 用法时：

1. 在 `PrivateAPI/CAFilterBridge.swift` 或相邻文件中以 base64 形式存储字符串
2. 运行时解码一次并缓存为 `nonisolated(unsafe) static let`
3. 所有调用走该文件暴露的 Swift 接口

## 提交流程

### Commit 消息

- 使用简体中文撰写（项目内部约定）
- 动宾结构，祈使句，首行不超过 50 字
- 只描述 **WHY**：为什么做这个改动；不描述 **WHAT**（diff 能看出来）

良好示例：

```
修复 iOS 15 legacy 路径下 mask 图高度超过 800pt 时的裁剪异常

原版 CAFilter 对 inputMaskImage 超长时会静默丢弃，
改为合成 min(800, size.height) 的 mask。
```

### Pull Request

- PR 标题同样动宾结构
- 描述请使用仓库的 PR 模板
- **必须在 iOS 15.x 和 iOS 26.x 两档各验证一次**（涉及视觉的改动）
- 公共 API 改动需同步更新 README

### 不要做的事

- 不要跑全项目格式化
- 不要在未讨论的情况下引入第三方依赖
- 不要在源码里写 `CAFilter` / `CABackdropLayer` / `variableBlur` 等字面量（必须 base64 混淆）
- 不要 `git push --force` / `git reset --hard` 到已推送分支
- 不要在 commit 里包含无关改动（空格整理 / 不相关重命名等）

## 反馈

- Bug / Feature：开 Issue，使用仓库模板
- 讨论 / 使用问题：开 Discussion

感谢你的贡献。

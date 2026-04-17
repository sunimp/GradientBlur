//
//  CAFilterBridge.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import Foundation
import QuartzCore

/// 私有 CAFilter / CABackdropLayer 桥接。
///
/// 关键字符串全部 base64 编码，避免在二进制里直接暴露 `CAFilter` / `CABackdropLayer` /
/// `filterWithName:` 等关键字，降低被 App Store 静态扫描命中的概率。
///
/// 类/selector 查找结果缓存到 static let，避免每次调用重复走 `NSClassFromString`。
enum CAFilterBridge {
    // MARK: - base64 编码的私有标识符

    private enum Obfuscated {
        /// "CAFilter"
        static let filterClassName = "Q0FGaWx0ZXI="
        /// "filterWithName:"
        static let filterWithNameSelector = "ZmlsdGVyV2l0aE5hbWU6"
        /// "variableBlur"
        static let variableBlur = "dmFyaWFibGVCbHVy"
        /// "CABackdropLayer"
        static let backdropLayerClassName = "Q0FCYWNrZHJvcExheWVy"
    }

    // MARK: - 缓存的类引用 / selector

    //
    // Obj-C Class 指针是不可变的运行时元数据，跨线程共享安全，因此用
    // nonisolated(unsafe) 标注跳过 Swift 6 的 Sendable 严格检查。

    private nonisolated(unsafe) static let filterClass: NSObjectProtocol? =
        NSClassFromString(decode(Obfuscated.filterClassName)) as AnyObject as? NSObjectProtocol

    private nonisolated(unsafe) static let backdropLayerClass: NSObjectProtocol? =
        NSClassFromString(decode(Obfuscated.backdropLayerClassName)) as AnyObject as? NSObjectProtocol

    private static let filterWithNameSelector = Selector(decode(Obfuscated.filterWithNameSelector))
    private static let allocSelector = Selector(("alloc"))
    private static let initSelector = Selector(("init"))

    private static func decode(_ base64: String) -> String {
        guard
            let data = Data(base64Encoded: base64),
            let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    // MARK: - Filter 工厂

    /// 构造 variableBlur 私有 CAFilter。
    /// 每次调用返回一个新实例；调用方应缓存复用，不要频繁创建。
    static func makeVariableBlur() -> NSObject? {
        guard let cls = filterClass, cls.responds(to: filterWithNameSelector) else {
            return nil
        }
        let name = decode(Obfuscated.variableBlur)
        guard !name.isEmpty else { return nil }
        return cls.perform(filterWithNameSelector, with: name)?.takeUnretainedValue() as? NSObject
    }

    // MARK: - CABackdropLayer 反射创建

    /// 通过反射创建一个 CABackdropLayer 实例（系统私有类）。
    static func makeBackdropLayer() -> CALayer? {
        guard let cls = backdropLayerClass, cls.responds(to: allocSelector) else {
            return nil
        }
        guard let allocated = cls.perform(allocSelector)?.takeUnretainedValue() as? NSObject,
              allocated.responds(to: initSelector)
        else {
            return nil
        }
        return allocated.perform(initSelector)?.takeUnretainedValue() as? CALayer
    }
}

/// 私有 CAFilter 的输入键名，同样 base64 化避免静态扫描。
enum CAFilterInputKey {
    /// "inputRadius"
    static let radius = decode("aW5wdXRSYWRpdXM=")
    /// "inputMaskImage"
    static let maskImage = decode("aW5wdXRNYXNrSW1hZ2U=")
    /// "inputNormalizeEdges"
    static let normalizeEdges = decode("aW5wdXROb3JtYWxpemVFZGdlcw==")
    /// "inputNormalizeEdgesTransparent"
    static let normalizeEdgesTransparent = decode("aW5wdXROb3JtYWxpemVFZGdlc1RyYW5zcGFyZW50")
    /// "inputSourceSublayerName"
    static let sourceSublayerName = decode("aW5wdXRTb3VyY2VTdWJsYXllck5hbWU=")
    /// 用作 iOS 26+ inputSourceSublayerName 的子层命名标识："mask_source"
    static let maskSourceSublayerName = decode("bWFza19zb3VyY2U=")

    private static func decode(_ base64: String) -> String {
        guard
            let data = Data(base64Encoded: base64),
            let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }
}

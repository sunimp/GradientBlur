//
//  VariableBlurLayer.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import QuartzCore
import UIKit

/// 绑定到指定 `CALayer`（约定为 CABackdropLayer）的变量模糊效果。
///
/// 两条并行路径：
/// - **iOS 26+ `inputSourceSublayerName`**：用一个命名裸 CALayer（`mask_source`）承载蒙版图。
///   只要形状 / 位置不变，改半径只需重装 filter；蒙版图变化时只改子 layer 的 contents。
/// - **iOS 15-18 legacy `inputMaskImage`**：把蒙版 CGImage 写入 filter 自身的 input 键；
///   形状或半径变化都要重装 filter。
///
/// 蒙版位图会缓存，只在 shape 或 height 真正变化时才重绘。
///
/// - Important: `CAFilter` 是 NSObject，但 CA 仅在 `CALayer.filters` 被 **重新赋值为包含新实例
///   的数组** 时才会重采样。仅改 `filter.setValue(..., forKey:)` 或用同一个实例重装 `filters[]`
///   都不会触发重算。因此所有需要 filter 侧变化（半径、mask 图、归一化策略）的操作都走
///   `installFilter(maskImage:)` 走新实例重装。
@MainActor
final class VariableBlurLayer {
    struct Params: Equatable {
        let size: CGSize
        let constantHeight: CGFloat
        let position: Position
        let inwardsExtension: CGFloat?
    }

    enum Position: Equatable {
        case top
        case bottom
    }

    // MARK: - 属性

    private let backdropLayer: CALayer
    private let isTransparent: Bool
    private let useNewPath: Bool
    private let maskSublayerHost: CALayer?
    private let nullActionDelegate = NullActionLayerDelegate()

    private var maxBlurRadius: CGFloat
    private var params: Params?
    private var gradientImage: UIImage?

    /// Legacy 路径下当前已合成的完整尺寸蒙版（含实心段+渐变段）；radius 变化时需要
    /// 把它重新塞进新 filter 的 inputMaskImage。新路径下此字段为空。
    private var legacyCompositedMaskCGImage: CGImage?

    // MARK: - 初始化

    init(backdropLayer: CALayer, maxBlurRadius: CGFloat, isTransparent: Bool = false) {
        self.backdropLayer = backdropLayer
        self.maxBlurRadius = maxBlurRadius
        self.isTransparent = isTransparent

        // 关键：backdropLayer 挂 null-action delegate，屏蔽对 filters/scale 等属性的
        // implicit 动画。否则每次 installFilter 重装 filters[] 都会被 CA 插值成
        // crossfade/抖动。
        backdropLayer.delegate = nullActionDelegate

        if #available(iOS 26.0, *) {
            useNewPath = true
            let sublayer = CALayer()
            sublayer.name = CAFilterInputKey.maskSourceSublayerName
            sublayer.delegate = nullActionDelegate
            maskSublayerHost = sublayer
            backdropLayer.addSublayer(sublayer)
        } else {
            useNewPath = false
            maskSublayerHost = nil
        }

        // 首次装载 filter：新路径下不需要 maskImage；legacy 路径下先空装，update 调进来时补。
        installFilter(maskImage: nil)
    }

    // MARK: - 对外更新入口

    /// 仅修改模糊半径；需要重装一个带新 radius 的 filter 才能让 CA 重采样。
    func updateMaxBlurRadius(_ radius: CGFloat) {
        guard maxBlurRadius != radius else { return }
        maxBlurRadius = radius
        installFilter(maskImage: legacyCompositedMaskCGImage)
    }

    /// 强制重装一次 filter，用于 backdrop 自身参数（如 scale）变化后重新采样。
    func refreshFilter() {
        installFilter(maskImage: legacyCompositedMaskCGImage)
    }

    func update(
        size: CGSize,
        constantHeight: CGFloat,
        position: Position,
        inwardsExtension: CGFloat?,
        transition: BlurTransition
    ) {
        let next = Params(
            size: size,
            constantHeight: constantHeight,
            position: position,
            inwardsExtension: inwardsExtension
        )
        let previous = params
        params = next

        let isGradientShapeChanged = previous?.constantHeight != next.constantHeight
            || previous?.inwardsExtension != next.inwardsExtension
            || previous?.position != next.position
        let isOverallHeightChanged = previous?.size.height != next.size.height

        if isGradientShapeChanged {
            gradientImage = renderGradientImage(for: next)
        }

        if useNewPath {
            // 新路径：mask 图放到命名子 layer 的 contents 上即可，filter 保持不动。
            if isGradientShapeChanged {
                maskSublayerHost?.contents = gradientImage?.cgImage
            }
            transition.updateFrame(layer: backdropLayer, frame: CGRect(origin: .zero, size: next.size))
            if let maskSublayerHost {
                transition.updateFrame(layer: maskSublayerHost, frame: CGRect(origin: .zero, size: next.size))
            }
        } else {
            // Legacy 路径：shape 或整体高度变了才重合成 mask 图，并走 installFilter 重装。
            if isGradientShapeChanged || isOverallHeightChanged {
                legacyCompositedMaskCGImage = renderLegacyCompositedMask(for: next)?.cgImage
                installFilter(maskImage: legacyCompositedMaskCGImage)
            }
            transition.updateFrame(layer: backdropLayer, frame: CGRect(origin: .zero, size: next.size))
        }
    }

    // MARK: - Filter 装载（唯一入口）

    /// 创建并装载一个新的 variableBlur filter；所有会影响 filter 的参数变更都走这里。
    private func installFilter(maskImage: CGImage?) {
        guard let filter = CAFilterBridge.makeVariableBlur() else { return }
        filter.setValue(maxBlurRadius, forKey: CAFilterInputKey.radius)
        if isTransparent {
            filter.setValue(true, forKey: CAFilterInputKey.normalizeEdgesTransparent)
        } else {
            filter.setValue(true, forKey: CAFilterInputKey.normalizeEdges)
        }
        if useNewPath {
            filter.setValue(CAFilterInputKey.maskSourceSublayerName, forKey: CAFilterInputKey.sourceSublayerName)
        } else if let maskImage {
            filter.setValue(maskImage, forKey: CAFilterInputKey.maskImage)
        }
        // 即使 layer delegate 屏蔽了 implicit 动画，某些 Core Animation 路径仍会从
        // 当前 CATransaction 获取 action；再加一层显式 disableActions 更稳。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer.filters = [filter]
        CATransaction.commit()
    }

    // MARK: - 蒙版图渲染

    private func renderGradientImage(for params: Params) -> UIImage? {
        GradientMaskImage.generate(
            baseHeight: max(1.0, params.constantHeight),
            isInverted: params.position == .bottom,
            extensionHeight: params.inwardsExtension ?? 0.0
        )
    }

    /// Legacy 路径专用：合成一张"实心 + 渐变 + 透明"整张 1×N mask。
    private func renderLegacyCompositedMask(for params: Params) -> UIImage? {
        guard let gradientImage else { return nil }
        let compositedHeight = min(800.0, params.size.height)
        return makeImage(
            size: CGSize(width: 1.0, height: compositedHeight),
            opaque: false
        ) { [params] size, context in
            UIGraphicsPushContext(context)
            defer { UIGraphicsPopContext() }

            context.clear(CGRect(origin: .zero, size: size))

            let mainFrame: CGRect
            let solidFrame: CGRect

            if params.inwardsExtension != nil {
                // 带实心延伸段：整张图都交由渐变图本体负责（渐变图自身已经带实心段）
                mainFrame = CGRect(origin: .zero, size: size)
                solidFrame = .zero
            } else if params.position == .bottom {
                mainFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: size.height - params.constantHeight),
                    size: CGSize(width: size.width, height: params.constantHeight)
                )
                solidFrame = CGRect(
                    origin: .zero,
                    size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight))
                )
            } else {
                mainFrame = CGRect(
                    origin: .zero,
                    size: CGSize(width: size.width, height: params.constantHeight)
                )
                solidFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: params.constantHeight),
                    size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight))
                )
            }

            context.setFillColor(UIColor(white: 0.0, alpha: 1.0).cgColor)
            context.fill(solidFrame)
            gradientImage.draw(in: mainFrame, blendMode: .normal, alpha: 1.0)
        }
    }
}

// MARK: - CALayerDelegate：对任何 key 返回 NSNull，禁用所有 implicit 动画

private final class NullActionLayerDelegate: NSObject, CALayerDelegate {
    func action(for _: CALayer, forKey _: String) -> CAAction? {
        NSNull()
    }
}

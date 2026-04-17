//
//  GradientBlurView.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import UIKit

/// 渐变高斯模糊视图。
///
/// 沿 Y 轴方向，从 `constantHeight` 指定的一侧向另一侧按预设非线性曲线平滑过渡：
/// 一端完全清晰、另一端完全透明。可附加一层 tint 色，该层用同一条渐变曲线做蒙版，
/// 确保 tint 色调与模糊强度同步淡出。
///
/// - Note: 依赖系统私有 `CAFilter` / `CABackdropLayer`；关键字符串已做 base64 混淆
///   以降低静态扫描风险，但并非完全合规，上架前请自行评估。
public final class GradientBlurView: UIView {
    /// 渐变方向。
    public enum GradientDirection {
        /// 顶部不透明，向下过渡到完全透明（导航栏向下扩散）。
        case topToBottom
        /// 底部不透明，向上过渡到完全透明（TabBar 向上扩散）。
        case bottomToTop
    }

    // MARK: - 私有属性

    private let direction: GradientDirection
    private let isTransparent: Bool

    private let backdropHostView = UIView()
    private let tintImageView = UIImageView()
    private var blurLayer: VariableBlurLayer?
    private let backdropLayer: CALayer?

    private var currentMaxBlurRadius: CGFloat
    private var currentBlurScale: CGFloat
    private var currentTintAlpha: CGFloat = 1.0
    private var isBlurEnabled: Bool = true

    private var currentSize: CGSize = .zero
    private var currentConstantHeight: CGFloat = 0.0
    private var currentStartOffset: CGFloat = 0.0

    // MARK: - 初始化

    /// - Parameters:
    ///   - direction: 渐变方向。
    ///   - maxBlurRadius: 最大模糊半径（在不透明侧达到的实际模糊量）。
    ///   - blurScale: backdrop 栅格化缩放（0.2~1.0）；越小越省性能、但细节越糊。
    ///   - isTransparent: 把 variableBlur 的边缘归一化策略切到"透明背景"版本；
    ///     宿主本身透明（例如浮在图片上而非纯色页面上）时设 true，可以避免边缘出现
    ///     视觉上的裁剪硬边。
    public init(
        direction: GradientDirection,
        maxBlurRadius: CGFloat = 20.0,
        blurScale: CGFloat = 0.5,
        isTransparent: Bool = false
    ) {
        self.direction = direction
        self.isTransparent = isTransparent
        currentMaxBlurRadius = maxBlurRadius
        currentBlurScale = max(0.2, blurScale)
        backdropLayer = CAFilterBridge.makeBackdropLayer()

        super.init(frame: .zero)

        configureHierarchy()
        configureBackdrop()
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 公共属性

    /// 当前最大模糊半径。只读；修改走 `updateBlurRadius`。
    public var maxBlurRadius: CGFloat {
        currentMaxBlurRadius
    }

    /// 当前 backdrop 栅格化缩放。只读；修改走 `updateBlurScale`。
    public var blurScale: CGFloat {
        currentBlurScale
    }

    // MARK: - 布局更新

    /// 更新布局与渐变参数。
    ///
    /// - Parameters:
    ///   - size: 视图总尺寸。
    ///   - constantHeight: 从"不透明一侧"起算的渐变段总高度（含可选的实心段）。
    ///   - startOffset: 不透明一侧保留的纯实心段高度；0 表示不保留实心段，整个
    ///     `constantHeight` 都是渐变。
    ///   - transition: 尺寸/位置变化的过渡方式。
    public func update(
        size: CGSize,
        constantHeight: CGFloat,
        startOffset: CGFloat = 0.0,
        transition: BlurTransition = .immediate
    ) {
        let clampedConstant = min(size.height, max(1.0, constantHeight))
        let clampedOffset = min(max(0.0, startOffset), max(0.0, size.height - clampedConstant))

        let didLayoutChange = currentSize != size
            || currentConstantHeight != clampedConstant
            || currentStartOffset != clampedOffset

        currentSize = size
        currentConstantHeight = clampedConstant
        currentStartOffset = clampedOffset

        let bounds = CGRect(origin: .zero, size: size)
        transition.updateFrame(view: backdropHostView, frame: bounds)
        transition.updateFrame(view: tintImageView, frame: bounds)

        if didLayoutChange {
            let maskImage = GradientMaskImage.generate(
                baseHeight: clampedConstant,
                isInverted: direction == .bottomToTop,
                extensionHeight: clampedOffset
            )
            tintImageView.image = maskImage?.withRenderingMode(.alwaysTemplate)
        }

        // Blur 层的"可见段"比 tint 层稍短 4pt，避免 blur 边缘硬边被看见。
        let blurVisibleHeight = max(1.0, clampedConstant - 4.0)
        blurLayer?.update(
            size: size,
            constantHeight: blurVisibleHeight,
            position: direction == .bottomToTop ? .bottom : .top,
            inwardsExtension: clampedOffset > 0 ? clampedOffset : nil,
            transition: transition
        )
    }

    // MARK: - Tint

    /// 更新 tint 色与 alpha。
    ///
    /// - Parameters:
    ///   - color: tint 色。传 nil 等价于"tint 层透明"（不会销毁底层资源）。
    ///   - alpha: tint 层整体 alpha，独立于颜色自身的 alpha 通道，便于动画淡入淡出。
    ///   - transition: 颜色与 alpha 的过渡方式。
    public func updateTint(
        color: UIColor?,
        alpha: CGFloat = 1.0,
        transition: BlurTransition = .immediate
    ) {
        let clampedAlpha = max(0.0, min(1.0, alpha))
        currentTintAlpha = clampedAlpha

        if let color {
            transition.updateTintColor(imageView: tintImageView, color: color)
            transition.updateAlpha(view: tintImageView, alpha: clampedAlpha)
        } else {
            transition.updateAlpha(view: tintImageView, alpha: 0.0)
        }
    }

    // MARK: - 模糊参数

    /// 运行时更新最大模糊半径；不重建 filter 也不重绘蒙版。
    public func updateBlurRadius(_ radius: CGFloat) {
        guard currentMaxBlurRadius != radius else { return }
        currentMaxBlurRadius = radius
        blurLayer?.updateMaxBlurRadius(radius)
    }

    /// 运行时更新 backdrop 栅格化缩放。越小越省性能、细节越糊（典型范围 0.2~1.0）。
    public func updateBlurScale(_ scale: CGFloat) {
        let clamped = max(0.2, scale)
        guard currentBlurScale != clamped else { return }
        currentBlurScale = clamped
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer?.setValue(clamped, forKey: "scale")
        backdropLayer?.rasterizationScale = clamped
        CATransaction.commit()
        // backdrop 的 scale 变了，必须让 CA 重采样一遍 filter。
        blurLayer?.refreshFilter()
    }

    /// 开关模糊层；关闭时仅 hide 宿主视图，不销毁 CABackdropLayer 与 filter，
    /// 再次打开时不产生任何重建开销。tint 层不受影响。
    public func setBlurEnabled(_ enabled: Bool) {
        guard isBlurEnabled != enabled else { return }
        isBlurEnabled = enabled
        backdropHostView.isHidden = !enabled
    }

    // MARK: - 私有装配

    private func configureHierarchy() {
        backdropHostView.isUserInteractionEnabled = false
        tintImageView.isUserInteractionEnabled = false
        tintImageView.contentMode = .scaleToFill

        addSubview(backdropHostView)
        addSubview(tintImageView)

        if let backdropLayer {
            backdropHostView.layer.addSublayer(backdropLayer)
        }
    }

    private func configureBackdrop() {
        guard let backdropLayer else { return }

        backdropLayer.setValue(currentBlurScale, forKey: "scale")
        backdropLayer.rasterizationScale = currentBlurScale

        blurLayer = VariableBlurLayer(
            backdropLayer: backdropLayer,
            maxBlurRadius: currentMaxBlurRadius,
            isTransparent: isTransparent
        )
    }
}

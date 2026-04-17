//
//  BlurTransition.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import QuartzCore
import UIKit

/// 轻量过渡描述：只区分立即生效与带曲线的时长动画两种场景，足以覆盖本组件全部动画需求。
public enum BlurTransition: Sendable {
    case immediate
    case animated(duration: TimeInterval, curve: UIView.AnimationCurve)

    public static let defaultAnimated: BlurTransition = .animated(duration: 0.25, curve: .easeInOut)

    // MARK: - UIView

    @MainActor
    func updateFrame(view: UIView, frame: CGRect) {
        guard view.frame != frame else { return }
        switch self {
        case .immediate:
            view.layer.removeAnimation(forKey: "bounds")
            view.layer.removeAnimation(forKey: "position")
            view.frame = frame
        case let .animated(duration, curve):
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: curve.asAnimationOptions,
                animations: { view.frame = frame }
            )
        }
    }

    @MainActor
    func updateAlpha(view: UIView, alpha: CGFloat) {
        guard view.alpha != alpha else { return }
        switch self {
        case .immediate:
            view.layer.removeAnimation(forKey: "opacity")
            view.alpha = alpha
        case let .animated(duration, curve):
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: curve.asAnimationOptions,
                animations: { view.alpha = alpha }
            )
        }
    }

    @MainActor
    func updateTintColor(imageView: UIImageView, color: UIColor) {
        guard imageView.tintColor != color else { return }
        switch self {
        case .immediate:
            imageView.tintColor = color
        case let .animated(duration, curve):
            UIView.transition(
                with: imageView,
                duration: duration,
                options: [curve.asAnimationOptions, .transitionCrossDissolve, .allowUserInteraction],
                animations: { imageView.tintColor = color }
            )
        }
    }

    // MARK: - CALayer

    @MainActor
    func updateFrame(layer: CALayer, frame: CGRect) {
        guard layer.frame != frame else { return }
        switch self {
        case .immediate:
            layer.removeAnimation(forKey: "bounds")
            layer.removeAnimation(forKey: "position")
            layer.frame = frame
        case let .animated(duration, curve):
            let previousFrame = layer.frame
            layer.frame = frame
            let from = CGPoint(
                x: previousFrame.midX - layer.position.x,
                y: previousFrame.midY - layer.position.y
            )
            let positionAnim = CABasicAnimation(keyPath: "position")
            positionAnim.fromValue = NSValue(cgPoint: CGPoint(
                x: layer.position.x + from.x,
                y: layer.position.y + from.y
            ))
            positionAnim.toValue = NSValue(cgPoint: layer.position)
            positionAnim.duration = duration
            positionAnim.timingFunction = curve.asCAMediaTimingFunction

            let boundsAnim = CABasicAnimation(keyPath: "bounds")
            boundsAnim.fromValue = NSValue(cgRect: CGRect(origin: .zero, size: previousFrame.size))
            boundsAnim.toValue = NSValue(cgRect: layer.bounds)
            boundsAnim.duration = duration
            boundsAnim.timingFunction = curve.asCAMediaTimingFunction

            layer.add(positionAnim, forKey: "position")
            layer.add(boundsAnim, forKey: "bounds")
        }
    }
}

// MARK: - UIView.AnimationCurve Bridge

private extension UIView.AnimationCurve {
    var asAnimationOptions: UIView.AnimationOptions {
        switch self {
        case .easeInOut: .curveEaseInOut
        case .easeIn: .curveEaseIn
        case .easeOut: .curveEaseOut
        case .linear: .curveLinear
        @unknown default: .curveEaseInOut
        }
    }

    var asCAMediaTimingFunction: CAMediaTimingFunction {
        switch self {
        case .easeInOut: CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeIn: CAMediaTimingFunction(name: .easeIn)
        case .easeOut: CAMediaTimingFunction(name: .easeOut)
        case .linear: CAMediaTimingFunction(name: .linear)
        @unknown default: CAMediaTimingFunction(name: .easeInEaseOut)
        }
    }
}

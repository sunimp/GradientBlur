//
//  ImageGeneration.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import CoreGraphics
import UIKit

/// 在 UIKit 坐标系（原点左上）下构造指定尺寸的 UIImage。
///
/// 基于 `UIGraphicsImageRenderer`，自带坐标系 flip，`drawLinearGradient`
/// 从 y=0 到 y=size.height 时表示从上到下。
func makeImage(
    size: CGSize,
    opaque: Bool = false,
    scale: CGFloat? = nil,
    draw: (CGSize, CGContext) -> Void
) -> UIImage? {
    guard size.width > 0, size.height > 0 else {
        return nil
    }
    let format = UIGraphicsImageRendererFormat.preferred()
    format.opaque = opaque
    if let scale {
        format.scale = scale
    }
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
        draw(size, context.cgContext)
    }
}

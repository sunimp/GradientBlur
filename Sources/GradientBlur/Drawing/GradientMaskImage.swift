//
//  GradientMaskImage.swift
//  GradientBlur
//
//  Created by Sun on 2026/4/17.
//

import CoreGraphics
import UIKit

/// 渐变蒙版工厂。
///
/// 提供一组精心调校的 256 点 alpha 曲线（非线性，偏 ease-out）作为主渐变段，
/// 外部可附加额外的"纯不透明延伸区"以形成"实心 + 渐变 + 透明"三段式蒙版。
enum GradientMaskImage {
    /// 渐变曲线数据。数值越大代表该处被模糊得越强。
    struct Curve: Equatable {
        let height: CGFloat
        let alpha: [CGFloat]
        let positions: [CGFloat]
    }

    // MARK: - 主曲线

    /// 预调校的 256 点非线性 alpha 曲线；越靠近内侧 alpha 越大（=清晰保留），越靠外侧越接近 0（=全透明）。
    static func defaultCurve(baseHeight: CGFloat) -> Curve {
        let normalized = rawAlpha.map { $0 / rawAlphaMax }
        return Curve(height: baseHeight, alpha: normalized, positions: rawPositions)
    }

    // MARK: - 蒙版图像

    /// 生成 CAFilter variableBlur 所需的灰度蒙版图。
    ///
    /// - Parameters:
    ///   - baseHeight: 渐变段主高度（从不透明过渡到透明的像素数）。
    ///   - isInverted: true 表示底部不透明顶部透明（TabBar 方向），false 表示顶部不透明（导航栏方向）。
    ///   - extensionHeight: 附加在不透明一侧的纯实心延伸段高度；用于"实心区 + 渐变区"两段式。
    static func generate(baseHeight: CGFloat, isInverted: Bool, extensionHeight: CGFloat = 0.0) -> UIImage? {
        if extensionHeight > 0.0 {
            return generateWithExtension(
                baseHeight: baseHeight,
                isInverted: isInverted,
                extensionHeight: extensionHeight
            )
        }
        return generateMainGradient(baseHeight: baseHeight, isInverted: isInverted)
    }

    // MARK: - 内部实现

    /// 简单两段：白色 -> 透明的线性渐变，配可选实心尾段。
    private static func generateWithExtension(baseHeight: CGFloat, isInverted: Bool, extensionHeight: CGFloat) -> UIImage? {
        let totalHeight = max(1.0, baseHeight + extensionHeight)

        return makeImage(size: CGSize(width: 1.0, height: totalHeight), opaque: false) { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)

            let colors = [
                UIColor.white.withAlphaComponent(1.0).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
            ] as CFArray
            var locations: [CGFloat] = [0.0, 1.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations) else {
                return
            }

            if isInverted {
                // 渐变方向：从 bottom 向上；底部 extensionHeight 段填纯白
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0.0, y: max(0.0, size.height - extensionHeight)),
                    end: CGPoint(x: 0.0, y: 0.0),
                    options: []
                )
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(
                    origin: CGPoint(x: 0.0, y: size.height - extensionHeight),
                    size: CGSize(width: size.width, height: extensionHeight)
                ))
            } else {
                // 渐变方向：从 top 向下；顶部 extensionHeight 段填纯白
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(
                    origin: .zero,
                    size: CGSize(width: size.width, height: extensionHeight)
                ))
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0.0, y: extensionHeight),
                    end: CGPoint(x: 0.0, y: size.height),
                    options: []
                )
            }
        }?.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: isInverted ? 0.0 : totalHeight,
                left: 0.0,
                bottom: isInverted ? totalHeight : 0.0,
                right: 0.0
            ),
            resizingMode: .stretch
        )
    }

    /// 非线性主曲线单段。
    private static func generateMainGradient(baseHeight: CGFloat, isInverted: Bool) -> UIImage? {
        let curve = defaultCurve(baseHeight: baseHeight)
        let colors = (isInverted ? curve.alpha.reversed() : Array(curve.alpha))
            .map { UIColor(white: 0.0, alpha: $0).cgColor } as CFArray
        var locations = isInverted
            ? curve.positions.reversed().map { 1.0 - $0 }
            : Array(curve.positions)

        return makeImage(size: CGSize(width: 1.0, height: baseHeight), opaque: false) { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations) else {
                return
            }
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0.0, y: 0.0),
                end: CGPoint(x: 0.0, y: size.height),
                options: []
            )
        }?.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: isInverted ? baseHeight : 0.0,
                left: 0.0,
                bottom: isInverted ? 0.0 : baseHeight,
                right: 0.0
            ),
            resizingMode: .stretch
        )
    }

    // MARK: - 原始曲线数据

    private static let rawAlphaMax: CGFloat = rawAlpha.max() ?? 1.0

    private static let rawAlpha: [CGFloat] = [
        0.8470588235294118, 0.8431372549019608, 0.8392156862745098, 0.8352941176470589,
        0.8313725490196078, 0.8274509803921568, 0.8235294117647058, 0.8196078431372549,
        0.8156862745098039, 0.8117647058823529, 0.807843137254902, 0.803921568627451,
        0.8, 0.7960784313725491, 0.792156862745098, 0.788235294117647,
        0.7843137254901961, 0.7803921568627451, 0.7764705882352941, 0.7725490196078432,
        0.7686274509803921, 0.7647058823529411, 0.7607843137254902, 0.7568627450980392,
        0.7529411764705882, 0.7490196078431373, 0.7450980392156863, 0.7411764705882353,
        0.7372549019607844, 0.7333333333333334, 0.7294117647058824, 0.7254901960784313,
        0.7215686274509804, 0.7176470588235294, 0.7137254901960784, 0.7098039215686274,
        0.7019607843137254, 0.6941176470588235, 0.6862745098039216, 0.6784313725490196,
        0.6705882352941177, 0.6588235294117647, 0.6509803921568628, 0.6431372549019607,
        0.6313725490196078, 0.6235294117647059, 0.615686274509804, 0.603921568627451,
        0.596078431372549, 0.5882352941176471, 0.5764705882352941, 0.5647058823529412,
        0.5529411764705883, 0.5411764705882354, 0.5294117647058824, 0.5176470588235293,
        0.5058823529411764, 0.49411764705882355, 0.4862745098039216, 0.4745098039215686,
        0.4627450980392157, 0.4549019607843138, 0.44313725490196076, 0.43137254901960786,
        0.41960784313725485, 0.4117647058823529, 0.4, 0.388235294117647,
        0.3764705882352941, 0.3647058823529412, 0.3529411764705882, 0.3411764705882353,
        0.3294117647058824, 0.3176470588235294, 0.3058823529411765, 0.2941176470588235,
        0.2823529411764706, 0.2705882352941177, 0.2588235294117647, 0.2431372549019608,
        0.2313725490196078, 0.21568627450980393, 0.19999999999999996, 0.18039215686274512,
        0.16078431372549018, 0.14117647058823535, 0.11764705882352944, 0.09019607843137256,
        0.04705882352941182, 0.0,
    ]

    private static let rawPositions: [CGFloat] = [
        0.0, 0.020905923344947737, 0.059233449477351915, 0.08710801393728224,
        0.10801393728222997, 0.12195121951219512, 0.13240418118466898, 0.14285714285714285,
        0.15331010452961671, 0.1602787456445993, 0.17073170731707318, 0.18118466898954705,
        0.1916376306620209, 0.20209059233449478, 0.20905923344947736, 0.21254355400696864,
        0.21951219512195122, 0.2264808362369338, 0.23344947735191637, 0.23693379790940766,
        0.24390243902439024, 0.24738675958188153, 0.25435540069686413, 0.2578397212543554,
        0.2613240418118467, 0.2682926829268293, 0.27177700348432055, 0.27526132404181186,
        0.28222996515679444, 0.2857142857142857, 0.289198606271777, 0.2926829268292683,
        0.2961672473867596, 0.29965156794425085, 0.30313588850174217, 0.30662020905923343,
        0.313588850174216, 0.3205574912891986, 0.32752613240418116, 0.3344947735191638,
        0.34146341463414637, 0.34843205574912894, 0.3554006968641115, 0.3623693379790941,
        0.3693379790940767, 0.37630662020905925, 0.3797909407665505, 0.3867595818815331,
        0.39372822299651566, 0.397212543554007, 0.40418118466898956, 0.41114982578397213,
        0.4181184668989547, 0.4250871080139373, 0.43205574912891986, 0.43902439024390244,
        0.445993031358885, 0.4529616724738676, 0.4564459930313589, 0.4634146341463415,
        0.47038327526132406, 0.4738675958188153, 0.4808362369337979, 0.4878048780487805,
        0.49477351916376305, 0.49825783972125437, 0.5052264808362369, 0.5121951219512195,
        0.519163763066202, 0.5261324041811847, 0.5331010452961672, 0.5400696864111498,
        0.5470383275261324, 0.554006968641115, 0.5609756097560976, 0.5679442508710801,
        0.5749128919860628, 0.5818815331010453, 0.5888501742160279, 0.5993031358885017,
        0.6062717770034843, 0.6167247386759582, 0.627177700348432, 0.6411149825783972,
        0.6585365853658537, 0.6759581881533101, 0.6968641114982579, 0.7282229965156795,
        0.7909407665505227, 1.0,
    ]
}

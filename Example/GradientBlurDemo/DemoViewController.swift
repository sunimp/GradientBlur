//
//  DemoViewController.swift
//  GradientBlurDemo
//
//  Created by Sun on 2026/4/17.
//

import GradientBlur
import UIKit

private typealias BlurTransition = GradientBlur.BlurTransition

/// 演示渐变模糊：滚动一张五彩背景，上下分别贴一条 GradientBlurView。
/// 滑条用于实时调参，便于视觉验证。
final class DemoViewController: UIViewController {
    // MARK: - 视图

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let topBlurView = GradientBlurView(direction: .topToBottom)
    private let bottomBlurView = GradientBlurView(direction: .bottomToTop)

    private let titleLabel = UILabel()
    private let tabLabelsContainer = UIStackView()

    // MARK: - 参数（随滑块调整）

    private var navGradientHeight: CGFloat = 88 // 默认包含 statusBar
    private var navSolidHeight: CGFloat = 44 // 其中纯不透明段
    private var tabGradientHeight: CGFloat = 83
    private var tabSolidHeight: CGFloat = 49
    private var blurRadius: CGFloat = 20
    private var blurScale: CGFloat = 0.5
    private var tintWhite: CGFloat = 1.0
    private var tintAlpha: CGFloat = 0.6

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupBackground()
        setupBlurs()
        setupOverlayText()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutBlurs()
    }

    // MARK: - 背景 & 滚动内容

    private func setupBackground() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // 五彩背景条带，让模糊效果一目了然；开头几条直接贴顶，便于初始视觉确认
        let stripes: [UIColor] = [
            UIColor(red: 0.98, green: 0.22, blue: 0.30, alpha: 1), // 红
            UIColor(red: 0.98, green: 0.58, blue: 0.14, alpha: 1), // 橙
            UIColor(red: 0.99, green: 0.82, blue: 0.16, alpha: 1), // 黄
            UIColor(red: 0.26, green: 0.72, blue: 0.32, alpha: 1), // 绿
        ]
        for (index, color) in stripes.enumerated() {
            contentStack.addArrangedSubview(makeStripe(color: color, index: index))
        }

        // 参数控制区夹在中间
        contentStack.addArrangedSubview(makeControlPanel())

        // 末尾再来几条彩色，让底部 blur 也有东西可模糊
        let tailStripes: [UIColor] = [
            UIColor(red: 0.13, green: 0.54, blue: 0.95, alpha: 1), // 蓝
            UIColor(red: 0.48, green: 0.29, blue: 0.83, alpha: 1), // 紫
            UIColor(red: 0.95, green: 0.42, blue: 0.64, alpha: 1), // 粉
            UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1), // 黑
        ]
        for (index, color) in tailStripes.enumerated() {
            contentStack.addArrangedSubview(makeStripe(color: color, index: index + stripes.count))
        }
    }

    private func makeStripe(color: UIColor, index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = color
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let label = UILabel()
        label.text = "BLOCK \(index + 1)  — scroll me under the blurred bars"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    // MARK: - 控制面板

    private func makeControlPanel() -> UIView {
        let panel = UIStackView()
        panel.axis = .vertical
        panel.spacing = 8
        panel.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.backgroundColor = UIColor(white: 0.96, alpha: 1)

        panel.addArrangedSubview(makeSlider(title: "Max Blur Radius", min: 0, max: 40, value: blurRadius) { [weak self] v in
            self?.blurRadius = CGFloat(v)
            self?.applyParams()
        })
        panel.addArrangedSubview(makeSlider(title: "Blur Scale", min: 0.2, max: 1.0, value: blurScale) { [weak self] v in
            self?.blurScale = CGFloat(v)
            self?.applyParams()
        })
        panel.addArrangedSubview(makeSlider(title: "Nav Gradient Height", min: 44, max: 160, value: navGradientHeight) { [weak self] v in
            self?.navGradientHeight = CGFloat(v)
            self?.layoutBlurs()
        })
        panel.addArrangedSubview(makeSlider(title: "Nav Solid Height", min: 0, max: 88, value: navSolidHeight) { [weak self] v in
            self?.navSolidHeight = CGFloat(v)
            self?.layoutBlurs()
        })
        panel.addArrangedSubview(makeSlider(title: "Tab Gradient Height", min: 49, max: 160, value: tabGradientHeight) { [weak self] v in
            self?.tabGradientHeight = CGFloat(v)
            self?.layoutBlurs()
        })
        panel.addArrangedSubview(makeSlider(title: "Tab Solid Height", min: 0, max: 88, value: tabSolidHeight) { [weak self] v in
            self?.tabSolidHeight = CGFloat(v)
            self?.layoutBlurs()
        })
        panel.addArrangedSubview(makeSlider(title: "Tint Alpha", min: 0, max: 1, value: tintAlpha) { [weak self] v in
            self?.tintAlpha = CGFloat(v)
            self?.applyParams()
        })

        let tintSegment = UISegmentedControl(items: ["Light Tint", "Dark Tint", "No Tint"])
        tintSegment.selectedSegmentIndex = 0
        tintSegment.addAction(UIAction { [weak self, weak tintSegment] _ in
            guard let self, let seg = tintSegment else { return }
            switch seg.selectedSegmentIndex {
            case 0: self.tintWhite = 1.0; self.tintAlpha = 0.6
            case 1: self.tintWhite = 0.0; self.tintAlpha = 0.4
            default: self.tintAlpha = 0
            }
            self.applyParams(transition: .defaultAnimated)
        }, for: .valueChanged)
        panel.addArrangedSubview(tintSegment)

        let toggleRow = UIStackView()
        toggleRow.axis = .horizontal
        toggleRow.spacing = 12
        let enableLabel = UILabel()
        enableLabel.text = "Blur Enabled"
        enableLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let enableSwitch = UISwitch()
        enableSwitch.isOn = true
        enableSwitch.addAction(UIAction { [weak self, weak enableSwitch] _ in
            guard let self, let sw = enableSwitch else { return }
            self.topBlurView.setBlurEnabled(sw.isOn)
            self.bottomBlurView.setBlurEnabled(sw.isOn)
        }, for: .valueChanged)
        toggleRow.addArrangedSubview(enableLabel)
        toggleRow.addArrangedSubview(enableSwitch)
        panel.addArrangedSubview(toggleRow)

        return panel
    }

    private func makeSlider(
        title: String,
        min minValue: Float,
        max maxValue: Float,
        value: CGFloat,
        onChange: @escaping (Float) -> Void
    ) -> UIView {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)

        let slider = UISlider()
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = Float(value)

        func updateLabel() {
            label.text = "\(title): \(String(format: "%.2f", slider.value))"
        }
        updateLabel()

        slider.addAction(UIAction { [weak slider] _ in
            guard let slider else { return }
            updateLabel()
            onChange(slider.value)
        }, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, slider])
        row.axis = .vertical
        row.spacing = 2
        return row
    }

    // MARK: - Blur 层与布局

    private func setupBlurs() {
        view.addSubview(topBlurView)
        view.addSubview(bottomBlurView)
        applyParams()
    }

    private func layoutBlurs() {
        let bounds = view.bounds
        let gradientExtra: CGFloat = 25 // 延伸段做软过渡

        let navFrameHeight = navGradientHeight + gradientExtra
        let tabFrameHeight = tabGradientHeight + gradientExtra

        topBlurView.frame = CGRect(
            x: 0, y: 0,
            width: bounds.width,
            height: navFrameHeight
        )
        bottomBlurView.frame = CGRect(
            x: 0, y: bounds.height - tabFrameHeight,
            width: bounds.width,
            height: tabFrameHeight
        )

        topBlurView.update(
            size: topBlurView.bounds.size,
            constantHeight: navGradientHeight,
            startOffset: navSolidHeight,
            transition: .immediate
        )
        bottomBlurView.update(
            size: bottomBlurView.bounds.size,
            constantHeight: tabGradientHeight,
            startOffset: tabSolidHeight,
            transition: .immediate
        )

        // 顶部标题从 safeArea.top 下沿开始；
        // 底部 tab 文字紧贴 safeArea.bottom 上沿（即避开 home indicator / 刘海安全区）。
        let insets = view.safeAreaInsets
        let titleHeight: CGFloat = 30
        titleLabel.frame = CGRect(
            x: 0,
            y: insets.top,
            width: bounds.width,
            height: titleHeight
        )
        let tabLabelHeight: CGFloat = 49
        tabLabelsContainer.frame = CGRect(
            x: 0,
            y: bounds.height - insets.bottom - tabLabelHeight,
            width: bounds.width,
            height: tabLabelHeight
        )
    }

    private func applyParams(transition: BlurTransition = .immediate) {
        topBlurView.updateBlurRadius(blurRadius)
        topBlurView.updateBlurScale(blurScale)
        topBlurView.updateTint(color: resolvedTintColor(), alpha: tintAlpha, transition: transition)

        bottomBlurView.updateBlurRadius(blurRadius)
        bottomBlurView.updateBlurScale(blurScale)
        bottomBlurView.updateTint(color: resolvedTintColor(), alpha: tintAlpha, transition: transition)
    }

    private func resolvedTintColor() -> UIColor? {
        UIColor(white: tintWhite, alpha: 1.0)
    }

    // MARK: - 顶部标题 & 底部 tab 文字（便于对照视觉）

    private func setupOverlayText() {
        titleLabel.text = "GradientBlur Demo"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        tabLabelsContainer.axis = .horizontal
        tabLabelsContainer.distribution = .fillEqually
        for emoji in ["💬", "👥", "⚙️"] {
            let label = UILabel()
            label.text = emoji
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            tabLabelsContainer.addArrangedSubview(label)
        }
        view.addSubview(tabLabelsContainer)
    }
}

//
//  SceneDelegate.swift
//  GradientBlurDemo
//
//  Created by Sun on 2026/4/17.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = DemoViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

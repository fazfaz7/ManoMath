//
//  ManoMathApp.swift
//  ManoMath
//
//  Created by Adrian Emmanuel Faz Mercado on 09/03/26.
//

import SwiftUI
import UIKit

@main
struct ManoMathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameCenterManager = GameCenterManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameCenterManager)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}


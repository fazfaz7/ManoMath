//
//  ManoMathApp.swift
//  ManoMath
//
//  Created by Adrian Emmanuel Faz Mercado on 09/03/26.
//

import SwiftUI
import UIKit

/// The main entry point for the Handy app.
/// This is a mental math training game where users answer
/// math problems using hand gestures captured by the camera.
///  Testing my ci/cd!
@main
struct ManoMathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
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


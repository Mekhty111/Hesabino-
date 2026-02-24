//
//  CompositorApp.swift
//  Compositor
//
//  Created by Mekhty on 24.02.26.
//

import SwiftUI

@main
struct CompositorApp: App {
    @AppStorage("appLanguage") private var appLanguage: String = "ru"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    ContentView()
                } else {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                }
            }
            .environment(\.locale, Locale(identifier: appLanguage))
        }
    }
}

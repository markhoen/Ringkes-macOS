//
//  RingkesApp.swift
//  Ringkes
//
//  Created by mardiansyah on 17/05/26.
//

import SwiftUI

@main
struct RingkesApp: App {

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {

        WindowGroup {

            ContentView()
        }
        .defaultSize(width: 500, height: 400)

        .commands {

            CommandGroup(replacing: .appInfo) {

                Button("About Ringkes") {

                    openWindow(id: "about")
                }
            }
        }

        Window("About Ringkes", id: "about") {

            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

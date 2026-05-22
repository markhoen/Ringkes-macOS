//
//  AboutView.swift
//  Ringkes
//
//  Created by mardiansyah on 17/05/26.
//

import SwiftUI

struct AboutView: View {

    var body: some View {

        VStack(spacing: 18) {

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(radius: 10)

            VStack(spacing: 6) {

                Text("Ringkes")
                    .font(.largeTitle)
                    .bold()

                Text("Cilik Ukurane, Gedhe Manfaate")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Version 1.1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Divider()
                .padding(.horizontal)

            VStack(spacing: 4) {

                Text("PDF Compressor & FPDI Fixer")
                    .font(.body)

                Text("Powered by Ghostscript")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("© 2026 R. Mardiansyah")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Button("Close") {

                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 10)
        }
        .padding(30)
        .frame(width: 420, height: 420)
    }
}

#Preview {
    AboutView()
}

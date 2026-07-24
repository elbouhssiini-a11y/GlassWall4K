//
//  ErrorStateView.swift
//  GlassWall4K
//

import SwiftUI

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = "Try Again"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 88, height: 88)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .glassEffectIfAvailable(in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                }

            VStack(spacing: 8) {
                Text("Something Went Wrong")
                    .font(.title2.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(22)
            .glassChrome(material: .regularMaterial)

            if let onRetry {
                GlassButton(title: retryTitle, systemName: "arrow.clockwise", action: onRetry)
                    .frame(maxWidth: 220)
            }
        }
        .padding(.horizontal, GlassMetrics.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorStateView(message: "Unable to load wallpapers.") {}
        .background(GlassScreenBackground())
}

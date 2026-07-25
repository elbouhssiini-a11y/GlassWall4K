//
//  LockScreenOverlay.swift
//  GlassWall4K
//

import SwiftUI

/// Minimal iPhone Lock Screen chrome for wallpaper preview.
struct LockScreenOverlay: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                Spacer().frame(height: 18)

                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.bottom, 10)

                Text(timeString(for: context.date))
                    .font(.system(size: 92, weight: .thin, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 12)

                Text(dateString(for: context.date))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, -4)

                Spacer(minLength: 0)

                HStack {
                    lockAccessory(systemName: "flashlight.off.fill")
                    Spacer()
                    lockAccessory(systemName: "camera.fill")
                }
                .padding(.horizontal, 46)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func lockAccessory(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            }
    }

    private func timeString(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "en_GB"))
        )
    }

    private func dateString(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .month(.wide)
                .day(.defaultDigits)
                .locale(Locale(identifier: "en_US"))
        )
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        LockScreenOverlay()
    }
}

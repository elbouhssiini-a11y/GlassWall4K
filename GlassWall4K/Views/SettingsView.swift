//
//  SettingsView.swift
//  GlassWall4K
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showsShareSheet = false
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    private let privacyPolicyURL = URL(string: "https://sites.google.com/view/privacy-policy-elbouhssini")!

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GlassMetrics.sectionSpacing) {
                GlassSection(title: "Support") {
                    SettingsActionRow(
                        title: "Rate App",
                        systemName: "star.fill",
                        tint: .orange
                    ) {
                        requestReview()
                    }
                    .settingsRowInsets()

                    GlassSectionDivider()

                    SettingsActionRow(
                        title: "Share App",
                        systemName: "square.and.arrow.up.fill",
                        tint: .blue
                    ) {
                        showsShareSheet = true
                    }
                    .settingsRowInsets()
                }

                GlassSection(title: "Storage") {
                    SettingsActionRow(
                        title: "Clear Cache",
                        systemName: "trash.fill",
                        tint: .orange,
                        role: .destructive
                    ) {
                        viewModel.clearImageCache()
                    }
                    .settingsRowInsets()
                }

                GlassSection(title: "About") {
                    SettingsActionRow(
                        title: "Privacy Policy",
                        systemName: "hand.raised.fill",
                        tint: .gray
                    ) {
                        openURL(privacyPolicyURL)
                    }
                    .settingsRowInsets()

                    GlassSectionDivider()

                    SettingsNavigationRow(
                        title: "Version",
                        systemName: "info.circle.fill",
                        tint: .secondary,
                        value: appVersion
                    )
                    .settingsRowInsets()
                }

                if let notice = viewModel.notice {
                    Text(notice)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, GlassMetrics.horizontalInset)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .animation(.easeOut(duration: 0.2), value: viewModel.notice)
        }
        .background {
            GlassScreenBackground()
        }
        .sheet(isPresented: $showsShareSheet) {
            ActivityShareSheet(items: viewModel.shareItems)
        }
    }
}

private extension View {
    func settingsRowInsets() -> some View {
        padding(.horizontal, GlassMetrics.rowHorizontalPadding)
            .padding(.vertical, GlassMetrics.rowVerticalPadding)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
    }
}

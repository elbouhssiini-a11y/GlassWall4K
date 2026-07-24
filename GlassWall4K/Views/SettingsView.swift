//
//  SettingsView.swift
//  GlassWall4K
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showsShareSheet = false
    @State private var showsPrivacy = false
    @Environment(\.requestReview) private var requestReview

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
                        showsPrivacy = true
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
        .sheet(isPresented: $showsPrivacy) {
            PrivacyPolicySheet()
        }
    }
}

private struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(
                    """
                    Wallora Glass lets you browse and save wallpapers to Photos.

                    The catalog is loaded from the cloud. Images may be cached on your device for faster loading.

                    We do not require an account. If ads are enabled, they are served by Google AdMob.

                    You can free local image cache anytime with Clear Cache in Settings.
                    """
                )
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background {
                GlassScreenBackground()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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

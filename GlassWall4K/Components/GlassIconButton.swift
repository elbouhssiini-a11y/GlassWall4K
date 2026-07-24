//
//  GlassIconButton.swift
//  GlassWall4K
//

import SwiftUI

struct GlassIconButton: View {
    let systemName: String
    var isEmphasized: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(isEmphasized ? Color.pink : Color.primary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(in: .circle)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassIconButton(systemName: "chevron.backward")
        GlassIconButton(systemName: "heart")
        GlassIconButton(systemName: "square.and.arrow.up")
    }
    .padding()
    .background(
        LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
    )
}

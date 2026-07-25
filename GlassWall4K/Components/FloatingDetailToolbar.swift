//
//  FloatingDetailToolbar.swift
//  GlassWall4K
//

import SwiftUI

struct FloatingDetailToolbar: View {
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack {
            GlassIconButton(systemName: "chevron.backward", action: onBack)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}

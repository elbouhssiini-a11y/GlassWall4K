//
//  SectionHeader.swift
//  GlassWall4K
//

import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
    }
}

#Preview {
    SectionHeader(title: "Trending")
        .padding()
}

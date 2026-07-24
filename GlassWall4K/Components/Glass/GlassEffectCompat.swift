//
//  GlassEffectCompat.swift
//  GlassWall4K
//

import SwiftUI

enum GlassEffectShape {
    case capsule
    case circle
    case roundedRect(cornerRadius: CGFloat)
}

enum LiquidGlassStyle {
    /// Clear watery glass — good for floating tab bars.
    case water
    case regular
}

extension View {
    /// Liquid Glass on iOS 26+; no-op on earlier OS (material backgrounds already applied).
    @ViewBuilder
    func glassEffectIfAvailable(
        _ style: LiquidGlassStyle = .regular,
        in shape: GlassEffectShape
    ) -> some View {
        if #available(iOS 26.0, *) {
            let glass = style.resolvedGlass
            switch shape {
            case .capsule:
                self.glassEffect(glass, in: .capsule)
            case .circle:
                self.glassEffect(glass, in: .circle)
            case .roundedRect(let cornerRadius):
                self.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self
        }
    }
}

@available(iOS 26.0, *)
private extension LiquidGlassStyle {
    var resolvedGlass: Glass {
        switch self {
        case .water:
            Glass.clear
                .tint(Color.cyan.opacity(0.14))
                .interactive()
        case .regular:
            Glass.regular.interactive()
        }
    }
}

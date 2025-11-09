//
//  AppColor.swift
//  VaultEye
//
//  Two-color minimal design system
//

import SwiftUI

/// Minimal two-color design system
/// Primary: #4EA8FF (lighter blue)
/// Gray: #94A3B8 (slightly lighter neutral)
struct AppColor {
    // MARK: - Base Colors

    /// Primary blue: #4EA8FF
    static let primaryHex = Color(hex: "4EA8FF")

    /// Neutral gray: #94A3B8
    static let grayHex = Color(hex: "94A3B8")

    /// Dark background for dark mode: #0F172A
    static let darkBg = Color(hex: "0F172A")

    // MARK: - Semantic Tokens (Light Mode)

    /// Primary color for interactive elements
    static let primary = primaryHex

    /// Gray for text and secondary elements
    static let gray = grayHex

    /// Primary background (10% opacity)
    static let primaryBg = primaryHex.opacity(0.10)

    /// Primary foreground (icons/accents)
    static let primaryFg = primaryHex

    /// Primary gradient (lighter to mid-blue)
    static let primaryGrad = LinearGradient(
        colors: [Color(hex: "4EA8FF"), Color(hex: "7BBEFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Gray background (12% opacity)
    static let grayBg = grayHex.opacity(0.12)

    /// Gray text (default body text)
    static let grayText = grayHex

    /// Card fill (18% opacity) - Light gray for light mode
    static let cardFill = Color(hex: "F8FAFC")

    /// Border (35% opacity)
    static let border = grayHex.opacity(0.35)

    // MARK: - Dark Mode Variants

    /// Primary for dark mode (slightly adjusted for contrast)
    static let primaryDark = Color(hex: "5BB2FF")

    /// Gray for dark mode (lighter for better contrast on dark bg)
    static let grayDark = Color(hex: "CBD5E1")

    /// Primary background for dark mode
    static let primaryBgDark = Color(hex: "5BB2FF").opacity(0.15)

    /// Gray background for dark mode
    static let grayBgDark = Color(hex: "CBD5E1").opacity(0.15)

    /// Card fill for dark mode - Darker gray
    static let cardFillDark = Color(hex: "1E293B")

    /// Border for dark mode
    static let borderDark = Color(hex: "CBD5E1").opacity(0.25)

    // MARK: - Adaptive Colors (Automatically switch based on color scheme)

    static func adaptivePrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? primaryDark : primary
    }

    static func adaptiveGray(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? grayDark : gray
    }

    static func adaptivePrimaryBg(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? primaryBgDark : primaryBg
    }

    static func adaptiveGrayBg(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? grayBgDark : grayBg
    }

    static func adaptiveCardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardFillDark : cardFill
    }

    static func adaptiveBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? borderDark : border
    }

    static func adaptiveGrayText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? grayDark : grayText
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

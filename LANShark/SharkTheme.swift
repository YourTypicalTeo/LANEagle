import SwiftUI

/// Central color theme for LANShark, supporting dynamic light/dark adaptation.
struct SharkTheme {
    static func background(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 25/255, green: 35/255, blue: 57/255),
                    Color(red: 40/255, green: 85/255, blue: 144/255),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 33/255, green: 67/255, blue: 107/255),
                    Color(red: 76/255, green: 160/255, blue: 255/255),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color(.secondarySystemBackground).opacity(0.93)
        : Color(.systemBackground).opacity(0.94)
    }

    static func blue(for scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color(red: 88/255, green: 170/255, blue: 255/255)
        : Color(red: 33/255, green: 67/255, blue: 107/255)
    }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color(red: 0.35, green: 0.7, blue: 1)
        : Color(red: 0.15, green: 0.45, blue: 0.85)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color(.tertiarySystemBackground)
        : Color(.secondarySystemBackground)
    }

    static var printer: Color { .purple }
    static var linux: Color { .green }
    static var windows: Color { .indigo }
    static var web: Color { .blue }
    static var unknown: Color { .gray }
    static var alert: Color { .red }
}

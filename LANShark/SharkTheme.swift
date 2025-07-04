import SwiftUI

struct SharkTheme {
    static let blue = Color(red: 33/255, green: 67/255, blue: 107/255)
    static let lightBlue = Color(red: 76/255, green: 160/255, blue: 255/255)
    static let gray = Color(red: 240/255, green: 245/255, blue: 250/255)
    static let background = LinearGradient(
        gradient: Gradient(colors: [SharkTheme.blue, SharkTheme.lightBlue, .white]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

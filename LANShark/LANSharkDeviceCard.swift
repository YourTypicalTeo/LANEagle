import SwiftUI

/// Card view for displaying a single scanned device, themed to adapt to light/dark mode.
/// Now with increased height and visual breathing room, still inset from sides.
struct LANSharkDeviceCard: View {
    let device: ScannedDevice
    @Environment(\.colorScheme) var colorScheme
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 16) { // More spacing for height
            // Device icon with accent color and gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [iconAccent.opacity(0.28), .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48) // Taller icon background
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(iconAccent)
            }
            // Device info
            VStack(alignment: .leading, spacing: 4) { // More vertical spacing
                Text(deviceDisplayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(device.ip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let hostname = device.hostname, !hostname.isEmpty, hostname != device.ip {
                    Text(hostname)
                        .font(.caption2)
                        .foregroundColor(iconAccent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let ssdp = device.ssdpInfo {
                    Text(ssdp.prefix(32) + (ssdp.count > 32 ? "..." : ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(15) // Larger padding restores previous height
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SharkTheme.card(for: colorScheme))
                .shadow(color: colorScheme == .dark ? .black.opacity(0.10) : .gray.opacity(0.08), radius: 6, x: 0, y: 4)
        )
        .padding(.vertical, 6) // Vertical spacing between cards
        .scaleEffect(isPulsing ? 1.07 : 1)
        .opacity(isPulsing ? 1.0 : 0.85)
        .animation(.spring(response: 0.45, dampingFraction: 0.62), value: isPulsing)
        .onAppear {
            isPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isPulsing = false
            }
        }
    }

    var deviceDisplayName: String {
        if let hostname = device.hostname, !hostname.isEmpty, hostname != device.ip {
            return hostname
        }
        if device.openPorts.contains(where: { [9100, 515, 631].contains($0) }) {
            return "Printer"
        }
        if device.openPorts.contains(80) || device.openPorts.contains(443) {
            return "Router/Web Device"
        }
        if device.openPorts.contains(22) {
            return "Linux/Unix Device"
        }
        if device.openPorts.contains(139) || device.openPorts.contains(445) {
            return "Windows PC"
        }
        if let bonjour = device.bonjourType {
            if bonjour.contains("workstation") { return "Mac/PC" }
            if bonjour.contains("airplay") { return "Apple TV/AirPlay" }
            if bonjour.contains("printer") { return "Printer" }
        }
        if let ssdp = device.ssdpInfo {
            if ssdp.contains("Xbox") { return "Xbox" }
            if ssdp.contains("DLNA") { return "Smart TV" }
        }
        return "Unknown Device"
    }

    var iconName: String {
        if device.openPorts.contains(where: { [9100, 515, 631].contains($0) }) {
            return "printer.fill"
        } else if device.openPorts.contains(80) || device.openPorts.contains(443) {
            return "network"
        } else if device.openPorts.contains(22) {
            return "terminal"
        } else if device.openPorts.contains(139) || device.openPorts.contains(445) {
            return "desktopcomputer"
        } else if let bonjour = device.bonjourType, bonjour.contains("airplay") {
            return "airplayvideo"
        } else if let ssdp = device.ssdpInfo, ssdp.contains("Xbox") {
            return "gamecontroller"
        } else {
            return "questionmark.circle"
        }
    }

    var iconAccent: Color {
        if device.openPorts.contains(where: { [9100, 515, 631].contains($0) }) {
            return SharkTheme.printer
        } else if device.openPorts.contains(80) || device.openPorts.contains(443) {
            return SharkTheme.web
        } else if device.openPorts.contains(22) {
            return SharkTheme.linux
        } else if device.openPorts.contains(139) || device.openPorts.contains(445) {
            return SharkTheme.windows
        } else {
            return SharkTheme.unknown
        }
    }
}

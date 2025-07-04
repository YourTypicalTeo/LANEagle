import SwiftUI

struct LANSharkDeviceCard: View {
    let device: ScannedDevice

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SharkTheme.lightBlue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(SharkTheme.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(deviceDisplayName)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                Group {
                    Text(device.ip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let hostname = device.hostname, !hostname.isEmpty, hostname != device.ip {
                        Text(hostname)
                            .font(.caption2)
                            .foregroundColor(SharkTheme.blue)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                HStack(spacing: 12) {
                    Text("\(Int(device.responseTime)) ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if !device.openPorts.isEmpty {
                        Text("Ports: \(device.openPorts.map { String($0) }.joined(separator: ","))")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: SharkTheme.blue.opacity(0.07), radius: 7, x: 0, y: 3)
        )
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
    }

    // Device naming logic as a computed property
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
        } else {
            return "questionmark.circle"
        }
    }
}

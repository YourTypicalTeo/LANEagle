import SwiftUI

struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("LAN Eagle")
                    .font(.largeTitle).bold()
                    .padding(.top)

                HStack(spacing: 32) {
                    Button(action: {
                        networkMonitor.startScan()
                    }) {
                        Label("Start Scan", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(networkMonitor.isScanning)

                    Button(action: {
                        networkMonitor.stopScan()
                    }) {
                        Label("Stop Scan", systemImage: "stop.circle")
                    }
                    .disabled(!networkMonitor.isScanning)
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)

                if let error = networkMonitor.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if networkMonitor.permissionRequested && networkMonitor.devices.isEmpty && !networkMonitor.isScanning {
                    Text("No devices found yet.\nMake sure local network permission is granted in Settings.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }

                List(networkMonitor.devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text("\(device.type) • \(device.ip)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding()
            .navigationTitle("Local Network Scan")
        }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var bonjour = BonjourScanner()
    @StateObject private var ping = PingScanner()
    @State private var isScanning = false

    var body: some View {
        NavigationView {
            List {
                if !bonjour.services.isEmpty {
                    Section("Bonjour Devices") {
                        ForEach(bonjour.services, id: \.self) { result in
                            let endpoint = result.endpoint
                            if case let .service(name, type, domain, _) = endpoint {
                                VStack(alignment: .leading) {
                                    Text(name).font(.headline)
                                    Text(type + "." + domain).font(.subheadline)
                                }
                            }
                        }
                    }
                }
                if !ping.reachableHosts.isEmpty {
                    Section("Reachable Hosts") {
                        ForEach(ping.reachableHosts.sorted(), id: \.self) { ip in
                            Text(ip)
                        }
                    }
                }
            }
            .navigationTitle("LAN Device Tracker")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(isScanning ? "Stop" : "Start") {
                        if isScanning {
                            bonjour.stopBrowsing()
                            ping.stopSweep()
                        } else {
                            startScanning()
                        }
                        isScanning.toggle()
                    }
                }
            }
        }
    }

    private func startScanning() {
        guard let (ip, _) = NetworkHelper.localSubnet() else { return }
        let prefix = ip.split(separator: ".").dropLast().joined(separator: ".")
        bonjour.startBrowsing(type: "_http._tcp")
        ping.startSweep(networkPrefix: String(prefix), port: 80)
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var bonjour = BonjourScanner()
    @StateObject private var scanner = PingScanner()
    @State private var scanning = false

    var body: some View {
        NavigationView {
            List {
                if !bonjour.services.isEmpty {
                    Section("Bonjour Devices") {
                        ForEach(bonjour.services, id: \.self) { result in
                            if case let .service(name, type, domain, _) = result.endpoint {
                                VStack(alignment: .leading) {
                                    Text(name).bold()
                                    Text("\(type).\(domain)")
                                }
                            }
                        }
                    }
                }
                if !scanner.reachableHosts.isEmpty {
                    Section("Reachable Hosts") {
                        ForEach(scanner.reachableHosts.sorted(), id: \.self) { ip in
                            Text(ip)
                        }
                    }
                }
            }
            .navigationTitle("LAN Eagle")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(scanning ? "Stop" : "Start") {
                        if scanning {
                            bonjour.stopBrowsing()
                            scanner.stopSweep()
                        } else {
                            startAll()
                        }
                        scanning.toggle()
                    }
                }
            }
        }
    }

    func startAll() {
        bonjour.startBrowsing(type: "_http._tcp")
        if let (ip, _) = NetworkHelper.localSubnet() {
            let prefix = ip.split(separator: ".").dropLast().joined(separator: ".")
            scanner.startSweep(networkPrefix: prefix, port: 80)
        }
    }
}

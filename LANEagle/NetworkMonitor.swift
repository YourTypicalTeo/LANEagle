import Foundation
import Network

final class NetworkMonitor: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var permissionRequested = false

    private var browser: NetServiceBrowser?
    private var discoveredKeys = Set<String>()
    private var serviceRefs = [String: NetService]()

    // MARK: - Public API

    func startScan() {
        stopScan()
        errorMessage = nil
        isScanning = true
        permissionRequested = true

        let browser = NetServiceBrowser()
        browser.delegate = self
        self.browser = browser

        // Start scanning for Bonjour services (triggers permission prompt)
        browser.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: "local.")
    }

    func stopScan() {
        browser?.stop()
        browser = nil
        isScanning = false
        discoveredKeys.removeAll()
        serviceRefs.removeAll()
        DispatchQueue.main.async {
            self.devices.removeAll()
        }
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let key = "\(service.name).\(service.type).\(service.domain)"
        guard !discoveredKeys.contains(key) else { return }
        discoveredKeys.insert(key)
        service.delegate = self
        serviceRefs[key] = service
        service.resolve(withTimeout: 5)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        for addressData in addresses {
            addressData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                let addr = pointer.bindMemory(to: sockaddr.self).baseAddress
                guard let addr else { return }
                if addr.pointee.sa_family == sa_family_t(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        addr,
                        socklen_t(addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0, let ip = String(validatingUTF8: hostname) {
                        DispatchQueue.main.async {
                            let device = DiscoveredDevice(name: sender.name, type: sender.type, ip: ip)
                            if !self.devices.contains(device) {
                                self.devices.append(device)
                            }
                        }
                    }
                }
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        DispatchQueue.main.async {
            self.errorMessage = "Failed to resolve service: \(sender.name)."
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        DispatchQueue.main.async {
            self.errorMessage = "Service browser failed: \(errorDict)"
            self.isScanning = false
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
}

// MARK: - Model

struct DiscoveredDevice: Hashable, Identifiable {
    let name: String
    let type: String
    let ip: String

    var id: String { "\(name)_\(type)_\(ip)" }
}

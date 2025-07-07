import Foundation
import Network

struct ScannedDevice: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    let responseTime: Double?
    let hostname: String?
    let openPorts: [UInt16]
    let bonjourName: String?
    let bonjourType: String?
    let ssdpInfo: String?
}

class LANScanner: NSObject, ObservableObject {
    @Published var scannedDevices: [ScannedDevice] = []
    @Published var isScanning: Bool = false
    @Published var progress: Float = 0.0
    @Published var scanDuration: Double = 0.0

    private let maxConcurrentConnections = 16
    private var startTime: Date?
    private let commonPorts: [UInt16] = [
        80, 443, 22, 139, 445, 3389, 9100, 21, 23, 53, 515, 631, 548, 554, 8000, 8080, 8443, 5353, 1900
    ]
    private var shouldCancel = false

    // Bonjour/mDNS
    private var bonjourTypeBrowser: NetServiceBrowser?
    private var bonjourServiceBrowsers: [NetServiceBrowser] = []
    private var discoveredTypes: Set<String> = []
    private var discoveredBonjour: [String: ScannedDevice] = [:]
    private var didStop = false

    // SSDP/UPnP
    private var ssdpSocket: UDPSocketReceiver?
    private var discoveredSSDP: [String: String] = [:] // ip: info

    func startScan(subnet: String, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.scannedDevices = []
            self.isScanning = true
            self.progress = 0.0
            self.scanDuration = 0.0
            self.shouldCancel = false
            self.discoveredBonjour = [:]
            self.didStop = false
            self.discoveredTypes = []
            self.discoveredSSDP = [:]
        }
        // Start Bonjour scan in parallel
        self.startBonjourScan()
        // Start SSDP scan in parallel
        self.startSSDPDiscovery()

        DispatchQueue.global(qos: .userInitiated).async {
            self._startScanAsync(subnet: subnet, completion: completion)
        }
    }

    private func _startScanAsync(subnet: String, completion: @escaping () -> Void) {
        self.startTime = Date()
        let queue = DispatchQueue(label: "lan-scan-queue", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrentConnections)

        let totalIPs = 254
        var completedIPs = 0

        let updateBatchSize = 40
        var pendingDevices: [ScannedDevice] = []
        var foundDevices: [String: ScannedDevice] = [:]
        var lastReportedIPs = 0

        for i in 1...254 {
            let ip = "\(subnet).\(i)"
            group.enter()
            semaphore.wait()
            queue.async { [weak self] in
                guard let self = self else { semaphore.signal(); group.leave(); return }
                if self.shouldCancel {
                    semaphore.signal()
                    group.leave()
                    return
                }
                let ipStart = Date()
                var portsResponded: [UInt16] = []
                let portGroup = DispatchGroup()
                for port in self.commonPorts {
                    portGroup.enter()
                    self.checkHost(ip: ip, port: port, timeout: 1.0) { alive in
                        if alive {
                            portsResponded.append(port)
                        }
                        portGroup.leave()
                    }
                }
                portGroup.notify(queue: .global()) {
                    if self.shouldCancel {
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    if !portsResponded.isEmpty {
                        let respTime = Date().timeIntervalSince(ipStart) * 1000
                        self.resolveHostname(ip: ip) { hostname in
                            if self.shouldCancel { return }
                            let device = ScannedDevice(
                                ip: ip,
                                responseTime: respTime,
                                hostname: hostname,
                                openPorts: portsResponded,
                                bonjourName: nil,
                                bonjourType: nil,
                                ssdpInfo: self.discoveredSSDP[ip]
                            )
                            foundDevices[ip] = device
                            pendingDevices.append(device)
                        }
                    }
                    completedIPs += 1
                    // THROTTLE: Only update UI every updateBatchSize addresses
                    if completedIPs - lastReportedIPs >= updateBatchSize || completedIPs == totalIPs {
                        let _ = pendingDevices
                        pendingDevices.removeAll()
                        let progress = Float(completedIPs) / Float(totalIPs)
                        DispatchQueue.main.async {
                            if self.shouldCancel { return }
                            self.progress = progress
                            self.scannedDevices = self.mergeDevices(main: foundDevices, bonjour: self.discoveredBonjour, ssdp: self.discoveredSSDP)
                        }
                        lastReportedIPs = completedIPs
                    }
                    semaphore.signal()
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if self.shouldCancel {
                self.isScanning = false
                self.progress = 0.0
                self.scanDuration = 0.0
                self.scannedDevices = []
                completion()
                self.stopBonjourScan()
                self.stopSSDPDiscovery()
                return
            }
            self.scannedDevices = self.mergeDevices(main: foundDevices, bonjour: self.discoveredBonjour, ssdp: self.discoveredSSDP)
            self.isScanning = false
            self.scanDuration = Date().timeIntervalSince(self.startTime ?? Date())
            self.stopBonjourScan()
            self.stopSSDPDiscovery()
            completion()
        }
    }

    func cancelScan() {
        DispatchQueue.main.async {
            self.shouldCancel = true
            self.didStop = true
            self.stopBonjourScan()
            self.stopSSDPDiscovery()
        }
    }

    private func checkHost(ip: String, port: UInt16, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host(ip)
        let nwport = NWEndpoint.Port(rawValue: port)!
        let connection = NWConnection(host: host, port: nwport, using: .tcp)
        var completed = false

        connection.stateUpdateHandler = { state in
            if completed { return }
            switch state {
            case .ready:
                completed = true
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                completed = true
                connection.cancel()
                completion(false)
            default:
                break
            }
        }
        connection.start(queue: .global())

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if !completed {
                completed = true
                connection.cancel()
                completion(false)
            }
        }
    }

    private func resolveHostname(ip: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global().async {
            let host = CFHostCreateWithName(nil, ip as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            var resolved: DarwinBoolean = false
            if let names = CFHostGetNames(host, &resolved)?.takeUnretainedValue() as? [String], let name = names.first {
                completion(name)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Bonjour/mDNS

    func startBonjourScan() {
        self.bonjourTypeBrowser = NetServiceBrowser()
        self.bonjourTypeBrowser?.delegate = self
        self.bonjourTypeBrowser?.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: "")
    }
    func stopBonjourScan() {
        bonjourTypeBrowser?.stop()
        bonjourServiceBrowsers.forEach { $0.stop() }
        bonjourTypeBrowser = nil
        bonjourServiceBrowsers.removeAll()
        discoveredTypes.removeAll()
    }

    // MARK: - SSDP/UPnP

    func startSSDPDiscovery() {
        ssdpSocket = UDPSocketReceiver { [weak self] ip, info in
            DispatchQueue.main.async {
                self?.discoveredSSDP[ip] = info
                self?.scannedDevices = self?.mergeDevices(main: [:], bonjour: self?.discoveredBonjour ?? [:], ssdp: self?.discoveredSSDP ?? [:]) ?? []
            }
        }
        ssdpSocket?.searchSSDP()
    }

    func stopSSDPDiscovery() {
        ssdpSocket?.close()
        ssdpSocket = nil
    }

    // Merge and deduplicate devices from port scan, Bonjour, and SSDP
    func mergeDevices(main: [String: ScannedDevice], bonjour: [String: ScannedDevice], ssdp: [String: String]) -> [ScannedDevice] {
        var devices = main
        // Bonjour
        for (ip, bdev) in bonjour {
            if let mdev = devices[ip] {
                devices[ip] = ScannedDevice(
                    ip: ip,
                    responseTime: mdev.responseTime,
                    hostname: mdev.hostname ?? bdev.hostname,
                    openPorts: mdev.openPorts,
                    bonjourName: bdev.bonjourName,
                    bonjourType: bdev.bonjourType,
                    ssdpInfo: ssdp[ip] ?? mdev.ssdpInfo
                )
            } else {
                devices[ip] = ScannedDevice(
                    ip: ip,
                    responseTime: nil,
                    hostname: bdev.hostname,
                    openPorts: [],
                    bonjourName: bdev.bonjourName,
                    bonjourType: bdev.bonjourType,
                    ssdpInfo: ssdp[ip]
                )
            }
        }
        // SSDP
        for (ip, info) in ssdp {
            if let dev = devices[ip] {
                devices[ip] = ScannedDevice(
                    ip: ip,
                    responseTime: dev.responseTime,
                    hostname: dev.hostname,
                    openPorts: dev.openPorts,
                    bonjourName: dev.bonjourName,
                    bonjourType: dev.bonjourType,
                    ssdpInfo: info
                )
            } else {
                devices[ip] = ScannedDevice(
                    ip: ip,
                    responseTime: nil,
                    hostname: nil,
                    openPorts: [],
                    bonjourName: nil,
                    bonjourType: nil,
                    ssdpInfo: info
                )
            }
        }
        return devices.values.sorted { $0.ip < $1.ip }
    }
}

// MARK: - NetServiceBrowserDelegate + NetServiceDelegate

extension LANScanner: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if browser == bonjourTypeBrowser {
            let type = service.type
            if !discoveredTypes.contains(type) {
                discoveredTypes.insert(type)
                let browserForType = NetServiceBrowser()
                browserForType.delegate = self
                browserForType.searchForServices(ofType: type, inDomain: "")
                bonjourServiceBrowsers.append(browserForType)
            }
        } else {
            service.delegate = self
            service.resolve(withTimeout: 3)
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        for data in addresses {
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard let sockaddrPtr = ptr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sockaddrPtr, socklen_t(data.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: host)
                    DispatchQueue.main.async {
                        let device = ScannedDevice(
                            ip: ip,
                            responseTime: nil,
                            hostname: sender.hostName,
                            openPorts: [],
                            bonjourName: sender.name,
                            bonjourType: sender.type,
                            ssdpInfo: self.discoveredSSDP[ip]
                        )
                        self.discoveredBonjour[ip] = device
                        self.scannedDevices = self.mergeDevices(main: [:], bonjour: self.discoveredBonjour, ssdp: self.discoveredSSDP)
                    }
                }
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {}
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {}
    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {}
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {}
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {}
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {}
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {}
}

// MARK: - SSDP UDP Socket Receiver

class UDPSocketReceiver {
    private var connection: NWConnection?
    private var listener: NWListener?
    private let onReceive: (String, String) -> Void

    init(onReceive: @escaping (String, String) -> Void) {
        self.onReceive = onReceive
    }

    func searchSSDP() {
        let params = NWParameters.udp
        do {
            listener = try NWListener(using: params, on: 0)
        } catch {
            return
        }
        listener?.stateUpdateHandler = { _ in }
        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            self?.receive(on: conn)
        }
        listener?.start(queue: .global())

        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: ssdp:all\r
        \r
        """
        connection = NWConnection(host: "239.255.255.250", port: 1900, using: .udp)
        connection?.stateUpdateHandler = { _ in }
        connection?.start(queue: .global())
        connection?.send(content: message.data(using: .utf8), completion: .contentProcessed({ _ in }))
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.close()
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, context, isComplete, error in
            guard let self = self, let data = data, error == nil else { return }
            let response = String(decoding: data, as: UTF8.self)
            if let ip = conn.endpoint.debugDescription.split(separator: ":").first?.trimmingCharacters(in: .whitespaces) {
                self.onReceive(String(ip), response)
            }
            if !isComplete {
                self.receive(on: conn)
            }
        }
    }

    func close() {
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
    }
}

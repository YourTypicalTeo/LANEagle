import Foundation
import Network

struct ScannedDevice: Identifiable {
    let id = UUID()
    let ip: String
    let responseTime: Double
    let hostname: String?
    let openPorts: [UInt16]
}

class LANScanner: ObservableObject {
    @Published var scannedDevices: [ScannedDevice] = []
    @Published var isScanning: Bool = false
    @Published var progress: Float = 0.0
    @Published var scanDuration: Double = 0.0

    private let maxConcurrentConnections = 16
    private var startTime: Date?
    private let commonPorts: [UInt16] = [80, 443, 22, 139, 445, 3389, 9100]
    private var shouldCancel = false

    func startScan(subnet: String, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.scannedDevices = []
            self.isScanning = true
            self.progress = 0.0
            self.scanDuration = 0.0
            self.shouldCancel = false

            // Defer actual scan start so UI can update first
            DispatchQueue.main.async {
                self._startScanAsync(subnet: subnet, completion: completion)
            }
        }
    }

    private func _startScanAsync(subnet: String, completion: @escaping () -> Void) {
        self.startTime = Date()
        let queue = DispatchQueue(label: "lan-scan-queue", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrentConnections)

        let totalIPs = 254
        var completedIPs = 0

        // THROTTLE: Only update UI every N addresses for max smoothness
        let updateBatchSize = 40
        var pendingDevices: [ScannedDevice] = []
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
                                openPorts: portsResponded
                            )
                            // THROTTLE: Only append to pendingDevices, not scannedDevices, on background queue
                            pendingDevices.append(device)
                        }
                    }
                    completedIPs += 1
                    // THROTTLE: Only update UI every updateBatchSize addresses
                    if completedIPs - lastReportedIPs >= updateBatchSize || completedIPs == totalIPs {
                        let batchDevices = pendingDevices
                        pendingDevices.removeAll()
                        let progress = Float(completedIPs) / Float(totalIPs)
                        DispatchQueue.main.async {
                            if self.shouldCancel { return }
                            self.progress = progress
                            if !batchDevices.isEmpty {
                                self.scannedDevices.append(contentsOf: batchDevices)
                            }
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
                return
            }
            // Final batch update
            if !pendingDevices.isEmpty {
                self.scannedDevices.append(contentsOf: pendingDevices)
            }
            self.isScanning = false
            self.scanDuration = Date().timeIntervalSince(self.startTime ?? Date())
            completion()
        }
    }

    func cancelScan() {
        DispatchQueue.main.async {
            self.shouldCancel = true
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
}

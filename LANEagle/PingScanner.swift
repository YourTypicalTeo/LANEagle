//
//  PingScanner.swift
//  LANEagle
//
//  Created by Θοδωρης Σκονδρας on 3/7/25.
//

import Foundation
import Network

class PingScanner: ObservableObject {
    @Published var reachableHosts: [String] = []
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "ping-queue", attributes: .concurrent)
    private var running = false

    func startSweep(networkPrefix: String, port: UInt16) {
        stopSweep()
        running = true
        for i in 1...254 {
            let ip = "\(networkPrefix).\(i)"
            queue.async { [weak self] in
                guard let self = self, self.running else { return }
                let endpoint = NWEndpoint.hostPort(host: .init(ip), port: .init(rawValue: port)!)
                let conn = NWConnection(to: endpoint, using: .tcp)
                self.connections.append(conn)
                conn.stateUpdateHandler = { state in
                    if case .ready = state {
                        DispatchQueue.main.async {
                            if !self.reachableHosts.contains(ip) {
                                self.reachableHosts.append(ip)
                            }
                        }
                        conn.cancel()
                    } else if case .failed = state {
                        conn.cancel()
                    }
                }
                conn.start(queue: self.queue)
            }
        }
    }

    func stopSweep() {
        running = false
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }
}

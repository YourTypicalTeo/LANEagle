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
    private let queue = DispatchQueue(label: "PingQueue", attributes: .concurrent)
    private var isRunning = false

    func startSweep(networkPrefix: String, port: UInt16) {
        stopSweep()
        reachableHosts = []
        isRunning = true

        for i in 1...254 {
            let ip = "\(networkPrefix).\(i)"
            queue.async { [weak self] in
                guard let self = self, self.isRunning else { return }
                let host = NWEndpoint.Host(ip)
                let endpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(rawValue: port)!)
                let conn = NWConnection(to: endpoint, using: .tcp)
                self.connections.append(conn)

                conn.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        DispatchQueue.main.async {
                            if !self.reachableHosts.contains(ip) {
                                self.reachableHosts.append(ip)
                            }
                        }
                        conn.cancel()
                    case .failed(_):
                        conn.cancel()
                    default:
                        break
                    }
                }
                conn.start(queue: self.queue)
            }
        }
    }

    func stopSweep() {
        isRunning = false
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }
}

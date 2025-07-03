//
//  NetworkHelper.swift
//  LANEagle
//
//  Created by Θοδωρης Σκονδρας on 3/7/25.
//

import Foundation

class NetworkHelper {
    static func localSubnet() -> (ip: String, netmask: String)? {
        var address: String?
        var netmask: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        defer { freeifaddrs(ifaddr) }

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let saFamily = interface.ifa_addr.pointee.sa_family
            if saFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                    address = String(cString: inet_ntoa(addr))
                    var mask = interface.ifa_netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                    netmask = String(cString: inet_ntoa(mask))
                    break
                }
            }
        }
        if let ip = address, let mask = netmask {
            return (ip, mask)
        }
        return nil
    }
}

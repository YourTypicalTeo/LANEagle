//
//  NetworkHelper.swift
//  LANEagle
//
//  Created by Θοδωρης Σκονδρας on 3/7/25.
//

import Foundation

class NetworkHelper {
    static func localSubnet() -> (ip: String, netmask: String)? {
        var addrPtr: UnsafeMutablePointer<ifaddrs>?
        defer { freeifaddrs(addrPtr) }
        guard getifaddrs(&addrPtr) == 0, let first = addrPtr else { return nil }
        var ip: String?
        var mask: String?
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET), String(cString: interface.ifa_name) == "en0" {
                let addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                let m = interface.ifa_netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                ip = String(cString: inet_ntoa(addr))
                mask = String(cString: inet_ntoa(m))
                break
            }
        }
        if let ip = ip, let mask = mask { return (ip, mask) }
        return nil
    }
}

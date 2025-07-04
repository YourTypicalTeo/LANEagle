import Foundation

func getLocalSubnet() -> String? {
    var address: String?

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    guard let firstAddr = ifaddr else { return nil }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        let addrFamily = interface.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) {
            let name = String(cString: interface.ifa_name)
            if name == "en0" { // WiFi
                var addr = interface.ifa_addr.pointee
                let ip = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        String(cString: inet_ntoa($0.pointee.sin_addr))
                    }
                }
                // Extract subnet (e.g. 192.168.1)
                let comps = ip.split(separator: ".")
                if comps.count == 4 {
                    address = "\(comps[0]).\(comps[1]).\(comps[2])"
                }
            }
        }
    }
    freeifaddrs(ifaddr)
    return address
}

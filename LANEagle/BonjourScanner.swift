//
//  BonjourScanner.swift
//  LANEagle
//
//  Created by Θοδωρης Σκονδρας on 3/7/25.
//
import Foundation
import Network

class BonjourScanner: ObservableObject {
    @Published var services: [NWBrowser.Result] = []
    private var browser: NWBrowser?

    func startBrowsing(type: String) {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: params)
        browser?.browseResultsChangedHandler = { results, _ in
            DispatchQueue.main.async {
                self.services = Array(results)
            }
        }
        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        services.removeAll()
    }
}

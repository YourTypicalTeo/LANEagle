import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var scanner = LANScanner()
    @State private var showAlert = false
    @State private var scanButtonActive = false
    @Environment(\.colorScheme) var colorScheme

    // Typing animation states
    @State private var displayedSubtitle = ""
    private let fullSubtitle = "Sharks Don’t Miss a Thing. \n Neither Should Your Scanner."
    @State private var typingTimer: Timer? = nil

    var body: some View {
        ZStack {
            // Themed background for light/dark mode
            SharkTheme.background(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("LANShark")
                        .font(.system(size: 37, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    // Typing subtitle with white/black depending on mode
                    Text(displayedSubtitle)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.bottom, 8)
                        .onAppear {
                            startTypingAnimation()
                        }
                }
                .padding(.top, 24)

                // Scan Button
                ScanButton(
                    isActive: scanButtonActive,
                    progress: scanner.progress,
                    cancelAction: {
                        scanner.cancelScan()
                        scanButtonActive = false
                    },
                    action: {
                        guard let subnet = getLocalSubnet(), !subnet.isEmpty else {
                            showAlert = true
                            return
                        }
                        scanButtonActive = true
                        scanner.scannedDevices = []
                        DispatchQueue.main.async {
                            scanner.startScan(subnet: subnet) {
                                scanButtonActive = false
                            }
                        }
                    }
                )
                .padding(.horizontal, 36)
                .padding(.bottom, 8)
                .frame(height: 70)

                // Scan progress/info
                if scanner.isScanning {
                    Text("Scanning your network…")
                        .font(.footnote)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.bottom, 3)
                }
                if !scanner.isScanning && scanner.scanDuration > 0 {
                    Text("Scan completed in \(String(format: "%.1f", scanner.scanDuration)) seconds")
                        .font(.footnote)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.bottom, 2)
                }

                // Device List
                VStack(alignment: .leading, spacing: 0) {
                    if !scanner.scannedDevices.isEmpty {
                        Text("Devices Found")
                            .font(.headline)
                            .foregroundColor(SharkTheme.blue(for: colorScheme))
                            .padding(.leading, 12)
                            .padding(.top, 6)
                    }
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(scanner.scannedDevices) { device in
                                LANSharkDeviceCard(device: device)
                            }
                        }
                        .padding(.horizontal, 12) // << Adds spacing from list edges!
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(22)
                .padding(.top, 6)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 2)
        }
        .alert("Could not detect your subnet. Please connect to WiFi and try again.", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Typing Animation Logic
    func startTypingAnimation() {
        displayedSubtitle = ""
        typingTimer?.invalidate()
        var charIndex = 0
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < fullSubtitle.count {
                let index = fullSubtitle.index(fullSubtitle.startIndex, offsetBy: charIndex+1)
                displayedSubtitle = String(fullSubtitle[..<index])
                playKeySound()
                charIndex += 1
            } else {
                timer.invalidate()
                typingTimer = nil
            }
        }
    }

    func playKeySound() {
        AudioServicesPlaySystemSound(1306)
    }
}

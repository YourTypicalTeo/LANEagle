import SwiftUI

struct ScanButton: View {
    let isActive: Bool
    let progress: Float
    var cancelAction: (() -> Void)? = nil
    let action: () -> Void

    @State private var animateGlow = false

    var body: some View {
        Button(action: {
            if !isActive {
                action()
            }
        }) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SharkTheme.blue.opacity(0.3))
                        .frame(height: 62)
                        .scaleEffect(animateGlow ? 1.09 : 1.0)
                        .shadow(color: SharkTheme.blue.opacity(animateGlow ? 0.38 : 0.20), radius: animateGlow ? 18 : 10, y: 3)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animateGlow)
                }
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isActive
                            ? AnyShapeStyle(LinearGradient(
                                gradient: Gradient(colors: [SharkTheme.blue.opacity(0.85), SharkTheme.lightBlue.opacity(0.75)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(SharkTheme.blue)
                    )
                    .frame(height: 54)
                    .shadow(color: SharkTheme.blue.opacity(0.12), radius: 7, y: 2)

                if isActive {
                    HStack(spacing: 16) {
                        ZStack {
                            // TimelineView animates ring independently of state changes
                            TimelineView(.animation) { context in
                                let angle = Double(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)) * 360
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 36, height: 36)
                                    .rotationEffect(.degrees(angle))
                            }
                            Image(systemName: "fish.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Scanning…")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        if let cancelAction = cancelAction {
                            Button(action: cancelAction) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 4)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "fish.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Start Scan")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
            }
            .scaleEffect(isActive ? 1.04 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActive)
        }
        .disabled(isActive)
        .onChange(of: isActive) {
            if isActive {
                animateGlow = false
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    animateGlow = true
                }
            } else {
                animateGlow = false
            }
        }
        .accessibility(label: Text(isActive ? "Scanning network" : "Start Scan"))
    }
}

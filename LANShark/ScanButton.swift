import SwiftUI

/// Animated scan/cancel button that adapts to theme and scan state.
struct ScanButton: View {
    let isActive: Bool
    let progress: Float
    var cancelAction: (() -> Void)? = nil
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var animateGlow = false
    @State private var swimPhase: Double = 0
    @State private var swimTimer: Timer?
    @State private var bubblePhase: Double = 0

    var body: some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SharkTheme.accent(for: colorScheme).opacity(0.28))
                    .frame(height: 62)
                    .scaleEffect(animateGlow ? 1.09 : 1.0)
                    .shadow(color: SharkTheme.accent(for: colorScheme).opacity(animateGlow ? 0.38 : 0.20), radius: animateGlow ? 18 : 10, y: 3)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animateGlow)
            }
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isActive
                        ? AnyShapeStyle(LinearGradient(
                            gradient: Gradient(colors: [
                                SharkTheme.accent(for: colorScheme),
                                SharkTheme.blue(for: colorScheme).opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(SharkTheme.accent(for: colorScheme))
                )
                .frame(height: 54)
                .shadow(color: SharkTheme.accent(for: colorScheme).opacity(0.12), radius: 7, y: 2)

            if isActive {
                HStack(spacing: 16) {
                    ZStack {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(sin(swimPhase) * 10))
                            .offset(y: CGFloat(sin(swimPhase * 1.7) * 4 - 2))
                            .animation(.easeInOut(duration: 0.15), value: swimPhase)
                        BubblesView(phase: bubblePhase)
                            .frame(width: 16, height: 38)
                            .offset(x: 18, y: -16)
                    }
                    Text("Scanning…")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .transition(.opacity)
                    if let cancelAction = cancelAction {
                        Button(action: {
                            cancelAction()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.93))
                                .font(.system(size: 26))
                                .scaleEffect(1.1)
                                .shadow(color: .black.opacity(0.14), radius: 1, x: 0, y: 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Cancel scan"))
                        .padding(.leading, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Button(action: {
                    action()
                }) {
                    HStack(spacing: 12) {
                        Text("Start Scan")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibility(label: Text("Start Scan"))
            }
        }
        .frame(height: 62)
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActive)
        .onChange(of: isActive) { newValue in
            if newValue {
                animateGlow = false
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    animateGlow = true
                }
                swimPhase = 0
                bubblePhase = 0
                swimTimer?.invalidate()
                swimTimer = Timer.scheduledTimer(withTimeInterval: 0.018, repeats: true) { _ in
                    swimPhase += 0.13
                    bubblePhase += 0.015
                }
            } else {
                animateGlow = false
                swimTimer?.invalidate()
                swimTimer = nil
                swimPhase = 0
                bubblePhase = 0
            }
        }
        .onDisappear {
            swimTimer?.invalidate()
            swimTimer = nil
        }
    }
}

struct BubblesView: View {
    let phase: Double

    var body: some View {
        ZStack {
            Bubble(offset: CGFloat((sin(phase * 1.1) + 1) * 6), size: 7, opacity: 0.5, yPhase: phase * 1.0)
            Bubble(offset: CGFloat((sin(phase * 1.7 + 1.8) + 1) * 2), size: 4.5, opacity: 0.35, yPhase: phase * 1.3 + 0.7)
            Bubble(offset: CGFloat((sin(phase * 2.5 + 2.5) + 1) * 8), size: 3, opacity: 0.25, yPhase: phase * 2.1 + 1.2)
        }
    }

    @ViewBuilder
    func Bubble(offset: CGFloat, size: CGFloat, opacity: Double, yPhase: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .offset(x: offset, y: CGFloat(-yPhase * 28).truncatingRemainder(dividingBy: 38))
    }
}

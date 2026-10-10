import SwiftUI

struct LaunchIconView: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: size, height: size)
            .scaleEffect(pulse ? 1.15 : 1)
            .rotationEffect(.degrees(pulse ? -12 : 0))
            .accessibilityLabel("ClickLoop")
            .task {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.35).repeatCount(4, autoreverses: true)) {
                    pulse = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { pulse = false }
            }
    }
}

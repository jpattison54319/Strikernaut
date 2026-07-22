import SwiftUI

struct CountUpText: View {
    let value: Int
    var duration: Double = 0.9
    var font: Font = .title2.bold()
    var color: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0

    var body: some View {
        AnimatedNumber(value: animatedValue, font: font, color: color)
            .onAppear {
                guard !reduceMotion else { animatedValue = Double(value); return }
                withAnimation(.easeOut(duration: duration)) { animatedValue = Double(value) }
            }
    }
}

private struct AnimatedNumber: View, Animatable {
    var value: Double
    let font: Font
    let color: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value.rounded()).formatted())
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
    }
}

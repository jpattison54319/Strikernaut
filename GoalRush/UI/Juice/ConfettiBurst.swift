import SwiftUI

/// One-shot deterministic confetti burst drawn in a single Canvas pass.
struct ConfettiBurst: View {
    let accent: Color
    var particleCount: Int = 60
    var duration: Double = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.distantPast

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { graphics, size in
                    guard elapsed >= 0, elapsed < duration else { return }
                    for index in 0..<particleCount {
                        var random = SeededGenerator(seed: UInt64(index &+ 1) &* 6_364_136_223_846_793_005)
                        let angle = random.unit() * .pi * 2
                        let speed = 90 + random.unit() * 240
                        let spin = random.unit() * .pi * 4
                        let x = size.width / 2 + cos(angle) * speed * elapsed
                        let y = size.height / 2 + sin(angle) * speed * elapsed + 320 * elapsed * elapsed
                        let fade = 1 - elapsed / duration
                        let rect = CGRect(x: x, y: y, width: 5, height: 8)
                        let color: Color = index.isMultiple(of: 3) ? GoalRushTheme.gold : (index.isMultiple(of: 2) ? accent : .white)
                        var transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
                        transform = transform.rotated(by: spin + elapsed * 5)
                        graphics.opacity = fade
                        graphics.fill(Path(rect).applying(transform), with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}

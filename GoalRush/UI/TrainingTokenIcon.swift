import SwiftUI

struct TrainingTokenIcon: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 20

    init(size: CGFloat = 20) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image("TrainingToken")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

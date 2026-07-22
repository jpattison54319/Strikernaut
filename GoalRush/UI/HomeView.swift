import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("MenuHero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            LinearGradient(
                colors: [.black.opacity(0.08), GoalRushTheme.navy.opacity(0.55), GoalRushTheme.navy.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    topBar
                    Spacer(minLength: 108)
                    title
                    modeCards
                    utilityButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Label("\(store.progress.trainingTokens)", systemImage: "hexagon.fill")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(GoalRushTheme.gold)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay { Capsule().stroke(.white.opacity(0.16)) }
                .accessibilityLabel("\(store.progress.trainingTokens) Training Tokens")
            Spacer()
            Button("Settings", systemImage: "gearshape.fill") { store.route = .settings }
                .labelStyle(.iconOnly)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
                .overlay { Circle().stroke(.white.opacity(0.16)) }
                .accessibilityIdentifier("settings")
        }
    }

    private var title: some View {
        VStack(spacing: 7) {
            Text("SOCCER ROGUELITE")
                .font(.caption.bold())
                .tracking(1.4)
                .foregroundStyle(GoalRushTheme.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GoalRushTheme.cyan.opacity(0.13), in: .capsule)
                .overlay { Capsule().stroke(GoalRushTheme.cyan.opacity(0.30)) }
            Text("GOAL RUSH")
                .font(.largeTitle.bold())
                .tracking(2)
        }
    }

    private var modeCards: some View {
        VStack(spacing: 12) {
            HomeModeButton(
                title: "Campaign",
                subtitle: "20 levels • Earth + Mars",
                status: campaignStatus,
                icon: "map.fill",
                colors: [GoalRushTheme.blue, GoalRushTheme.cyan]
            ) {
                store.route = .levels
            }
            .accessibilityIdentifier("play")

            HomeModeButton(
                title: "Endless",
                subtitle: "Infinite waves • New powers",
                status: endlessStatus,
                icon: "infinity",
                colors: [Color(red: 0.72, green: 0.18, blue: 0.82), GoalRushTheme.orange]
            ) {
                store.route = .endless
            }
            .accessibilityIdentifier("endless")
        }
    }

    private var utilityButtons: some View {
        HStack(spacing: 12) {
            Button("Locker", systemImage: "tshirt.fill") { store.route = .gear }
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("gear")
            Button("Upgrades", systemImage: "arrow.up.circle.fill") { store.route = .upgrades }
                .buttonStyle(SecondaryGameButton())
                .accessibilityIdentifier("upgrades")
        }
    }

    private var campaignStatus: String {
        let completed = store.progress.levelRecords.values.filter(\.completed).count
        return "\(completed) / \(GameContent.levels.count) cleared"
    }

    private var endlessStatus: String {
        let record = store.progress.endlessRecords.values.max(by: { $0.bestWave < $1.bestWave }) ?? .empty
        return record.bestWave > 0 ? "Best wave \(record.bestWave)" : "New run ready"
    }
}

private struct HomeModeButton: View {
    let title: String
    let subtitle: String
    let status: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2.bold())
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.16), in: .rect(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status.uppercased())
                        .font(.caption2.bold())
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.top, 2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.28)) }
            .shadow(color: (colors.first ?? .clear).opacity(0.34), radius: 14, y: 7)
        }
        .buttonStyle(HomeModeButtonStyle())
    }
}

private struct HomeModeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? 0.07 : 0)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}

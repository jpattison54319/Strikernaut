import SwiftUI

struct GearView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedSlot: GearSlot = .torso
    @State private var selectedSheet: LockerSheet?

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "LockerRoom") {
            VStack(spacing: 0) {
                GameDestinationBar(
                    title: "Locker",
                    trailingText: "About Gear",
                    onHome: goHome,
                    onInfo: { show(.about) }
                )

                ScrollView {
                    VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) {
                        equippedSummary

                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilityLockerStage
                        } else {
                            lockerStage
                        }

                        detailActions
                    }
                    .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                    .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $selectedSheet) { sheet in
            switch sheet {
            case .itemDetails:
                LockerItemDetailsSheet(selectedSlot: selectedSlot)
                    .presentationDetents([.medium])
            case .setProgress:
                LockerSetProgressSheet()
                    .presentationDetents([.medium, .large])
            case .about:
                GearInfoSheet()
                    .presentationDetents([.medium])
            }
        }
        .sensoryFeedback(trigger: store.progress.equippedGear) { _, _ in
            store.settings.hapticsEnabled ? .selection : nil
        }
    }

    private var equippedSummary: some View {
        HStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
            Image(systemName: "tshirt.fill")
                .foregroundStyle(GoalRushTheme.cyan)
                .accessibilityHidden(true)
            Text("LIVE LOADOUT")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.68))
            Spacer(minLength: 8)
            Text("\(store.progress.equippedGear.count)/5 equipped")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.hud)
        .accessibilityElement(children: .combine)
    }

    private var lockerStage: some View {
        GeometryReader { geometry in
            ZStack {
                Image("LockerRoom")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.black.opacity(0.08), .clear, .black.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)

                LockerAvatarView(loadout: store.progress.loadout)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(Array(GearSlot.allCases.enumerated()), id: \.element) { index, slot in
                    gearRow(slot)
                        .position(x: geometry.size.width / 2, y: [128, 220, 286, 346, 400][index])
                }
            }
            .clipShape(.rect(cornerRadius: GoalRushTheme.Metrics.panelRadius))
            .overlay {
                RoundedRectangle(cornerRadius: GoalRushTheme.Metrics.panelRadius)
                    .stroke(GoalRushTheme.emphasizedSurfaceStroke)
            }
            .shadow(color: GoalRushTheme.surfaceShadow, radius: 18, y: 9)
        }
        .frame(height: 454)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Character gear preview")
    }

    private var accessibilityLockerStage: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ZStack {
                Image("LockerRoom")
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
                LockerAvatarView(loadout: store.progress.loadout)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(height: 280)
            .clipped()
            .clipShape(.rect(cornerRadius: GoalRushTheme.Metrics.panelRadius))

            ForEach(GearSlot.allCases) { slot in
                gearRow(slot)
                    .padding(.horizontal, GoalRushTheme.Metrics.compactSpacing)
                    .frame(minHeight: 60)
                    .gameSurface(.panel)
            }
        }
    }

    private func gearRow(_ slot: GearSlot) -> some View {
        GearCycleRow(
            slot: slot,
            itemName: store.progress.equippedGear[slot].map { GearCatalog.item($0).shortName } ?? "Empty",
            canCycle: !GearCatalog.items(for: slot, unlocked: store.progress.unlockedGear).isEmpty,
            selected: selectedSlot == slot,
            showsNewBadge: hasUnseenGear(in: slot),
            previous: { cycle(slot, direction: -1) },
            next: { cycle(slot, direction: 1) }
        )
        .onAppear { markVisibleGearSeen(in: slot) }
    }

    @ViewBuilder
    private var detailActions: some View {
        let actions = Group {
            FloatingGameActionButton(
                title: "Item Details",
                subtitle: selectedSlot.title,
                systemImage: selectedSlot.icon,
                accent: GoalRushTheme.cyan
            ) {
                show(.itemDetails)
            }
            .accessibilityLabel("Item Details")

            FloatingGameActionButton(
                title: "Set Progress",
                subtitle: "Earth & Mars",
                systemImage: "square.grid.2x2.fill",
                accent: GoalRushTheme.gold
            ) {
                show(.setProgress)
            }
            .accessibilityLabel("Set Progress")
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: GoalRushTheme.Metrics.sectionSpacing) { actions }
        } else {
            HStack(alignment: .top, spacing: GoalRushTheme.Metrics.sectionSpacing) { actions }
        }
    }

    private func cycle(_ slot: GearSlot, direction: Int) {
        selectedSlot = slot
        store.uiAudio.play(.tap)
        store.cycleGear(in: slot, direction: direction)
        markVisibleGearSeen(in: slot)
    }

    private func show(_ sheet: LockerSheet) {
        store.uiAudio.play(.tap)
        selectedSheet = sheet
    }

    private func goHome() {
        store.uiAudio.play(.tap)
        store.route = .home
    }

    private func hasUnseenGear(in slot: GearSlot) -> Bool {
        GearCatalog.items(for: slot, unlocked: store.progress.unlockedGear).contains { item in
            store.progress.unlockedGear.contains(item.id) && !store.progress.seenGearIDs.contains(item.id)
        }
    }

    private func markVisibleGearSeen(in slot: GearSlot) {
        guard let id = store.progress.equippedGear[slot] else { return }
        store.markGearSeen(id)
    }
}

private enum LockerSheet: String, Identifiable {
    case itemDetails
    case setProgress
    case about

    var id: String { rawValue }
}

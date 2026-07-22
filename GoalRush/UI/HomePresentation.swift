enum HomePrimaryAction: Equatable {
    case campaign(level: Int)
    case endless
}

enum HomePresentation {
    static func primaryAction(progress: PlayerProgress) -> HomePrimaryAction {
        guard let level = GameContent.levels.first(where: {
            $0.number <= progress.highestUnlockedLevel
                && progress.levelRecords[$0.number]?.completed != true
        }) else {
            return .endless
        }

        return .campaign(level: level.number)
    }

    static func completedMissionCount(_ missions: [MissionState]) -> Int {
        missions.filter { $0.isComplete && !$0.claimed }.count
    }
}

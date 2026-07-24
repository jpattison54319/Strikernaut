import Foundation

struct LevelDefinition: Identifiable, Sendable {
    let number: Int
    let world: WorldID
    let worldLevel: Int
    let name: String
    let subtitle: String
    let duration: TimeInterval
    let spawnInterval: TimeInterval
    let enemies: [EnemyKind]
    let objects: [FieldObjectKind]
    let concepts: [CampaignConcept]
    let hasBoss: Bool
    let firstClearBonus: Int
    let replayBonus: Int

    var id: Int { number }
    var waveCount: Int { CampaignBalance.waveCount(worldLevel: worldLevel) }
    var waveDuration: TimeInterval { duration / Double(waveCount) }

    init(
        number: Int,
        world: WorldID = .earth,
        worldLevel: Int? = nil,
        name: String,
        subtitle: String,
        duration: TimeInterval,
        spawnInterval: TimeInterval,
        enemies: [EnemyKind],
        objects: [FieldObjectKind],
        concepts: [CampaignConcept] = [],
        hasBoss: Bool,
        firstClearBonus: Int,
        replayBonus: Int
    ) {
        self.number = number
        self.world = world
        self.worldLevel = worldLevel ?? number
        self.name = name
        self.subtitle = subtitle
        self.duration = duration
        self.spawnInterval = spawnInterval
        self.enemies = enemies
        self.objects = objects
        self.concepts = concepts
        self.hasBoss = hasBoss
        self.firstClearBonus = firstClearBonus
        self.replayBonus = replayBonus
    }
}

enum GameContent {
    static let worlds: [WorldDefinition] = [
        .init(
            id: .earth,
            name: "Earth",
            subtitle: "Training Grounds",
            chapter: "WORLD 1",
            levelRange: 1...10,
            gameplayAsset: "GameplayArena",
            heroAsset: "GameplayArena",
            boss: .titanKeeper
        ),
        .init(
            id: .mars,
            name: "Mars",
            subtitle: "Red Frontier",
            chapter: "WORLD 2",
            levelRange: 11...20,
            gameplayAsset: "MarsArena",
            heroAsset: "MarsArena",
            boss: .marsColossus
        )
    ]

    static let levels: [LevelDefinition] = [
        .init(number: 1, name: "First Touch", subtitle: "Find your feet", duration: 85, spawnInterval: 1.55, enemies: [.coneRunner], objects: [.ballCart], concepts: [.automaticKicks], hasBoss: false, firstClearBonus: 100, replayBonus: 50),
        .init(number: 2, name: "Hold the Line", subtitle: "Meet the defenders", duration: 120, spawnInterval: 1.45, enemies: [.coneRunner, .dummyDefender], objects: [.ballCart, .waterCooler], hasBoss: false, firstClearBonus: 125, replayBonus: 60),
        .init(number: 3, name: "Quick Feet", subtitle: "Track the zigzag", duration: 135, spawnInterval: 1.35, enemies: [.coneRunner, .dummyDefender, .tackleBot], objects: [.ballCart, .coneBarricade], hasBoss: false, firstClearBonus: 150, replayBonus: 70),
        .init(number: 4, name: "Hands Up", subtitle: "Break the shield", duration: 145, spawnInterval: 1.30, enemies: [.dummyDefender, .tackleBot, .keeperDrone], objects: [.waterCooler, .tacticsBoard], hasBoss: false, firstClearBonus: 175, replayBonus: 80),
        .init(number: 5, name: "Press Test", subtitle: "Survive the elite wave", duration: 150, spawnInterval: 1.20, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone], objects: [.ballCart, .equipmentTrunk], hasBoss: false, firstClearBonus: 200, replayBonus: 90),
        .init(number: 6, name: "Return Fire", subtitle: "Dodge the launchers", duration: 155, spawnInterval: 1.18, enemies: [.dummyDefender, .tackleBot, .ballLauncher], objects: [.waterCooler, .coneBarricade], hasBoss: false, firstClearBonus: 225, replayBonus: 100),
        .init(number: 7, name: "Tight Spaces", subtitle: "Choose a clean lane", duration: 165, spawnInterval: 1.12, enemies: [.coneRunner, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .coneBarricade], hasBoss: false, firstClearBonus: 250, replayBonus: 110),
        .init(number: 8, name: "Full Press", subtitle: "Every bot joins in", duration: 170, spawnInterval: 1.02, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: false, firstClearBonus: 275, replayBonus: 120),
        .init(number: 9, name: "Keeper's Trial", subtitle: "Read the danger zones", duration: 175, spawnInterval: 0.96, enemies: [.tackleBot, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .equipmentTrunk], hasBoss: false, firstClearBonus: 300, replayBonus: 135),
        .init(number: 10, name: "Titan Keeper", subtitle: "Bring down the machine", duration: 180, spawnInterval: 1.02, enemies: [.dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: true, firstClearBonus: 400, replayBonus: 175),
        .init(number: 11, world: .mars, worldLevel: 1, name: "Red Arrival", subtitle: "Meet the dust sprites", duration: 115, spawnInterval: 1.34, enemies: [.dustSprite], objects: [.oxygenPod, .meteorCrate], concepts: [.marsArena], hasBoss: false, firstClearBonus: 425, replayBonus: 185),
        .init(number: 12, world: .mars, worldLevel: 2, name: "Rover Rush", subtitle: "Crack the colony armor", duration: 130, spawnInterval: 1.26, enemies: [.dustSprite, .roverRaider], objects: [.oxygenPod, .holoGate], hasBoss: false, firstClearBonus: 450, replayBonus: 195),
        .init(number: 13, world: .mars, worldLevel: 3, name: "Crater Dance", subtitle: "Track the sideways swarm", duration: 140, spawnInterval: 1.18, enemies: [.dustSprite, .roverRaider, .craterCrawler], objects: [.meteorCrate, .crystalBarricade], hasBoss: false, firstClearBonus: 475, replayBonus: 205),
        .init(number: 14, world: .mars, worldLevel: 4, name: "Saucer Shield", subtitle: "Bend shots around the guard", duration: 150, spawnInterval: 1.12, enemies: [.roverRaider, .craterCrawler, .saucerKeeper], objects: [.oxygenPod, .holoGate], hasBoss: false, firstClearBonus: 500, replayBonus: 220),
        .init(number: 15, world: .mars, worldLevel: 5, name: "Dust Storm", subtitle: "Hold through the red wave", duration: 155, spawnInterval: 1.02, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper], objects: [.meteorCrate, .artifactVault], hasBoss: false, firstClearBonus: 540, replayBonus: 235),
        .init(number: 16, world: .mars, worldLevel: 6, name: "Plasma Rain", subtitle: "Dodge the alien strikers", duration: 160, spawnInterval: 0.98, enemies: [.roverRaider, .craterCrawler, .plasmaStriker], objects: [.oxygenPod, .crystalBarricade], hasBoss: false, firstClearBonus: 575, replayBonus: 250),
        .init(number: 17, world: .mars, worldLevel: 7, name: "Low Gravity", subtitle: "Read every open lane", duration: 170, spawnInterval: 0.92, enemies: [.dustSprite, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .crystalBarricade], hasBoss: false, firstClearBonus: 610, replayBonus: 265),
        .init(number: 18, world: .mars, worldLevel: 8, name: "Alien Press", subtitle: "The whole colony attacks", duration: 175, spawnInterval: 0.86, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: false, firstClearBonus: 650, replayBonus: 280),
        .init(number: 19, world: .mars, worldLevel: 9, name: "Colony Trial", subtitle: "Survive the frontier elite", duration: 180, spawnInterval: 0.80, enemies: [.craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .artifactVault], hasBoss: false, firstClearBonus: 700, replayBonus: 300),
        .init(number: 20, world: .mars, worldLevel: 10, name: "Mars Colossus", subtitle: "Defeat the ruler of the crater", duration: 190, spawnInterval: 0.88, enemies: [.roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: true, firstClearBonus: 850, replayBonus: 350)
    ]

    static func level(_ number: Int) -> LevelDefinition {
        levels[max(0, min(number - 1, levels.count - 1))]
    }

    static func world(_ id: WorldID) -> WorldDefinition {
        worlds.first(where: { $0.id == id }) ?? worlds[0]
    }

    static func levels(in world: WorldID) -> [LevelDefinition] {
        levels.filter { $0.world == world }
    }

    static func isWorldUnlocked(_ world: WorldID, progress: PlayerProgress) -> Bool {
        switch world {
        case .earth: true
        case .mars: progress.highestUnlockedLevel >= GameContent.world(.mars).levelRange.lowerBound
        }
    }
}

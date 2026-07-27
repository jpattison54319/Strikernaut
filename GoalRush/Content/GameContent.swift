import Foundation

struct LevelDefinition: Identifiable, Sendable {
    let number: Int
    let world: WorldID
    let worldLevel: Int
    let name: String
    let subtitle: String
    /// Historical pacing target retained for offline balance comparisons only.
    let referenceDuration: TimeInterval
    let spawnInterval: TimeInterval
    let enemies: [EnemyKind]
    let objects: [FieldObjectKind]
    let concepts: [CampaignConcept]
    let hasBoss: Bool
    let firstClearBonus: Int
    let replayBonus: Int

    var id: Int { number }
    var waveCount: Int { CampaignBalance.waveCount(worldLevel: worldLevel) }
    var referenceWaveDuration: TimeInterval { referenceDuration / Double(waveCount) }

    init(
        number: Int,
        world: WorldID = .earth,
        worldLevel: Int? = nil,
        name: String,
        subtitle: String,
        referenceDuration: TimeInterval,
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
        self.referenceDuration = referenceDuration
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
            mapAsset: "EarthWorldMap",
            boss: .titanKeeper,
            rule: nil,
            temporaryPowers: [.rapidFire, .split, .heatSeeking]
        ),
        .init(
            id: .moon,
            name: "Moon",
            subtitle: "Lunar League",
            chapter: "WORLD 2",
            levelRange: 11...20,
            gameplayAsset: "MoonArena",
            heroAsset: "MoonArena",
            mapAsset: "MoonWorldMap",
            boss: .lunarWarden,
            rule: .lunarCycle,
            temporaryPowers: [.reverse, .ice, .orbitShot]
        ),
        .init(
            id: .mars,
            name: "Mars",
            subtitle: "Red Frontier",
            chapter: "WORLD 3",
            levelRange: 21...30,
            gameplayAsset: "MarsArena",
            heroAsset: "MarsArena",
            mapAsset: "MarsWorldMap",
            boss: .marsColossus,
            rule: .volatileCores,
            temporaryPowers: [.fire, .explosive, .solarPierce]
        )
    ]

    static let levels: [LevelDefinition] = [
        .init(number: 1, name: "First Touch", subtitle: "Find your feet", referenceDuration: 85, spawnInterval: 1.55, enemies: [.coneRunner], objects: [.ballCart], concepts: [.automaticKicks], hasBoss: false, firstClearBonus: 100, replayBonus: 45),
        .init(number: 2, name: "Hold the Line", subtitle: "Meet the defenders", referenceDuration: 120, spawnInterval: 1.45, enemies: [.coneRunner, .dummyDefender], objects: [.ballCart, .waterCooler], hasBoss: false, firstClearBonus: 110, replayBonus: 50),
        .init(number: 3, name: "Quick Feet", subtitle: "Track the zigzag", referenceDuration: 135, spawnInterval: 1.35, enemies: [.coneRunner, .dummyDefender, .tackleBot], objects: [.ballCart, .coneBarricade], hasBoss: false, firstClearBonus: 120, replayBonus: 55),
        .init(number: 4, name: "Hands Up", subtitle: "Break the shield", referenceDuration: 145, spawnInterval: 1.30, enemies: [.dummyDefender, .tackleBot, .keeperDrone], objects: [.waterCooler, .tacticsBoard], hasBoss: false, firstClearBonus: 130, replayBonus: 60),
        .init(number: 5, name: "Press Test", subtitle: "Survive the elite wave", referenceDuration: 150, spawnInterval: 1.20, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone], objects: [.ballCart, .equipmentTrunk], hasBoss: false, firstClearBonus: 150, replayBonus: 70),
        .init(number: 6, name: "Return Fire", subtitle: "Dodge the launchers", referenceDuration: 155, spawnInterval: 1.18, enemies: [.dummyDefender, .tackleBot, .ballLauncher], objects: [.waterCooler, .coneBarricade], hasBoss: false, firstClearBonus: 165, replayBonus: 75),
        .init(number: 7, name: "Tight Spaces", subtitle: "Choose a clean lane", referenceDuration: 165, spawnInterval: 1.12, enemies: [.coneRunner, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .coneBarricade], hasBoss: false, firstClearBonus: 180, replayBonus: 80),
        .init(number: 8, name: "Full Press", subtitle: "Every bot joins in", referenceDuration: 170, spawnInterval: 1.02, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: false, firstClearBonus: 210, replayBonus: 95),
        .init(number: 9, name: "Keeper's Trial", subtitle: "Read the danger zones", referenceDuration: 175, spawnInterval: 0.96, enemies: [.tackleBot, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .equipmentTrunk], hasBoss: false, firstClearBonus: 240, replayBonus: 110),
        .init(number: 10, name: "Titan Keeper", subtitle: "Bring down the machine", referenceDuration: 180, spawnInterval: 1.02, enemies: [.dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: true, firstClearBonus: 320, replayBonus: 145),
        .init(number: 11, world: .moon, worldLevel: 1, name: "First Step", subtitle: "Enter the Lunar League", referenceDuration: 115, spawnInterval: 1.34, enemies: [.regolithRunner], objects: [.roverBattery, .satelliteRelay], concepts: [.lunarCycle], hasBoss: false, firstClearBonus: 240, replayBonus: 105),
        .init(number: 12, world: .moon, worldLevel: 2, name: "Moon Bounce", subtitle: "Track the lunar hoppers", referenceDuration: 130, spawnInterval: 1.27, enemies: [.regolithRunner, .lunarHopper], objects: [.roverBattery, .regolithBarricade], hasBoss: false, firstClearBonus: 255, replayBonus: 110),
        .init(number: 13, world: .moon, worldLevel: 3, name: "Orbital Lane", subtitle: "Read the circling drones", referenceDuration: 140, spawnInterval: 1.20, enemies: [.regolithRunner, .lunarHopper, .orbitDrone], objects: [.satelliteRelay, .gravityCell], hasBoss: false, firstClearBonus: 270, replayBonus: 115),
        .init(number: 14, world: .moon, worldLevel: 4, name: "Eclipse Guard", subtitle: "Break the shadow shield", referenceDuration: 150, spawnInterval: 1.14, enemies: [.lunarHopper, .orbitDrone, .eclipseKeeper], objects: [.roverBattery, .regolithBarricade], hasBoss: false, firstClearBonus: 285, replayBonus: 120),
        .init(number: 15, world: .moon, worldLevel: 5, name: "Gravity Shift", subtitle: "Survive the debris cycle", referenceDuration: 155, spawnInterval: 1.06, enemies: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper], objects: [.gravityCell, .lunarVault], hasBoss: false, firstClearBonus: 320, replayBonus: 135),
        .init(number: 16, world: .moon, worldLevel: 6, name: "Dark-Side Fire", subtitle: "Dodge the gravity strikers", referenceDuration: 160, spawnInterval: 1.00, enemies: [.lunarHopper, .orbitDrone, .gravityStriker], objects: [.satelliteRelay, .regolithBarricade], hasBoss: false, firstClearBonus: 335, replayBonus: 140),
        .init(number: 17, world: .moon, worldLevel: 7, name: "Crater Cross", subtitle: "Hold every drifting lane", referenceDuration: 170, spawnInterval: 0.95, enemies: [.regolithRunner, .eclipseKeeper, .gravityStriker], objects: [.roverBattery, .gravityCell, .regolithBarricade], hasBoss: false, firstClearBonus: 350, replayBonus: 150),
        .init(number: 18, world: .moon, worldLevel: 8, name: "Orbital Press", subtitle: "The whole league attacks", referenceDuration: 175, spawnInterval: 0.89, enemies: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.satelliteRelay, .lunarVault], hasBoss: false, firstClearBonus: 390, replayBonus: 165),
        .init(number: 19, world: .moon, worldLevel: 9, name: "Lunar Trial", subtitle: "Survive the eclipse elite", referenceDuration: 180, spawnInterval: 0.84, enemies: [.orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.gravityCell, .regolithBarricade, .lunarVault], hasBoss: false, firstClearBonus: 430, replayBonus: 180),
        .init(number: 20, world: .moon, worldLevel: 10, name: "Lunar Warden", subtitle: "Defeat the keeper of the dark side", referenceDuration: 190, spawnInterval: 0.92, enemies: [.lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.roverBattery, .lunarVault], hasBoss: true, firstClearBonus: 575, replayBonus: 240),
        .init(number: 21, world: .mars, worldLevel: 1, name: "Red Arrival", subtitle: "Meet the dust sprites", referenceDuration: 120, spawnInterval: 1.24, enemies: [.dustSprite], objects: [.oxygenPod, .meteorCrate], concepts: [.marsArena], hasBoss: false, firstClearBonus: 500, replayBonus: 210),
        .init(number: 22, world: .mars, worldLevel: 2, name: "Rover Rush", subtitle: "Crack the colony armor", referenceDuration: 135, spawnInterval: 1.17, enemies: [.dustSprite, .roverRaider], objects: [.oxygenPod, .holoGate], hasBoss: false, firstClearBonus: 520, replayBonus: 220),
        .init(number: 23, world: .mars, worldLevel: 3, name: "Crater Dance", subtitle: "Track the sideways swarm", referenceDuration: 145, spawnInterval: 1.10, enemies: [.dustSprite, .roverRaider, .craterCrawler], objects: [.meteorCrate, .crystalBarricade], hasBoss: false, firstClearBonus: 540, replayBonus: 230),
        .init(number: 24, world: .mars, worldLevel: 4, name: "Saucer Shield", subtitle: "Bend shots around the guard", referenceDuration: 155, spawnInterval: 1.04, enemies: [.roverRaider, .craterCrawler, .saucerKeeper], objects: [.oxygenPod, .holoGate], hasBoss: false, firstClearBonus: 560, replayBonus: 240),
        .init(number: 25, world: .mars, worldLevel: 5, name: "Dust Storm", subtitle: "Hold through the red wave", referenceDuration: 160, spawnInterval: 0.97, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper], objects: [.meteorCrate, .artifactVault], hasBoss: false, firstClearBonus: 600, replayBonus: 255),
        .init(number: 26, world: .mars, worldLevel: 6, name: "Plasma Rain", subtitle: "Dodge the alien strikers", referenceDuration: 165, spawnInterval: 0.92, enemies: [.roverRaider, .craterCrawler, .plasmaStriker], objects: [.oxygenPod, .crystalBarricade], hasBoss: false, firstClearBonus: 625, replayBonus: 265),
        .init(number: 27, world: .mars, worldLevel: 7, name: "Crimson Crossfire", subtitle: "Read every volatile lane", referenceDuration: 175, spawnInterval: 0.87, enemies: [.dustSprite, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .crystalBarricade], hasBoss: false, firstClearBonus: 650, replayBonus: 275),
        .init(number: 28, world: .mars, worldLevel: 8, name: "Alien Press", subtitle: "The whole colony attacks", referenceDuration: 180, spawnInterval: 0.82, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: false, firstClearBonus: 700, replayBonus: 295),
        .init(number: 29, world: .mars, worldLevel: 9, name: "Colony Trial", subtitle: "Survive the frontier elite", referenceDuration: 185, spawnInterval: 0.77, enemies: [.craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .artifactVault], hasBoss: false, firstClearBonus: 760, replayBonus: 320),
        .init(number: 30, world: .mars, worldLevel: 10, name: "Mars Colossus", subtitle: "Defeat the ruler of the crater", referenceDuration: 195, spawnInterval: 0.84, enemies: [.roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: true, firstClearBonus: 950, replayBonus: 400)
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
        case .moon, .mars:
            progress.highestUnlockedLevel >= GameContent.world(world).levelRange.lowerBound
        }
    }
}

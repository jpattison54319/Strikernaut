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

    var id: Int { number }
    var waveCount: Int { CampaignBalance.waveCount(worldLevel: worldLevel) }
    var referenceWaveDuration: TimeInterval { referenceDuration / Double(waveCount) }
    var firstClearBonus: Int {
        EconomyBalance.campaignFirstClearBonus(
            world: world,
            worldLevel: worldLevel,
            hasBoss: hasBoss
        )
    }
    var replayBonus: Int {
        EconomyBalance.campaignReplayBonus(
            world: world,
            worldLevel: worldLevel,
            hasBoss: hasBoss
        )
    }

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
        hasBoss: Bool
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
            hazard: nil,
            temporaryPowers: [.rapidFire, .split, .heatSeeking],
            endlessEnemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher],
            endlessObjects: [.ballCart, .waterCooler, .tacticsBoard, .coneBarricade, .equipmentTrunk]
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
            hazard: .init(cadence: 16, telegraphDuration: 1.25, activeDuration: 0.35, baseDamage: 16),
            temporaryPowers: [.reverse, .ice, .orbitShot],
            endlessEnemies: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker],
            endlessObjects: [.roverBattery, .satelliteRelay, .regolithBarricade, .gravityCell, .lunarVault]
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
            hazard: nil,
            temporaryPowers: [.fire, .explosive, .solarPierce],
            endlessEnemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker],
            endlessObjects: [.oxygenPod, .meteorCrate, .holoGate, .crystalBarricade, .artifactVault]
        ),
        .init(
            id: .jupiter,
            name: "Jupiter",
            subtitle: "Storm Citadel",
            chapter: "WORLD 4",
            levelRange: 31...40,
            gameplayAsset: "JupiterArena",
            heroAsset: "JupiterArena",
            mapAsset: "JupiterWorldMap",
            boss: .tempestRegent,
            rule: .windShear,
            hazard: .init(cadence: 14, telegraphDuration: 1.0, activeDuration: 1.6, baseDamage: 10),
            temporaryPowers: [.rapidFire, .heatSeeking, .gravityWell],
            endlessEnemies: [.cloudRunner, .pressureBrute, .vortexSkimmer, .stormKeeper, .boltStriker],
            endlessObjects: [.pressureCell, .cloudCondenser, .windGate, .lightningMast, .stormVault]
        ),
        .init(
            id: .saturn,
            name: "Saturn",
            subtitle: "Crown of Rings",
            chapter: "WORLD 5",
            levelRange: 41...50,
            gameplayAsset: "SaturnArena",
            heroAsset: "SaturnArena",
            mapAsset: "SaturnWorldMap",
            boss: .crownSovereign,
            rule: .ringSweep,
            hazard: .init(cadence: 13, telegraphDuration: 1.25, activeDuration: 1.1, baseDamage: 10),
            temporaryPowers: [.orbitShot, .split, .ringReturn],
            endlessEnemies: [.ringRunner, .iceMason, .shepherdDrone, .haloKeeper, .shardStriker],
            endlessObjects: [.ringShardCrate, .thermalPod, .shepherdBeacon, .iceBarricade, .crownVault]
        ),
        .init(
            id: .uranus,
            name: "Uranus",
            subtitle: "Tilted Frontier",
            chapter: "WORLD 6",
            levelRange: 51...60,
            gameplayAsset: "UranusArena",
            heroAsset: "UranusArena",
            mapAsset: "UranusWorldMap",
            boss: .axisPrime,
            rule: .cryoDrift,
            hazard: .init(cadence: 12, telegraphDuration: 0.8, activeDuration: 3.0, baseDamage: 11),
            temporaryPowers: [.ice, .reverse, .polarLink],
            endlessEnemies: [.frostSprinter, .tiltBrute, .auroraDrifter, .polarKeeper, .magnetStriker],
            endlessObjects: [.magneticCoil, .cryoCanister, .auroraRelay, .frostBarricade, .polarVault]
        ),
        .init(
            id: .neptune,
            name: "Neptune",
            subtitle: "Tempest Deep",
            chapter: "WORLD 7",
            levelRange: 61...70,
            gameplayAsset: "NeptuneArena",
            heroAsset: "NeptuneArena",
            mapAsset: "NeptuneWorldMap",
            boss: .abyssalMonarch,
            rule: .pressureTide,
            hazard: .init(cadence: 11, telegraphDuration: 1.2, activeDuration: 2.8, baseDamage: 12),
            temporaryPowers: [.explosive, .solarPierce, .undertow],
            endlessEnemies: [.mistRunner, .currentBrute, .squallRay, .tridentKeeper, .pressureStriker],
            endlessObjects: [.stormBattery, .oxygenBell, .currentGate, .coralBarricade, .trenchVault]
        )
    ]

    static let levels: [LevelDefinition] = [
        .init(number: 1, name: "First Touch", subtitle: "Find your feet", referenceDuration: 85, spawnInterval: 1.55, enemies: [.coneRunner], objects: [.ballCart], concepts: [.automaticKicks], hasBoss: false),
        .init(number: 2, name: "Hold the Line", subtitle: "Meet the defenders", referenceDuration: 120, spawnInterval: 1.45, enemies: [.coneRunner, .dummyDefender], objects: [.ballCart, .waterCooler], hasBoss: false),
        .init(number: 3, name: "Quick Feet", subtitle: "Track the zigzag", referenceDuration: 135, spawnInterval: 1.35, enemies: [.coneRunner, .dummyDefender, .tackleBot], objects: [.ballCart, .coneBarricade], hasBoss: false),
        .init(number: 4, name: "Hands Up", subtitle: "Break the shield", referenceDuration: 145, spawnInterval: 1.30, enemies: [.dummyDefender, .tackleBot, .keeperDrone], objects: [.waterCooler, .tacticsBoard], hasBoss: false),
        .init(number: 5, name: "Press Test", subtitle: "Survive the elite wave", referenceDuration: 150, spawnInterval: 1.20, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone], objects: [.ballCart, .equipmentTrunk], hasBoss: false),
        .init(number: 6, name: "Return Fire", subtitle: "Dodge the launchers", referenceDuration: 155, spawnInterval: 1.18, enemies: [.dummyDefender, .tackleBot, .ballLauncher], objects: [.waterCooler, .coneBarricade], hasBoss: false),
        .init(number: 7, name: "Tight Spaces", subtitle: "Choose a clean lane", referenceDuration: 165, spawnInterval: 1.12, enemies: [.coneRunner, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .coneBarricade], hasBoss: false),
        .init(number: 8, name: "Full Press", subtitle: "Every bot joins in", referenceDuration: 170, spawnInterval: 1.02, enemies: [.coneRunner, .dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: false),
        .init(number: 9, name: "Keeper's Trial", subtitle: "Read the danger zones", referenceDuration: 175, spawnInterval: 0.96, enemies: [.tackleBot, .keeperDrone, .ballLauncher], objects: [.ballCart, .tacticsBoard, .equipmentTrunk], hasBoss: false),
        .init(number: 10, name: "Titan Keeper", subtitle: "Bring down the machine", referenceDuration: 180, spawnInterval: 1.02, enemies: [.dummyDefender, .tackleBot, .keeperDrone, .ballLauncher], objects: [.waterCooler, .equipmentTrunk], hasBoss: true),
        .init(number: 11, world: .moon, worldLevel: 1, name: "First Step", subtitle: "Enter the Lunar League", referenceDuration: 115, spawnInterval: 1.34, enemies: [.regolithRunner], objects: [.roverBattery, .satelliteRelay], concepts: [.lunarCycle], hasBoss: false),
        .init(number: 12, world: .moon, worldLevel: 2, name: "Moon Bounce", subtitle: "Track the lunar hoppers", referenceDuration: 130, spawnInterval: 1.27, enemies: [.regolithRunner, .lunarHopper], objects: [.roverBattery, .regolithBarricade], hasBoss: false),
        .init(number: 13, world: .moon, worldLevel: 3, name: "Orbital Lane", subtitle: "Read the circling drones", referenceDuration: 140, spawnInterval: 1.20, enemies: [.regolithRunner, .lunarHopper, .orbitDrone], objects: [.satelliteRelay, .gravityCell], hasBoss: false),
        .init(number: 14, world: .moon, worldLevel: 4, name: "Eclipse Guard", subtitle: "Break the shadow shield", referenceDuration: 150, spawnInterval: 1.14, enemies: [.lunarHopper, .orbitDrone, .eclipseKeeper], objects: [.roverBattery, .regolithBarricade], hasBoss: false),
        .init(number: 15, world: .moon, worldLevel: 5, name: "Gravity Shift", subtitle: "Survive the debris cycle", referenceDuration: 155, spawnInterval: 1.06, enemies: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper], objects: [.gravityCell, .lunarVault], hasBoss: false),
        .init(number: 16, world: .moon, worldLevel: 6, name: "Dark-Side Fire", subtitle: "Dodge the gravity strikers", referenceDuration: 160, spawnInterval: 1.00, enemies: [.lunarHopper, .orbitDrone, .gravityStriker], objects: [.satelliteRelay, .regolithBarricade], hasBoss: false),
        .init(number: 17, world: .moon, worldLevel: 7, name: "Crater Cross", subtitle: "Hold every drifting lane", referenceDuration: 170, spawnInterval: 0.95, enemies: [.regolithRunner, .eclipseKeeper, .gravityStriker], objects: [.roverBattery, .gravityCell, .regolithBarricade], hasBoss: false),
        .init(number: 18, world: .moon, worldLevel: 8, name: "Orbital Press", subtitle: "The whole league attacks", referenceDuration: 175, spawnInterval: 0.89, enemies: [.regolithRunner, .lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.satelliteRelay, .lunarVault], hasBoss: false),
        .init(number: 19, world: .moon, worldLevel: 9, name: "Lunar Trial", subtitle: "Survive the eclipse elite", referenceDuration: 180, spawnInterval: 0.84, enemies: [.orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.gravityCell, .regolithBarricade, .lunarVault], hasBoss: false),
        .init(number: 20, world: .moon, worldLevel: 10, name: "Lunar Warden", subtitle: "Defeat the keeper of the dark side", referenceDuration: 190, spawnInterval: 0.92, enemies: [.lunarHopper, .orbitDrone, .eclipseKeeper, .gravityStriker], objects: [.roverBattery, .lunarVault], hasBoss: true),
        .init(number: 21, world: .mars, worldLevel: 1, name: "Red Arrival", subtitle: "Meet the dust sprites", referenceDuration: 120, spawnInterval: 1.24, enemies: [.dustSprite], objects: [.oxygenPod, .meteorCrate], concepts: [.marsArena], hasBoss: false),
        .init(number: 22, world: .mars, worldLevel: 2, name: "Rover Rush", subtitle: "Crack the colony armor", referenceDuration: 135, spawnInterval: 1.17, enemies: [.dustSprite, .roverRaider], objects: [.oxygenPod, .holoGate], hasBoss: false),
        .init(number: 23, world: .mars, worldLevel: 3, name: "Crater Dance", subtitle: "Track the sideways swarm", referenceDuration: 145, spawnInterval: 1.10, enemies: [.dustSprite, .roverRaider, .craterCrawler], objects: [.meteorCrate, .crystalBarricade], hasBoss: false),
        .init(number: 24, world: .mars, worldLevel: 4, name: "Saucer Shield", subtitle: "Bend shots around the guard", referenceDuration: 155, spawnInterval: 1.04, enemies: [.roverRaider, .craterCrawler, .saucerKeeper], objects: [.oxygenPod, .holoGate], hasBoss: false),
        .init(number: 25, world: .mars, worldLevel: 5, name: "Dust Storm", subtitle: "Hold through the red wave", referenceDuration: 160, spawnInterval: 0.97, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper], objects: [.meteorCrate, .artifactVault], hasBoss: false),
        .init(number: 26, world: .mars, worldLevel: 6, name: "Plasma Rain", subtitle: "Dodge the alien strikers", referenceDuration: 165, spawnInterval: 0.92, enemies: [.roverRaider, .craterCrawler, .plasmaStriker], objects: [.oxygenPod, .crystalBarricade], hasBoss: false),
        .init(number: 27, world: .mars, worldLevel: 7, name: "Crimson Crossfire", subtitle: "Read every volatile lane", referenceDuration: 175, spawnInterval: 0.87, enemies: [.dustSprite, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .crystalBarricade], hasBoss: false),
        .init(number: 28, world: .mars, worldLevel: 8, name: "Alien Press", subtitle: "The whole colony attacks", referenceDuration: 180, spawnInterval: 0.82, enemies: [.dustSprite, .roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: false),
        .init(number: 29, world: .mars, worldLevel: 9, name: "Colony Trial", subtitle: "Survive the frontier elite", referenceDuration: 185, spawnInterval: 0.77, enemies: [.craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.meteorCrate, .holoGate, .artifactVault], hasBoss: false),
        .init(number: 30, world: .mars, worldLevel: 10, name: "Mars Colossus", subtitle: "Defeat the ruler of the crater", referenceDuration: 195, spawnInterval: 0.84, enemies: [.roverRaider, .craterCrawler, .saucerKeeper, .plasmaStriker], objects: [.oxygenPod, .artifactVault], hasBoss: true),
        .init(number: 31, world: .jupiter, worldLevel: 1, name: "Cloudfall", subtitle: "Enter the Storm Citadel", referenceDuration: 130, spawnInterval: 1.16, enemies: [.cloudRunner], objects: [.pressureCell, .cloudCondenser], concepts: [.windShear], hasBoss: false),
        .init(number: 32, world: .jupiter, worldLevel: 2, name: "Pressure Line", subtitle: "Break the cloud armor", referenceDuration: 140, spawnInterval: 1.10, enemies: [.cloudRunner, .pressureBrute], objects: [.pressureCell, .windGate], hasBoss: false),
        .init(number: 33, world: .jupiter, worldLevel: 3, name: "Vortex Run", subtitle: "Track the spiraling skimmers", referenceDuration: 150, spawnInterval: 1.04, enemies: [.cloudRunner, .pressureBrute, .vortexSkimmer], objects: [.lightningMast, .windGate], hasBoss: false),
        .init(number: 34, world: .jupiter, worldLevel: 4, name: "Thunder Guard", subtitle: "Crack the storm shield", referenceDuration: 160, spawnInterval: 0.98, enemies: [.pressureBrute, .vortexSkimmer, .stormKeeper], objects: [.cloudCondenser, .lightningMast], hasBoss: false),
        .init(number: 35, world: .jupiter, worldLevel: 5, name: "Eye Wall", subtitle: "Hold against the first storm wall", referenceDuration: 170, spawnInterval: 0.92, enemies: [.cloudRunner, .pressureBrute, .vortexSkimmer, .stormKeeper], objects: [.pressureCell, .stormVault], hasBoss: false),
        .init(number: 36, world: .jupiter, worldLevel: 6, name: "Jetstream Fire", subtitle: "Dodge the bolt strikers", referenceDuration: 175, spawnInterval: 0.87, enemies: [.pressureBrute, .vortexSkimmer, .boltStriker], objects: [.cloudCondenser, .windGate], hasBoss: false),
        .init(number: 37, world: .jupiter, worldLevel: 7, name: "Great Red Cross", subtitle: "Read every changing current", referenceDuration: 180, spawnInterval: 0.82, enemies: [.cloudRunner, .stormKeeper, .boltStriker], objects: [.pressureCell, .lightningMast, .windGate], hasBoss: false),
        .init(number: 38, world: .jupiter, worldLevel: 8, name: "Storm Citadel", subtitle: "Survive the shifting gale", referenceDuration: 190, spawnInterval: 0.77, enemies: [.cloudRunner, .pressureBrute, .vortexSkimmer, .stormKeeper, .boltStriker], objects: [.cloudCondenser, .stormVault], hasBoss: false),
        .init(number: 39, world: .jupiter, worldLevel: 9, name: "King of Clouds", subtitle: "Master the storm elite", referenceDuration: 195, spawnInterval: 0.73, enemies: [.vortexSkimmer, .stormKeeper, .boltStriker], objects: [.lightningMast, .windGate, .stormVault], hasBoss: false),
        .init(number: 40, world: .jupiter, worldLevel: 10, name: "Tempest Regent", subtitle: "Defeat the ruler of the storm", referenceDuration: 205, spawnInterval: 0.80, enemies: [.pressureBrute, .vortexSkimmer, .stormKeeper, .boltStriker], objects: [.cloudCondenser, .stormVault], hasBoss: true),
        .init(number: 41, world: .saturn, worldLevel: 1, name: "Ringfall", subtitle: "Enter the Crown of Rings", referenceDuration: 135, spawnInterval: 1.10, enemies: [.ringRunner], objects: [.ringShardCrate, .thermalPod], concepts: [.ringSweep], hasBoss: false),
        .init(number: 42, world: .saturn, worldLevel: 2, name: "Ice Band", subtitle: "Break the ring armor", referenceDuration: 145, spawnInterval: 1.04, enemies: [.ringRunner, .iceMason], objects: [.ringShardCrate, .iceBarricade], hasBoss: false),
        .init(number: 43, world: .saturn, worldLevel: 3, name: "Shepherd Run", subtitle: "Track the circling drones", referenceDuration: 155, spawnInterval: 0.98, enemies: [.ringRunner, .iceMason, .shepherdDrone], objects: [.shepherdBeacon, .iceBarricade], hasBoss: false),
        .init(number: 44, world: .saturn, worldLevel: 4, name: "Halo Guard", subtitle: "Split the orbital shield", referenceDuration: 165, spawnInterval: 0.92, enemies: [.iceMason, .shepherdDrone, .haloKeeper], objects: [.thermalPod, .shepherdBeacon], hasBoss: false),
        .init(number: 45, world: .saturn, worldLevel: 5, name: "Cassini Gap", subtitle: "Find the opening", referenceDuration: 175, spawnInterval: 0.86, enemies: [.ringRunner, .iceMason, .shepherdDrone, .haloKeeper], objects: [.ringShardCrate, .crownVault], hasBoss: false),
        .init(number: 46, world: .saturn, worldLevel: 6, name: "Shard Volley", subtitle: "Dodge the ring strikers", referenceDuration: 180, spawnInterval: 0.81, enemies: [.iceMason, .shepherdDrone, .shardStriker], objects: [.thermalPod, .iceBarricade], hasBoss: false),
        .init(number: 47, world: .saturn, worldLevel: 7, name: "Ring Cross", subtitle: "Thread the moving bands", referenceDuration: 185, spawnInterval: 0.76, enemies: [.ringRunner, .haloKeeper, .shardStriker], objects: [.ringShardCrate, .shepherdBeacon, .iceBarricade], hasBoss: false),
        .init(number: 48, world: .saturn, worldLevel: 8, name: "Seven Bands", subtitle: "The full crown closes in", referenceDuration: 195, spawnInterval: 0.71, enemies: [.ringRunner, .iceMason, .shepherdDrone, .haloKeeper, .shardStriker], objects: [.thermalPod, .crownVault], hasBoss: false),
        .init(number: 49, world: .saturn, worldLevel: 9, name: "Crown Trial", subtitle: "Master the ring elite", referenceDuration: 200, spawnInterval: 0.68, enemies: [.shepherdDrone, .haloKeeper, .shardStriker], objects: [.shepherdBeacon, .iceBarricade, .crownVault], hasBoss: false),
        .init(number: 50, world: .saturn, worldLevel: 10, name: "Crown Sovereign", subtitle: "Break the ruler of the rings", referenceDuration: 210, spawnInterval: 0.75, enemies: [.iceMason, .shepherdDrone, .haloKeeper, .shardStriker], objects: [.thermalPod, .crownVault], hasBoss: true),
        .init(number: 51, world: .uranus, worldLevel: 1, name: "Sideways Arrival", subtitle: "Enter the Tilted Frontier", referenceDuration: 140, spawnInterval: 1.04, enemies: [.frostSprinter], objects: [.magneticCoil, .cryoCanister], concepts: [.cryoDrift], hasBoss: false),
        .init(number: 52, world: .uranus, worldLevel: 2, name: "Frost Drift", subtitle: "Brake across the ice", referenceDuration: 150, spawnInterval: 0.98, enemies: [.frostSprinter, .tiltBrute], objects: [.magneticCoil, .frostBarricade], hasBoss: false),
        .init(number: 53, world: .uranus, worldLevel: 3, name: "Aurora Switch", subtitle: "Track the polar drifters", referenceDuration: 160, spawnInterval: 0.92, enemies: [.frostSprinter, .tiltBrute, .auroraDrifter], objects: [.auroraRelay, .frostBarricade], hasBoss: false),
        .init(number: 54, world: .uranus, worldLevel: 4, name: "Polar Guard", subtitle: "Crack the frozen keeper", referenceDuration: 170, spawnInterval: 0.86, enemies: [.tiltBrute, .auroraDrifter, .polarKeeper], objects: [.cryoCanister, .auroraRelay], hasBoss: false),
        .init(number: 55, world: .uranus, worldLevel: 5, name: "Axial Break", subtitle: "Hold the diagonal line", referenceDuration: 180, spawnInterval: 0.80, enemies: [.frostSprinter, .tiltBrute, .auroraDrifter, .polarKeeper], objects: [.magneticCoil, .polarVault], hasBoss: false),
        .init(number: 56, world: .uranus, worldLevel: 6, name: "Magnet Fire", subtitle: "Dodge the polar strikers", referenceDuration: 185, spawnInterval: 0.75, enemies: [.tiltBrute, .auroraDrifter, .magnetStriker], objects: [.cryoCanister, .frostBarricade], hasBoss: false),
        .init(number: 57, world: .uranus, worldLevel: 7, name: "Tilted Cross", subtitle: "Read every frozen lane", referenceDuration: 190, spawnInterval: 0.70, enemies: [.frostSprinter, .polarKeeper, .magnetStriker], objects: [.magneticCoil, .auroraRelay, .frostBarricade], hasBoss: false),
        .init(number: 58, world: .uranus, worldLevel: 8, name: "Deep Freeze", subtitle: "The whole frontier drifts", referenceDuration: 200, spawnInterval: 0.66, enemies: [.frostSprinter, .tiltBrute, .auroraDrifter, .polarKeeper, .magnetStriker], objects: [.cryoCanister, .polarVault], hasBoss: false),
        .init(number: 59, world: .uranus, worldLevel: 9, name: "Pole Trial", subtitle: "Master the axial elite", referenceDuration: 205, spawnInterval: 0.63, enemies: [.auroraDrifter, .polarKeeper, .magnetStriker], objects: [.auroraRelay, .frostBarricade, .polarVault], hasBoss: false),
        .init(number: 60, world: .uranus, worldLevel: 10, name: "Axis Prime", subtitle: "Defeat the master of the poles", referenceDuration: 215, spawnInterval: 0.70, enemies: [.tiltBrute, .auroraDrifter, .polarKeeper, .magnetStriker], objects: [.cryoCanister, .polarVault], hasBoss: true),
        .init(number: 61, world: .neptune, worldLevel: 1, name: "Blue Descent", subtitle: "Enter the Tempest Deep", referenceDuration: 145, spawnInterval: 0.98, enemies: [.mistRunner], objects: [.stormBattery, .oxygenBell], concepts: [.pressureTide], hasBoss: false),
        .init(number: 62, world: .neptune, worldLevel: 2, name: "Pressure Lane", subtitle: "Break the current armor", referenceDuration: 155, spawnInterval: 0.92, enemies: [.mistRunner, .currentBrute], objects: [.stormBattery, .currentGate], hasBoss: false),
        .init(number: 63, world: .neptune, worldLevel: 3, name: "Dark Current", subtitle: "Track the squall rays", referenceDuration: 165, spawnInterval: 0.86, enemies: [.mistRunner, .currentBrute, .squallRay], objects: [.coralBarricade, .currentGate], hasBoss: false),
        .init(number: 64, world: .neptune, worldLevel: 4, name: "Trident Guard", subtitle: "Break the deep keeper", referenceDuration: 175, spawnInterval: 0.80, enemies: [.currentBrute, .squallRay, .tridentKeeper], objects: [.oxygenBell, .coralBarricade], hasBoss: false),
        .init(number: 65, world: .neptune, worldLevel: 5, name: "Rogue Tide", subtitle: "Hold the narrowing channel", referenceDuration: 185, spawnInterval: 0.74, enemies: [.mistRunner, .currentBrute, .squallRay, .tridentKeeper], objects: [.stormBattery, .trenchVault], hasBoss: false),
        .init(number: 66, world: .neptune, worldLevel: 6, name: "Stormfire", subtitle: "Dodge the pressure strikers", referenceDuration: 190, spawnInterval: 0.69, enemies: [.currentBrute, .squallRay, .pressureStriker], objects: [.oxygenBell, .currentGate], hasBoss: false),
        .init(number: 67, world: .neptune, worldLevel: 7, name: "Crushing Deep", subtitle: "Read the moving refuge", referenceDuration: 195, spawnInterval: 0.65, enemies: [.mistRunner, .tridentKeeper, .pressureStriker], objects: [.stormBattery, .coralBarricade, .currentGate], hasBoss: false),
        .init(number: 68, world: .neptune, worldLevel: 8, name: "Great Dark Spot", subtitle: "The full tempest closes in", referenceDuration: 205, spawnInterval: 0.61, enemies: [.mistRunner, .currentBrute, .squallRay, .tridentKeeper, .pressureStriker], objects: [.oxygenBell, .trenchVault], hasBoss: false),
        .init(number: 69, world: .neptune, worldLevel: 9, name: "Last Horizon", subtitle: "Master the deep elite", referenceDuration: 210, spawnInterval: 0.58, enemies: [.squallRay, .tridentKeeper, .pressureStriker], objects: [.coralBarricade, .currentGate, .trenchVault], hasBoss: false),
        .init(number: 70, world: .neptune, worldLevel: 10, name: "Abyssal Monarch", subtitle: "Defeat the ruler of the deep", referenceDuration: 220, spawnInterval: 0.65, enemies: [.currentBrute, .squallRay, .tridentKeeper, .pressureStriker], objects: [.oxygenBell, .trenchVault], hasBoss: true)
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
        case .moon, .mars, .jupiter, .saturn, .uranus, .neptune:
            progress.highestUnlockedLevel >= GameContent.world(world).levelRange.lowerBound
        }
    }
}

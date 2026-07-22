import Foundation

protocol ProgressStore: Sendable {
    func load() throws -> PlayerProgress
    func save(_ progress: PlayerProgress) throws
    func reset() throws
}

struct FileProgressStore: ProgressStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appending(path: "GoalRush/goal-rush-save-v1.json")
        }
    }

    func load() throws -> PlayerProgress {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .newPlayer }
        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder().decode(PlayerProgress.self, from: data)
        } catch {
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return .newPlayer
        }
    }

    func save(_ progress: PlayerProgress) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(progress)
        try data.write(to: fileURL, options: .atomic)
    }

    func reset() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

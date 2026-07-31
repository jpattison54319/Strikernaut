import Foundation

actor RunCheckpointStore {
    private let directoryURL: URL

    init(
        directoryURL: URL? = nil,
        resetExistingStorage: Bool = false
    ) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.directoryURL = base.appending(path: "GoalRush/CurrentRuns")
        }
        if resetExistingStorage,
           FileManager.default.fileExists(atPath: self.directoryURL.path) {
            try? FileManager.default.removeItem(at: self.directoryURL)
        }
    }

    func load(
        for mode: RunMode,
        campaignCycle expectedCampaignCycle: Int? = nil
    ) -> RunCheckpoint? {
        let fileURL = fileURL(for: mode)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let checkpoint = try JSONDecoder().decode(RunCheckpoint.self, from: data)
            guard checkpoint.schemaVersion == RunCheckpoint.currentSchemaVersion,
                  checkpoint.mode == mode,
                  checkpoint.simulation.mode == mode,
                  expectedCampaignCycle.map({ checkpoint.campaignCycle == $0 }) != false,
                  checkpoint.wave > 1 else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return checkpoint
        } catch {
            let backup = fileURL
                .deletingPathExtension()
                .appendingPathExtension(
                    "corrupt-\(Int(Date.now.timeIntervalSince1970)).json"
                )
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return nil
        }
    }

    func save(_ checkpoint: RunCheckpoint) throws {
        guard !Task.isCancelled,
              checkpoint.schemaVersion == RunCheckpoint.currentSchemaVersion,
              checkpoint.wave > 1 else {
            return
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = fileURL(for: checkpoint.mode)
        if let existing = load(for: checkpoint.mode),
           existing.runID == checkpoint.runID,
           existing.revision > checkpoint.revision {
            return
        }
        guard !Task.isCancelled else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(checkpoint)
        try data.write(to: fileURL, options: .atomic)
    }

    func delete(for mode: RunMode) throws {
        let fileURL = fileURL(for: mode)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    func invalidateAfterDeath(for mode: RunMode) throws {
        try delete(for: mode)
    }

    func reset() throws {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: directoryURL)
    }

    private func fileURL(for mode: RunMode) -> URL {
        directoryURL.appending(path: "\(mode.checkpointFileStem).json")
    }
}

private extension RunMode {
    nonisolated var checkpointFileStem: String {
        switch self {
        case .campaign(let level):
            "campaign-level-\(level)"
        case .endless:
            "endless"
        }
    }
}

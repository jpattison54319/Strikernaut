import AVFoundation
import Foundation

/// Keeps short gameplay effects decoded and connected to the audio graph.
/// Reusing player nodes avoids AVAudioPlayer/AudioQueue setup work during
/// ricochet, meteor, and shockwave event bursts.
@MainActor
final class BufferedEffectPlayer {
    struct PoolSpec {
        let name: String
        let resources: [String]
        let voiceCount: Int
    }

    private struct Voice {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private var pools: [String: [Voice]] = [:]
    private var indices: [String: Int] = [:]
    private var isPrepared = false

    func prepare(specs: [PoolSpec]) async {
        guard !isPrepared else { return }

        var decodedBuffers: [String: AVAudioPCMBuffer] = [:]
        for resource in Set(specs.flatMap(\.resources)) where !Task.isCancelled {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                  )
            else { continue }

            do {
                try file.read(into: buffer)
                decodedBuffers[resource] = buffer
            } catch {
                continue
            }
            await Task.yield()
        }

        for spec in specs where !Task.isCancelled {
            pools[spec.name] = (0..<spec.voiceCount).compactMap { index in
                let resource = spec.resources[index % spec.resources.count]
                guard let buffer = decodedBuffers[resource] else { return nil }
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
                return Voice(node: node, buffer: buffer)
            }
            await Task.yield()
        }

        guard !Task.isCancelled else {
            stop()
            return
        }

        engine.prepare()
        do {
            try engine.start()
            isPrepared = true
        } catch {
            stop()
        }
    }

    func play(_ name: String, volume: Float) {
        guard isPrepared, let voices = pools[name], !voices.isEmpty else { return }
        let index = indices[name, default: 0] % voices.count
        let voice = voices[index]
        voice.node.volume = volume
        voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts)
        voice.node.play()
        indices[name] = index + 1
    }

    func stop() {
        pools.values.flatMap { $0 }.forEach { $0.node.stop() }
        engine.stop()
        isPrepared = false
    }
}

#!/usr/bin/swift
import Foundation

let sampleRate = 44_100

func envelope(_ t: Double, duration: Double, attack: Double = 0.008, release: Double = 0.22) -> Double {
    min(1, t / attack) * min(1, max(0, (duration - t) / release))
}

func tone(duration: Double, generator: (Double) -> Double) -> [Int16] {
    let count = Int(duration * Double(sampleRate))
    return (0..<count).map { index in
        let t = Double(index) / Double(sampleRate)
        return Int16(max(-1, min(1, generator(t))) * Double(Int16.max) * 0.72)
    }
}

func writeWAV(_ samples: [Int16], name: String) throws {
    var data = Data()
    func append(_ value: UInt32) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
    func append16(_ value: UInt16) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
    data.append("RIFF".data(using: .ascii)!)
    append(UInt32(36 + samples.count * 2))
    data.append("WAVEfmt ".data(using: .ascii)!)
    append(16); append16(1); append16(1); append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append16(2); append16(16)
    data.append("data".data(using: .ascii)!)
    append(UInt32(samples.count * 2))
    for sample in samples { var value = sample.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "GoalRush/Resources/Audio/\(name).wav")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: output, options: .atomic)
}

func note(_ frequency: Double, t: Double, start: Double, length: Double) -> Double {
    guard t >= start, t < start + length else { return 0 }
    let local = t - start
    return sin(local * frequency * .pi * 2) * envelope(local, duration: length, attack: 0.015, release: 0.08)
}

let kick = tone(duration: 0.22) { t in
    let frequency = 150 - 95 * (t / 0.22)
    return sin(t * frequency * .pi * 2) * envelope(t, duration: 0.22, release: 0.18)
}
let impact = tone(duration: 0.16) { t in
    let noise = sin(t * 6_913) * sin(t * 2_717)
    return (sin(t * 90 * .pi * 2) * 0.6 + noise * 0.35) * envelope(t, duration: 0.16, release: 0.13)
}
let coin = tone(duration: 0.28) { t in
    (sin(t * 880 * .pi * 2) + sin(t * 1_320 * .pi * 2) * 0.45) * envelope(t, duration: 0.28, release: 0.18) * 0.65
}
let heal = tone(duration: 0.45) { t in
    let frequencies = [523.25, 659.25, 783.99]
    return frequencies.enumerated().reduce(0) { result, pair in result + note(pair.element, t: t, start: Double(pair.offset) * 0.10, length: 0.24) * 0.42 }
}
let confirm = tone(duration: 0.18) { t in (sin(t * 620 * .pi * 2) + sin(t * 930 * .pi * 2) * 0.35) * envelope(t, duration: 0.18, release: 0.10) * 0.55 }
let victory = tone(duration: 1.5) { t in
    let notes = [523.25, 659.25, 783.99, 1046.5]
    return notes.enumerated().reduce(0) { $0 + note($1.element, t: t, start: Double($1.offset) * 0.24, length: 0.62) * 0.32 }
}
let defeat = tone(duration: 1.2) { t in
    let notes = [392.0, 349.23, 293.66]
    return notes.enumerated().reduce(0) { $0 + note($1.element, t: t, start: Double($1.offset) * 0.28, length: 0.55) * 0.32 }
}
let boss = tone(duration: 0.9) { t in (sin(t * 82.4 * .pi * 2) + sin(t * 123.5 * .pi * 2) * 0.4) * envelope(t, duration: 0.9, release: 0.45) * 0.65 }

func music(layer: Int) -> [Int16] {
    tone(duration: 8) { t in
        let step = Int(t / 0.5) % 16
        let bassNotes = [110.0, 110.0, 146.83, 164.81]
        let bass = note(bassNotes[(step / 4) % 4], t: t, start: floor(t / 0.5) * 0.5, length: 0.42) * 0.26
        if layer == 0 { return bass }
        let pulse = sin(t * (layer == 1 ? 220 : 330) * .pi * 2) * envelope(t.truncatingRemainder(dividingBy: layer == 1 ? 0.25 : 0.125), duration: layer == 1 ? 0.25 : 0.125, release: 0.06) * (layer == 1 ? 0.13 : 0.09)
        return bass * 0.35 + pulse
    }
}

try writeWAV(kick, name: "kick")
try writeWAV(impact, name: "impact")
try writeWAV(coin, name: "coin")
try writeWAV(heal, name: "heal")
try writeWAV(confirm, name: "confirm")
try writeWAV(victory, name: "victory")
try writeWAV(defeat, name: "defeat")
try writeWAV(boss, name: "boss-phase")
try writeWAV(music(layer: 0), name: "music-calm")
try writeWAV(music(layer: 1), name: "music-pressure")
try writeWAV(music(layer: 2), name: "music-boss")
print("Baked Goal Rush audio assets")

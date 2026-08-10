import Foundation

enum GameNumberFormatter {
    nonisolated static func compact(_ value: Int) -> String {
        let units: [(divisor: UInt, suffix: String)] = [
            (1_000, "K"),
            (1_000_000, "M"),
            (1_000_000_000, "B"),
            (1_000_000_000_000, "T"),
            (1_000_000_000_000_000, "Qa"),
            (1_000_000_000_000_000_000, "Qi"),
        ]
        let magnitude = value.magnitude

        guard magnitude >= units[0].divisor else {
            return value.formatted()
        }

        var unitIndex = units.lastIndex {
            magnitude >= $0.divisor
        } ?? 0

        while true {
            let unit = units[unitIndex]
            var whole = magnitude / unit.divisor
            let remainder = magnitude % unit.divisor
            var tenth: UInt = 0

            if whole < 100 {
                let tenthDivisor = unit.divisor / 10
                tenth = (remainder + unit.divisor / 20) / tenthDivisor
                if tenth == 10 {
                    whole += 1
                    tenth = 0
                }
            } else if remainder >= unit.divisor / 2 {
                whole += 1
            }

            if whole >= 1_000, unitIndex < units.count - 1 {
                unitIndex += 1
                continue
            }

            let sign = value < 0 ? "-" : ""
            if tenth > 0, whole < 100 {
                return "\(sign)\(whole).\(tenth)\(unit.suffix)"
            }
            return "\(sign)\(whole)\(unit.suffix)"
        }
    }

    nonisolated static func exact(_ value: Int) -> String {
        value.formatted()
    }
}

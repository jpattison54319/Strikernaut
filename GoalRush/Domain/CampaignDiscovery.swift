import Foundation

struct CampaignDiscovery: Identifiable, Equatable, Sendable {
    enum Subject: Equatable, Sendable {
        case enemy(EnemyKind)
        case fieldObject(FieldObjectKind)
        case concept(CampaignConcept)
    }

    let subject: Subject
    let title: String
    let detail: String
    let systemImage: String

    var id: String {
        switch subject {
        case .enemy(let enemy): "enemy-\(enemy.rawValue)"
        case .fieldObject(let object): "object-\(object.rawValue)"
        case .concept(let concept): "concept-\(concept.rawValue)"
        }
    }

    var targetKind: TargetState.Kind? {
        switch subject {
        case .enemy(let enemy): .enemy(enemy)
        case .fieldObject(let object): .fieldObject(object)
        case .concept: nil
        }
    }
}

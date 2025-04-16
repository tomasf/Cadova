import Foundation
import Manifold3D

enum BooleanOperationType: String, Hashable, Sendable, Codable {
    case union
    case difference
    case intersection

    var manifoldRepresentation: Manifold3D.BooleanOperation {
        switch self {
        case .union: .union
        case .difference: .difference
        case .intersection: .intersection
        }
    }
}


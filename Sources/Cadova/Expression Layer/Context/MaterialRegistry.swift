import Foundation
import Manifold3D

actor MaterialRegistry {
    private var table: [Manifold.OriginalID: Material] = [:]

    func register(_ material: Material, for id: Manifold.OriginalID) {
        table[id] = material
    }

    func material(for id: Manifold.OriginalID) -> Material? {
        table[id]
    }
}

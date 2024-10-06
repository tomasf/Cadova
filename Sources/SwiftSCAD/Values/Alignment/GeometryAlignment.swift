
import Foundation

public struct GeometryAlignment2D: Equatable, Sendable {
    internal let x: AxisAlignment?
    internal let y: AxisAlignment?

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) {
        self.x = x
        self.y = y
    }

    internal init(merging alignments: [GeometryAlignment2D]) {
        x = alignments.compactMap(\.x).last
        y = alignments.compactMap(\.y).last
    }

    internal var factors: Vector2D {
        .init(x?.factor ?? 0, y?.factor ?? 0)
    }

    internal func offset(for boundingBox: BoundingBox2D) -> Vector2D {
        -boundingBox.minimum - factors * boundingBox.size
    }
}

public struct GeometryAlignment3D: Equatable, Sendable {
    internal let x: AxisAlignment?
    internal let y: AxisAlignment?
    internal let z: AxisAlignment?

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) {
        self.x = x
        self.y = y
        self.z = z
    }

    internal init(merging alignments: [GeometryAlignment3D]) {
        x = alignments.compactMap(\.x).last
        y = alignments.compactMap(\.y).last
        z = alignments.compactMap(\.z).last
    }

    internal var factors: Vector3D {
        .init(x?.factor ?? 0, y?.factor ?? 0, z?.factor ?? 0)
    }

    internal func offset(for boundingBox: BoundingBox3D) -> Vector3D {
        -boundingBox.minimum - factors * boundingBox.size
    }
}

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}

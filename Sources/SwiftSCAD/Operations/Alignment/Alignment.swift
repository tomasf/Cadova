import Foundation

public enum AxisAlignment: Equatable {
    case min
    case mid
    case max

    internal var factor: Double {
        switch self {
        case .min: 0.0
        case .mid: 0.5
        case .max: 1.0
        }
    }
}

public struct GeometryAlignment2D: Equatable {
    internal let x: AxisAlignment?
    internal let y: AxisAlignment?

    internal init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) {
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
}

public struct GeometryAlignment3D: Equatable {
    internal let x: AxisAlignment?
    internal let y: AxisAlignment?
    internal let z: AxisAlignment?

    internal init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) {
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
}

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}

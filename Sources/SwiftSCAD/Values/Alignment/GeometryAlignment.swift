
import Foundation

public struct GeometryAlignment2D: Equatable, Sendable {
    internal let x: AxisAlignment?
    internal let y: AxisAlignment?

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) {
        self.x = x
        self.y = y
    }

    fileprivate init(merging alignments: [GeometryAlignment2D]) {
        x = alignments.compactMap(\.x).last
        y = alignments.compactMap(\.y).last
    }

    internal var factors: Vector2D {
        .init(x?.factor ?? 0, y?.factor ?? 0)
    }

    internal func defaultingToOrigin() -> Self {
        .init(
            x: x ?? .min,
            y: y ?? .min
        )
    }

    internal var hasEffect: Bool {
        x != nil || y != nil
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

    fileprivate init(merging alignments: [GeometryAlignment3D]) {
        x = alignments.compactMap(\.x).last
        y = alignments.compactMap(\.y).last
        z = alignments.compactMap(\.z).last
    }

    internal var factors: Vector3D {
        .init(x?.factor ?? 0, y?.factor ?? 0, z?.factor ?? 0)
    }

    internal func defaultingToOrigin() -> Self {
        .init(
            x: x ?? .min,
            y: y ?? .min,
            z: z ?? .min
        )
    }

    internal var hasEffect: Bool {
        x != nil || y != nil || z != nil
    }
}

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}

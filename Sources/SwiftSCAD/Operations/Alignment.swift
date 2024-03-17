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

public extension GeometryAlignment2D {
    static let none = Self()
    static let center = Self(x: .mid, y: .mid)
    
    static let minX = Self(x: .min)
    static let centerX = Self(x: .mid)
    static let maxX = Self(x: .max)

    static let left = minX
    static let right = maxX

    static let minY = Self(y: .min)
    static let centerY = Self(y: .mid)
    static let maxY = Self(y: .max)

    static let top = maxY
    static let bottom = minY
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

public extension GeometryAlignment3D {
    static let none = Self()
    static let center = Self(x: .mid, y: .mid, z: .mid)
    static let centerXY = Self(x: .mid, y: .mid)

    static let minX = Self(x: .min)
    static let centerX = Self(x: .mid)
    static let maxX = Self(x: .max)

    static let left = minX
    static let right = maxX

    static let minY = Self(y: .min)
    static let centerY = Self(y: .mid)
    static let maxY = Self(y: .max)

    static let back = maxY
    static let front = minY

    static let minZ = Self(z: .min)
    static let centerZ = Self(z: .mid)
    static let maxZ = Self(z: .max)

    static let top = maxZ
    static let bottom = minZ
}

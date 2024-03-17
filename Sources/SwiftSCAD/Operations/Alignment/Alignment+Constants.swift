import Foundation

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

import Foundation

// Stable digest conformances for the value types that can appear inside a geometry node.
//
// Every conformance here folds in a fixed textual discriminant before its payload, so that two
// different cases can't produce the same byte stream, and so that adding a case later doesn't
// renumber the existing ones.

internal extension StableHasher {
    /// Feeds a case discriminant. Spelled out as text rather than an ordinal so the digest survives
    /// reordering or insertion of enum cases.
    mutating func combine(case name: StaticString) {
        // Walks the literal's bytes directly rather than through a `Sequence`, which an
        // unoptimized build would turn into an iterator call per byte. Every case name here is
        // several characters long, so the literal always has a pointer representation. A literal
        // holding a single Unicode scalar would not, and `utf8CodeUnitCount` traps on those, so
        // the requirement is stated here rather than left to a trap inside the stdlib.
        precondition(name.hasPointerRepresentation, "A case name must be more than one character")
        let count = name.utf8CodeUnitCount
        combine(word: UInt64(count))
        let bytes = name.utf8Start
        var index = 0
        while index < count {
            combine(byte: bytes[index])
            index += 1
        }
    }

    /// Feeds a vector, element by element, at a fixed width for its dimensionality.
    @inline(__always)
    mutating func combine(_ vector: Vector2D) {
        combine(word: 2)
        combine(vector.x)
        combine(vector.y)
    }

    @inline(__always)
    mutating func combine(_ vector: Vector3D) {
        combine(word: 3)
        combine(vector.x)
        combine(vector.y)
        combine(vector.z)
    }

    /// Feeds an affine transform in row-major order.
    ///
    /// A transform is the heaviest payload a node carries — sixteen doubles for a `Transform3D` —
    /// and reaching them through the `Transform` protocol costs a witness call per element that an
    /// unoptimized build can't see through. The two concrete types are picked out once per
    /// transform instead.
    mutating func combine<T: Transform>(transform: T) {
        let (rows, columns) = T.size
        combine(word: UInt64(rows))
        combine(word: UInt64(columns))

        if let transform = transform as? Transform3D {
            combine(transform)
        } else if let transform = transform as? Transform2D {
            combine(transform)
        } else {
            for row in 0..<rows {
                for column in 0..<columns {
                    combine(transform[row, column])
                }
            }
        }
    }

    @inline(__always)
    mutating func combine(_ transform: Transform3D) {
        for row in 0..<4 {
            for column in 0..<4 {
                combine(transform[row, column])
            }
        }
    }

    @inline(__always)
    mutating func combine(_ transform: Transform2D) {
        for row in 0..<3 {
            for column in 0..<3 {
                combine(transform[row, column])
            }
        }
    }
}

extension Vector2D: StableHashable {
    @inline(__always)
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(self)
    }
}

extension Vector3D: StableHashable {
    @inline(__always)
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(self)
    }
}

extension Transform2D: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(transform: self)
    }
}

extension Transform3D: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(transform: self)
    }
}

extension Angle: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(degrees)
    }
}

extension Direction: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        // `D.Vector` is only known to conform to `Vector` here, so this goes through the protocol.
        // Directions are rare in node payloads, unlike the vectors and doubles above.
        hasher.combine(word: UInt64(D.Vector.elementCount))
        for element in unitVector {
            hasher.combine(element)
        }
    }
}

extension Plane: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(offset)
        hasher.combine(normal)
    }
}

extension Color: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
        hasher.combine(alpha)
    }
}

extension Material.PhysicalProperties: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(metallicness)
        hasher.combine(roughness)
    }
}

extension Material: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(name)
        hasher.combine(baseColor)
        hasher.combine(physicalProperties)
    }
}

extension LineJoinStyle: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .round: hasher.combine(case: "round")
        case .miter: hasher.combine(case: "miter")
        case .bevel: hasher.combine(case: "bevel")
        case .square: hasher.combine(case: "square")
        }
    }
}

extension FillRule: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .nonZero: hasher.combine(case: "nonZero")
        case .evenOdd: hasher.combine(case: "evenOdd")
        case .positive: hasher.combine(case: "positive")
        case .negative: hasher.combine(case: "negative")
        }
    }
}

extension BooleanOperationType: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension SimplePolygon: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(vertices)
    }
}

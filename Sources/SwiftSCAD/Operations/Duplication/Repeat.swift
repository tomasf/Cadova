import Foundation

extension Geometry3D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func repeated(along axis: Axis3D, in range: Range<Double>, step: Double) -> Geometry3D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func repeated(along axis: Axis3D, in range: Range<Double>, count: Int) -> Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector3D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within
    ///   - step: The angular distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func repeated(around axis: Axis3D, in range: Range<Angle>, step: Angle) -> Geometry3D {
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(angle: Angle(radians: value), axis: axis)
        }
    }

    /// Repeat the geometry rotated around an axis
    /// - Parameters:
    ///   - axis: The axis to rotate around
    ///   - range: The range of angles to rotate within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func repeated(around axis: Axis3D, in range: Range<Angle>, count: Int) -> Geometry3D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(angle: Angle(radians: value), axis: axis)
        }
    }

    /// Repeat this geometry at specified offsets along an axis
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    ///   - axis: The axis to distribute along
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func distributed(at offsets: [Double], along axis: Axis3D) -> Geometry3D {
        for offset in offsets {
            translated(Vector3D(axis: axis, value: offset))
        }
    }

    /// Repeat this geometry at specified angles around an axis
    /// - Parameters:
    ///   - angles: The angles to use
    ///   - axis: The axis to distribute around
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func distributed(at angles: [Angle], around axis: Axis3D) -> Geometry3D {
        for angle in angles {
            rotated(angle: angle, axis: axis)
        }
    }

    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func distributed(at points: [Vector3D]) -> Geometry3D {
        for offset in points {
            translated(offset)
        }
    }

    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder3D public func distributed(at points: Vector3D...) -> Geometry3D {
        distributed(at: points)
    }
}


extension Geometry2D {
    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - step: The distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func repeated(along axis: Axis2D, in range: Range<Double>, step: Double) -> Geometry2D {
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry along an axis
    /// - Parameters:
    ///   - axis: The axis to repeat along
    ///   - range: The range of offsets to repeat within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func repeated(along axis: Axis2D, in range: Range<Double>, count: Int) -> Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound, to: range.upperBound, by: step) {
            translated(Vector2D(axis: axis, value: value))
        }
    }

    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within
    ///   - step: The angular distance between each copy
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func repeated(in range: Range<Angle>, step: Angle) -> Geometry2D {
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(Angle(radians: value))
        }
    }

    /// Repeat the geometry rotated
    /// - Parameters:
    ///   - range: The range of angles to rotate within
    ///   - count: The number of geometries to generate
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func repeated(in range: Range<Angle>, count: Int) -> Geometry2D {
        let step = (range.upperBound - range.lowerBound) / Double(count)
        for value in stride(from: range.lowerBound.radians, to: range.upperBound.radians, by: step.radians) {
            rotated(Angle(radians: value))
        }
    }

    /// Repeat this geometry at specified offsets along an axis
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    ///   - axis: The axis to distribute along
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func distributed(at offsets: [Double], along axis: Axis2D) -> Geometry2D {
        for offset in offsets {
            translated(Vector2D(axis: axis, value: offset))
        }
    }

    /// Repeat this geometry at specified angles
    /// - Parameters:
    ///   - angles: The angles to use
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func distributed(at angles: [Angle]) -> Geometry2D {
        for angle in angles {
            rotated(angle)
        }
    }

    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func distributed(at offsets: [Vector2D]) -> Geometry2D {
        for offset in offsets {
            translated(offset)
        }
    }

    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated

    @UnionBuilder2D public func distributed(at offsets: Vector2D...) -> Geometry2D {
        distributed(at: offsets)
    }
}


import Foundation

extension Geometry2D {
    /// Repeat this geometry at specified offsets along an axis
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    ///   - axis: The axis to distribute along
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder2D
    public func distributed(at offsets: any Sequence<Double>, along axis: Axis2D) -> any Geometry2D {
        for offset in offsets {
            translated(Vector2D(axis: axis, value: offset))
        }
    }
    
    /// Repeat this geometry at specified angles
    /// - Parameters:
    ///   - angles: The angles to use
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder2D
    public func distributed(at angles: any Sequence<Angle>) -> any Geometry2D {
        for angle in angles {
            rotated(angle)
        }
    }
    
    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder2D
    public func distributed(at offsets: any Sequence<Vector2D>) -> any Geometry2D {
        for offset in offsets {
            translated(offset)
        }
    }
    
    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder2D
    public func distributed(at offsets: Vector2D...) -> any Geometry2D {
        distributed(at: offsets)
    }
}

extension Geometry3D {
    /// Repeat this geometry at specified offsets along an axis
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    ///   - axis: The axis to distribute along
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder3D
    public func distributed(at offsets: any Sequence<Double>, along axis: Axis3D) -> any Geometry3D {
        for offset in offsets {
            translated(Vector3D(axis: axis, value: offset))
        }
    }
    
    /// Repeat this geometry at specified angles around an axis
    /// - Parameters:
    ///   - angles: The angles to use
    ///   - axis: The axis to distribute around
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder3D
    public func distributed(at angles: any Sequence<Angle>, around axis: Axis3D) -> any Geometry3D {
        for angle in angles {
            rotated(angle: angle, axis: axis)
        }
    }
    
    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder3D
    public func distributed(at points: any Sequence<Vector3D>) -> any Geometry3D {
        for offset in points {
            translated(offset)
        }
    }
    
    /// Repeat this geometry at specified offsets
    /// - Parameters:
    ///   - offsets: The translation offsets to use
    /// - Returns: A new geometry with this geometry repeated
    
    @UnionBuilder3D
    public func distributed(at points: Vector3D...) -> any Geometry3D {
        distributed(at: points)
    }
}

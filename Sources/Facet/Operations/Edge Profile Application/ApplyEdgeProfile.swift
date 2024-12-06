import Foundation

internal extension Geometry3D {
    func applyingTopEdgeProfile(profile: EdgeProfile, at z: Double, shape: any Geometry2D, method: EdgeProfile.Method) -> any Geometry3D {
        let subtraction = profile.negativeMask(shape: shape, method: method)
            .translated(z: z)
        return subtracting(subtraction)
    }

    func applyingBottomEdgeProfile(profile: EdgeProfile, at z: Double, shape: any Geometry2D, method: EdgeProfile.Method) -> any Geometry3D {
        let subtraction = profile.negativeMask(shape: shape, method: method)
            .flipped(along: .z)
            .translated(z: z)
        return subtracting(subtraction)
    }
}

public extension Geometry3D {
    /// Applies a specified edge profile to the top edge of a 3D geometry.
    ///
    /// This variant allows optional specification of the Z-coordinate and uses a 2D equivalent of the 3D geometry
    /// as a guide for applying the edge profile. If `z` is not provided, the top of the bounding box is used.
    ///
    /// - Parameters:
    ///   - profile: The `EdgeProfile` to apply, defining the shape of the top edge.
    ///   - z: An optional Z-coordinate where the profile is applied. Defaults to the top bounding box if not provided.
    ///   - method: The method of the profile application, which may adjust how the profile interacts with the geometry.
    ///   - shape: A closure returning a 2D geometry slice that acts as the 2D equivalent for guiding the profile application.
    /// - Returns: A new `Geometry3D` with the applied top edge profile.
    func applyingTopEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method, @GeometryBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
        let slice = shape()
        if let z {
            return applyingTopEdgeProfile(profile: profile, at: z, shape: slice, method: method)
        } else {
            return measuringBounds { _, box in
                applyingTopEdgeProfile(profile: profile, at: box.requireNonNil().maximum.z, shape: slice, method: method)
            }
        }
    }

    /// Applies a specified edge profile to the top edge of a 3D geometry using a projected 2D equivalent.
    ///
    /// This variant creates a 2D slice by projecting the geometry at a given Z-coordinate to use as the profile shape.
    /// If `z` is not provided, the top of the bounding box is used.
    ///
    /// - Parameters:
    ///   - profile: The `EdgeProfile` to apply, defining the shape of the top edge.
    ///   - z: An optional Z-coordinate where the profile is applied. Defaults to the top bounding box if not provided.
    ///   - method: The method of the profile application.
    /// - Returns: A new `Geometry3D` with the applied top edge profile.
    func applyingTopEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method) -> any Geometry3D {
        if let z {
            applyingTopEdgeProfile(profile, at: z, method: method) {
                projection(slicingAtZ: z - 0.01)
            }
        } else {
            measuringBounds { _, box in
                let box = box.requireNonNil()
                applyingTopEdgeProfile(profile, at: box.maximum.z, method: method) {
                    projection(slicingAtZ: box.maximum.z - 0.01)
                }
            }
        }
    }

    /// Applies a specified edge profile to the bottom edge of a 3D geometry.
    ///
    /// This variant allows optional specification of the Z-coordinate and uses a 2D equivalent of the 3D geometry
    /// as a guide for applying the edge profile. If `z` is not provided, the bottom of the bounding box is used.
    ///
    /// - Parameters:
    ///   - profile: The `EdgeProfile` to apply, defining the shape of the bottom edge.
    ///   - z: An optional Z-coordinate where the profile is applied. Defaults to the bottom bounding box if not provided.
    ///   - method: The method of the profile application.
    ///   - shape: A closure returning a 2D geometry slice that acts as the 2D equivalent for guiding the profile application.
    /// - Returns: A new `Geometry3D` with the applied bottom edge profile.
    func applyingBottomEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method, @GeometryBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
        let slice = shape()
        if let z {
            return applyingBottomEdgeProfile(profile: profile, at: z, shape: slice, method: method)
        } else {
            return measuringBounds { _, box in
                let box = box.requireNonNil()
                return applyingBottomEdgeProfile(profile: profile, at: box.minimum.z, shape: slice, method: method)
            }
        }
    }

    /// Applies a specified edge profile to the bottom edge of a 3D geometry using a projected 2D equivalent.
    ///
    /// This variant creates a 2D slice by projecting the geometry at a given Z-coordinate to use as the profile shape.
    /// If `z` is not provided, the bottom of the bounding box is used.
    ///
    /// - Parameters:
    ///   - profile: The `EdgeProfile` to apply, defining the shape of the bottom edge.
    ///   - z: An optional Z-coordinate where the profile is applied. Defaults to the bottom bounding box if not provided.
    ///   - method: The method of the profile application.
    /// - Returns: A new `Geometry3D` with the applied bottom edge profile.
    func applyingBottomEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method) -> any Geometry3D {
        if let z {
            applyingBottomEdgeProfile(profile, at: z, method: method) {
                projection(slicingAtZ: z + 0.01)
            }
        } else {
            measuringBounds { _, box in
                let box = box.requireNonNil()
                applyingBottomEdgeProfile(profile, at: box.minimum.z, method: method) {
                    projection(slicingAtZ: box.minimum.z + 0.01)
                }
            }
        }
    }
}

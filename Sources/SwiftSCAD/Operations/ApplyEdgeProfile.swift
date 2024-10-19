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
    func applyingTopEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method, @UnionBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
        let slice = shape()
        if let z {
            return applyingTopEdgeProfile(profile: profile, at: z, shape: slice, method: method)
        } else {
            return measuringBounds { _, box in
                applyingTopEdgeProfile(profile: profile, at: box.requireNonNil().maximum.z, shape: slice, method: method)
            }
        }
    }

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

    func applyingBottomEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: EdgeProfile.Method, @UnionBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
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

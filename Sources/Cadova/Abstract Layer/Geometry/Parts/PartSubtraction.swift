import Foundation

public extension Geometry3D {
    /// Subtracts the specified parts from this geometry to prevent overlap with those parts.
    ///
    /// This is useful when generating multi-part 3MF models where the "main" printable geometry should not
    /// physically overlap with detached parts. Some slicers rely on non-overlapping meshes to correctly
    /// identify separate objects.
    ///
    /// The method subtracts the specified parts from the receiver. It does not modify or remove the parts themselves.
    ///
    /// - Parameter parts: The parts to subtract from this geometry.
    /// - Returns: A new geometry with the specified parts subtracted from the receiver.
    ///
    func subtractingParts(_ parts: [Part]) -> any Geometry3D {
        readingParts(matching: parts) { base, matchedParts in
            base.subtracting {
                matchedParts.values
            }
        }
    }

}

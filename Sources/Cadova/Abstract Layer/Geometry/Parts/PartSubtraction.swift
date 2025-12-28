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

    /// Subtracts one or more named parts from this geometry to prevent overlap with those parts.
    ///
    /// This is useful when generating multi-part 3MF models where the "main" printable geometry should not
    /// physically overlap with detached parts (e.g. parts created with `.inPart(named:)`). Some slicers rely
    /// on non-overlapping meshes to correctly identify separate objects.
    ///
    /// The method gathers parts by semantic, optionally filters by name, and subtracts those parts from the receiver.
    /// It does not modify or remove the parts themselves.
    ///
    /// - Parameters:
    ///   - names: An optional set of part names to subtract. If `nil`, all parts matching `semantic` are subtracted.
    ///   - semantic: The semantic of parts to subtract. Defaults to `.solid`.
    /// - Returns: A new geometry with the specified parts subtracted from the receiver.
    ///
    func subtractingParts(named names: Set<String>? = nil, ofType semantic: PartSemantic = .solid) -> any Geometry3D {
        readingParts(ofType: semantic) { base, parts in
            base.subtracting {
                if let names {
                    parts.filter { names.contains($0.key) }.values
                } else {
                    parts.values
                }
            }
        }
    }
}

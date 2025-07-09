import Foundation

public extension Geometry3D {
    /// Splits the geometry into two parts along the specified plane, assigning one side to a named part.
    ///
    /// This variant is useful when you want to separate a portion of the geometry into a named part
    /// for viewing or slicing. The side of the geometry that faces the direction of the plane's normal
    /// is moved into a named part, while the opposite side remains in place. This is useful as a way to
    /// view a clean cross-section of the model.
    ///
    /// The named part is detached from the geometry tree and appears as a separate object in the resulting
    /// 3MF file. It will follow transformations applied to the overall geometry but is otherwise excluded
    /// from subsequent operations like booleans or modifiers.
    ///
    /// - Parameters:
    ///   - plane: The `Plane` used to split the geometry.
    ///   - partName: The name to assign to the detached part.
    ///   - type: The semantic role of the part in the 3MF output. This controls how the part is interpreted by slicers and viewers.
    ///           For example, use `.solid` for printable geometry, `.context` for reference geometry, or `.visual` for display-only parts.
    ///
    /// - Returns: A new geometry with one part detached into a named part.
    ///
    /// ## Example
    /// ```swift
    /// model.separating(along: Plane(z: 0), into: "top-half")
    /// ```
    func separating(along plane: Plane, into partName: String, type: PartSemantic = .solid) -> any Geometry3D {
        split(along: plane) { over, under in
            over.inPart(named: partName, type: type)
            under
        }
    }

    /// Splits the geometry into two parts using a custom mask geometry, assigning one side to a named part.
    ///
    /// This method separates the portion of the geometry that lies within a user-provided mask and assigns it
    /// to a named part. The rest of the geometry remains part of the original object. The detached part is placed
    /// in a separate group in the resulting 3MF file, which can be useful for visualizing cross-sections or
    /// organizing multi-part prints.
    ///
    /// The named part will follow transformations applied to the main geometry, but is excluded from subsequent
    /// boolean operations or modifications.
    ///
    /// - Parameters:
    ///   - partName: The name to assign to the detached part.
    ///   - type: The semantic role of the part in the 3MF output. This controls how the part is interpreted by slicers and viewers.
    ///           For example, use `.solid` for printable geometry, `.context` for reference geometry, or `.visual` for display-only parts.
    ///   - mask: A closure that builds the mask geometry used for splitting.
    ///
    /// - Returns: A new geometry with the masked part detached into a named part.
    ///
    /// ## Example
    /// ```swift
    /// model.separating(into: "bottom") {
    ///     Box(x: 10, y: 10, z: 2)
    ///         .translated(z: 1)
    /// }
    /// ```
    func separating(into partName: String, type: PartSemantic = .solid, @GeometryBuilder3D mask: @escaping () -> any Geometry3D) -> any Geometry3D {
        split(with: mask) { inside, outside in
            inside.inPart(named: partName, type: type)
            outside
        }
    }
}

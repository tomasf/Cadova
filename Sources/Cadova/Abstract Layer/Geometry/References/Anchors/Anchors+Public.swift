import Foundation

/// A value used to mark coordinate systems that can be referenced elsewhere in a model.
///
/// Anchors provide a way to capture a transformation state at one location in your geometry tree
/// and later place other geometry at that same world-space position and orientation. This is useful
/// for attaching parts together, such as placing screws in predefined holes or mounting components
/// at specific locations.
///
/// You create an anchor once (optionally with a human-readable label for debugging) and then define
/// it on geometry using `definingAnchor(_:at:offset:pointing:rotated:)`. Later, you can
/// use `anchored(to:)` to place other geometry at the recorded transforms.
///
/// - Multiple definitions:
///   - An anchor can be defined multiple times across a geometry tree. Each definition records a
///     separate world transform. When you call `anchored(to:)`, the geometry is duplicated at each
///     recorded location and orientation.
///
/// - Undefined anchors:
///   - Referencing an anchor that has no definitions produces no geometry and prints a warning when
///     the model is fully built.
///
public struct Anchor: Hashable, Sendable, CustomStringConvertible {
    internal let id = UUID()
    internal let label: String?

    /// Creates a new anchor.
    ///
    /// - Parameter label: An optional label for debugging and diagnostics (e.g., undefined anchor warnings).
    public init(_ label: String? = nil) {
        self.label = label
    }

    public var description: String {
        if let label {
            "Anchor \"\(label)\" (\(id))"
        } else {
            "Anchor \(id)"
        }
    }
}

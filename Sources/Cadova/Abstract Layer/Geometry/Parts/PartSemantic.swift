import Foundation

/// Specifies the semantic role of a part in the 3MF output.
///
/// This is used to indicate how a part should be treated in the resulting model.
///
public enum PartSemantic: String, Hashable, Sendable, Codable, CaseIterable {
    /// A regular printable part, typically rendered as opaque and included in the physical output.
    case solid

    /// A background or reference part used for spatial context. These parts are included in the model for
    /// visualization, but are not intended to be printed or interact with the printable geometry.
    case context

    /// A visual-only part used for display, guidance, or context. These are not intended for printing.
    case visual
}

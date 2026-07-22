import Foundation

/// Horizontal alignment options for text relative to the origin.
///
/// Use with ``Geometry/withTextAlignment(horizontal:vertical:)`` to control how
/// text is positioned horizontally relative to the X origin.
///
public enum HorizontalTextAlignment: Sendable, Hashable, Codable {
    /// Places the left (minimum X) edge of the text at the origin.
    case left

    /// Centers the text horizontally (center X) on the origin.
    case center

    /// Places the right edge (maximum X) of the text at the origin.
    case right
}

/// Vertical alignment options for text relative to the origin.
///
/// Use with ``Geometry/withTextAlignment(horizontal:vertical:)`` to control how
/// text is positioned vertically relative to the Y origin.
///
public enum VerticalTextAlignment: Sendable, Hashable, Codable {
    /// Places the baseline of the first line at the origin.
    case firstBaseline

    /// Places the baseline of the last line at the origin.
    case lastBaseline

    /// Places the top of the text (ascender) at the origin.
    case top

    /// Centers the text vertically on the origin.
    case center

    /// Places the bottom of the text (descender) at the origin.
    case bottom
}

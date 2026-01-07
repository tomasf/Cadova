import Foundation

/// Describes how the ends of open strokes are capped.
public enum LineCapStyle: Hashable, Sendable, Codable {
    /// Ends are squared off exactly at the end of the curve.
    case butt

    /// Ends are rounded with a semicircle of radius half the stroke width.
    case round

    /// Ends are extended by half the stroke width and squared off.
    case square
}

public extension EnvironmentValues {
    static private let lineCapStyleKey = Key("Cadova.LineCapStyle")

    /// The cap style used for open-curve strokes. Defaults to `.butt`.
    var lineCapStyle: LineCapStyle {
        get { self[Self.lineCapStyleKey] as? LineCapStyle ?? .butt }
        set { self[Self.lineCapStyleKey] = newValue }
    }

    func withLineCapStyle(_ style: LineCapStyle) -> EnvironmentValues {
        setting(key: Self.lineCapStyleKey, value: style)
    }
}

public extension Geometry {
    /// Sets the cap style for open-curve strokes.
    func withLineCapStyle(_ style: LineCapStyle) -> D.Geometry {
        withEnvironment { $0.withLineCapStyle(style) }
    }
}

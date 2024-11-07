import Foundation

internal extension EnvironmentValues {
    struct TextAttributes: Sendable {
        var fontName: String?
        var fontStyle: String?
        var fontSize: Double?

        var horizontalAlignment: Text.HorizontalAlignment?
        var verticalAlignment: Text.VerticalAlignment?
        var characterSpacing: Double?
    }

    static private let environmentKey = Key("SwiftSCAD.TextAttributes")

    var textAttributes: TextAttributes {
        self[Self.environmentKey] as? TextAttributes ?? .init()
    }

    func settingTextAttribute<V>(_ attribute: WritableKeyPath<TextAttributes, V>, value: V) -> EnvironmentValues {
        var attributes = textAttributes
        attributes[keyPath: attribute] = value
        return setting(key: Self.environmentKey, value: attributes)
    }

    func withFont(name: String?, style: String?, size: Double?) -> EnvironmentValues {
        var e = self
        if let name {
            e = e.settingTextAttribute(\.fontName, value: name)
        }
        if let style {
            e = e.settingTextAttribute(\.fontStyle, value: style)
        }
        if let size {
            e = e.settingTextAttribute(\.fontSize, value: size)
        }
        return e
    }

    func withTextAlignment(horizontal: Text.HorizontalAlignment? = nil, vertical: Text.VerticalAlignment? = nil) -> EnvironmentValues {
        var e = self
        if let horizontal {
            e = e.settingTextAttribute(\.horizontalAlignment, value: horizontal)
        }
        if let vertical {
            e = e.settingTextAttribute(\.verticalAlignment, value: vertical)
        }
        return e
    }
}

public extension EnvironmentValues {
    /// The current font name set in the environment's text attributes.
    ///
    /// This property reflects the font name that will be applied to text geometries within the environment. If `nil`, the default system font is used.
    var fontName: String? { textAttributes.fontName }

    /// The current font style set in the environment's text attributes.
    ///
    /// This property reflects the font style (e.g., "Bold", "Italic") that will be applied to text geometries within the environment. If `nil`, the default font style is used.
    var fontStyle: String? { textAttributes.fontStyle }

    /// The current font size set in the environment's text attributes.
    ///
    /// This property reflects the font size that will be applied to text geometries within the environment. If `nil`, the default font size is used.
    var fontSize: Double? { textAttributes.fontSize }

    /// The current horizontal text alignment set in the environment's text attributes.
    ///
    /// This property determines the horizontal alignment (left, center, right) of text geometries within the environment. If `nil`, the default alignment is used.
    var horizontalTextAlignment: Text.HorizontalAlignment? { textAttributes.horizontalAlignment }

    /// The current vertical text alignment set in the environment's text attributes.
    ///
    /// This property determines the vertical alignment (top, center, baseline, bottom) of text geometries within the environment. If `nil`, the default alignment is used.
    var verticalTextAlignment: Text.VerticalAlignment? { textAttributes.verticalAlignment }

    /// The current character spacing set in the environment's text attributes.
    ///
    /// This property reflects the factor by which character spacing is adjusted for text geometries within the environment. A value of 1 indicates normal spacing, while values greater than 1 increase the spacing. If `nil`, the default spacing is used.
    var characterSpacing: Double? { textAttributes.characterSpacing }
}

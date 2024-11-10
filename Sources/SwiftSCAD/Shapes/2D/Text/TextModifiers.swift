import Foundation

public extension Geometry2D {
    /// Applies a specified font name, style, and size to text geometry.
    ///
    /// This method allows for the customization of fonts. Providing `nil` for any of the parameters will leave that particular attribute unchanged. SwiftSCAD adjusts the font size to align with standard typographical expectations, countering OpenSCAD's unconventional scaling. This ensures that specified point sizes reflect typical visual sizes.
    ///
    /// - Parameters:
    ///   - fontName: The name of the font. Default is `nil`.
    ///   - style: The style of the font (e.g., "Bold", "Italic"). Default is `nil`.
    ///   - size: The size of the font. Default is `nil`.
    /// - Returns: A new `Geometry2D` instance with the updated font attributes.
    func usingFont(_ fontName: String? = nil, style: String? = nil, size: Double? = nil) -> any Geometry2D {
        withEnvironment {
            $0.withFont(name: fontName, style: style, size: size)
        }
    }

    /// Sets the horizontal and vertical text alignment for text geometry.
    ///
    /// Specifying `nil` for either parameter will keep the current alignment for that direction unchanged.
    ///
    /// - Parameters:
    ///   - horizontal: The horizontal text alignment. Default is `nil`.
    ///   - vertical: The vertical text alignment. Default is `nil`.
    /// - Returns: A new `Geometry2D` instance with the updated text alignment.
    func usingTextAlignment(horizontal: Text.HorizontalAlignment? = nil, vertical: Text.VerticalAlignment? = nil) -> any Geometry2D {
        withEnvironment {
            $0.withTextAlignment(horizontal: horizontal, vertical: vertical)
        }
    }

    /// Adjusts the character spacing in text geometry.
    ///
    /// This method sets the factor by which character spacing is increased or decreased. A value of 1 (the default) results in normal spacing for the font. Values greater than 1 increase the space between characters, effectively spreading them further apart.
    ///
    /// - Parameter spacingFactor: The character spacing factor. A value greater than 1 causes the characters to be spaced further apart.
    /// - Returns: A new `Geometry2D` instance with the updated character spacing.
    func usingCharacterSpacing(_ spacingFactor: Double) -> any Geometry2D {
        withEnvironment {
            $0.settingTextAttribute(\.characterSpacing, value: spacingFactor)
        }
    }
}

public extension Geometry3D {
    /// Applies a specified font name, style, and size to text geometry.
    ///
    /// This method allows for the customization of fonts. Providing `nil` for any of the parameters will leave that particular attribute unchanged. SwiftSCAD adjusts the font size to align with standard typographical expectations, countering OpenSCAD's unconventional scaling. This ensures that specified point sizes reflect typical visual sizes.
    ///
    /// - Parameters:
    ///   - fontName: The name of the font. Default is `nil`.
    ///   - style: The style of the font (e.g., "Bold", "Italic"). Default is `nil`.
    ///   - size: The size of the font. Default is `nil`.
    /// - Returns: A new `Geometry3D` instance with the updated font attributes.
    func usingFont(_ fontName: String? = nil, style: String? = nil, size: Double? = nil) -> any Geometry3D {
        withEnvironment {
            $0.withFont(name: fontName, style: style, size: size)
        }
    }

    /// Sets the horizontal and vertical text alignment for text geometry.
    ///
    /// Specifying `nil` for either parameter will keep the current alignment for that direction unchanged.
    ///
    /// - Parameters:
    ///   - horizontal: The horizontal text alignment. Default is `nil`.
    ///   - vertical: The vertical text alignment. Default is `nil`.
    /// - Returns: A new `Geometry3D` instance with the updated text alignment.
    func usingTextAlignment(horizontal: Text.HorizontalAlignment? = nil, vertical: Text.VerticalAlignment? = nil) -> any Geometry3D {
        withEnvironment {
            $0.withTextAlignment(horizontal: horizontal, vertical: vertical)
        }
    }

    /// Adjusts the character spacing in text geometry.
    ///
    /// This method sets the factor by which character spacing is increased or decreased. A value of 1 (the default) results in normal spacing for the font. Values greater than 1 increase the space between characters, effectively spreading them further apart.
    ///
    /// - Parameter spacing: The character spacing factor. A value greater than 1 causes the characters to be spaced further apart.
    /// - Returns: A new `Geometry3D` instance with the updated character spacing.
    func usingCharacterSpacing(_ spacing: Double) -> any Geometry3D {
        withEnvironment {
            $0.settingTextAttribute(\.characterSpacing, value: spacing)
        }
    }
}

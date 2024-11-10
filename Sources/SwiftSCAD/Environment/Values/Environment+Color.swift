import Foundation

public extension EnvironmentValues {
    private static let key = Key("SwiftSCAD.Color")

    /// The color value currently set in the environment.
    ///
    /// This property retrieves the optional color setting from the environment. If a color has not been explicitly set, this property will return `nil`. Color can be applied to geometry instances to visually represent or differentiate them. While the color value itself does not directly influence geometry creation in SwiftSCAD, it can be used by models to adjust rendering or style based on the specified color.
    ///
    /// - Returns: The current color value as an optional `Color`.
    var color: Color? {
        self[Self.key] as? Color
    }

    internal func withColor(_ color: Color?) -> EnvironmentValues {
        setting(key: Self.key, value: color)
    }
}

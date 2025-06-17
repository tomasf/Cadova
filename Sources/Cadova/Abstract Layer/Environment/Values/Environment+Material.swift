import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.Material")
    /// The material value currently set in the environment.
    ///
    /// This property retrieves the optional material setting from the environment. If a material has not been
    /// explicitly set, this property will return `nil`. Material can be applied to geometry instances to visually
    /// represent or differentiate them. While the material itself does not directly influence geometry creation in
    /// Cadova, it can be used by models to adjust rendering or style based on the specified material.
    ///
    /// - Returns: The current material value as an optional `Material`.
    ///
    var material: Material? {
        self[Self.key] as? Material
    }

    internal func withMaterial(_ material: Material?) -> EnvironmentValues {
        if self[Self.key] == nil {
            setting(key: Self.key, value: material)
        } else {
            self
        }
    }
}

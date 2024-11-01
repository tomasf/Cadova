import Foundation

public extension Environment {
    private static let key = Key("SwiftSCAD.PreviewConvexity")

    /// The preview convexity currently set in the environment.
    ///
    /// The `previewConvexity` parameter specifies the maximum number of front or back faces a ray might intersect in the geometry during preview rendering. This parameter is only relevant when using OpenCSG preview mode in OpenSCAD and has no effect on the final mesh output or rendering.
    ///
    /// - Important: In OpenCSG preview mode, `previewConvexity` helps determine the correct visibility of complex shapes (e.g., tori or nested geometries). Adjust this parameter for accurate previews of intricate models but know that it is not necessary for final output generation.
    ///
    /// - Returns: The preview convexity value as an `Int`, or `nil` if not set.
    var previewConvexity: Int? {
        self[Self.key] as? Int
    }

    /// Returns a new environment with a modified preview convexity value.
    ///
    /// Use this method to apply a `previewConvexity` value to the environment, influencing the OpenCSG preview rendering in OpenSCAD.
    ///
    /// - Parameter convexity: An optional `Int` specifying the maximum number of front or back faces a ray might intersect. Pass `nil` to remove the existing convexity setting.
    /// - Returns: A new `Environment` with the specified preview convexity.
    ///
    /// ### Example
    /// ```swift
    /// let environmentWithConvexity = environment.withPreviewConvexity(2)
    /// ```
    func withPreviewConvexity(_ convexity: Int?) -> Environment {
        setting(key: Self.key, value: convexity)
    }
}

public extension Geometry3D {
    /// Applies a preview convexity setting to the geometry.
    ///
    /// This method sets a `previewConvexity` value, specifying the maximum number of front or back faces a ray might intersect in the geometry during preview rendering. While SwiftSCAD does not use this value directly for geometry creation, OpenSCAD’s OpenCSG preview mode relies on it for accurate previews.
    ///
    /// - Parameter convexity: An `Int` specifying the preview convexity.
    /// - Returns: A modified geometry with the specified preview convexity.
    ///
    func withPreviewConvexity(_ convexity: Int) -> any Geometry3D {
        withEnvironment { enviroment in
            enviroment.withPreviewConvexity(convexity)
        }
    }
}

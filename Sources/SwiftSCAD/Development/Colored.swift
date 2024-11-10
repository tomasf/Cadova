import Foundation

public extension Geometry2D {
    /// Apply a color to the geometry.
    ///
    /// - Parameter color: The `Color` instance to apply.
    /// - Returns: A new colored geometry instance.
    func colored(_ color: Color) -> any Geometry2D {
        withEnvironment { $0.withColor(color) }
    }

    /// Apply a color with transparency to the geometry.
    ///
    /// - Parameters:
    ///   - color: The `Color` instance to apply.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A new colored geometry instance with adjusted transparency.
    func colored(_ color: Color, alpha: Double) -> any Geometry2D {
        colored(color.withAlphaComponent(alpha))
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry2D {
        colored(.init(red: red, green: green, blue: blue, alpha: alpha))
    }

    /// Modify the current color of the geometry using a custom modification function.
    ///
    /// This method allows you to adjust or replace the color of the geometry by providing
    /// a closure that receives the current color (if any) and returns a new color.
    ///
    /// - Parameter modifier: A closure that takes the current `Color?` (if any is set)
    ///   and returns an optional `Color`. Returning `nil` will remove any color previously
    ///   applied to the geometry, while returning a `Color` will set the geometry to that color.
    /// - Returns: A new geometry instance with the modified color.
    ///
    func modifyingColor(_ modifier: @escaping (Color?) -> Color?) -> any Geometry2D {
        withEnvironment { environment in
            environment.withColor(modifier(environment.color))
        }
    }

    /// Adjust the color properties of the geometry.
    ///
    /// This method adjusts the hue, saturation, brightness, and alpha values of the geometry's color.
    /// If the geometry has no color assigned, this method has no effect.
    ///
    /// - Parameters:
    ///   - hDelta: The change in hue, where 0.0 represents no change. Positive values increase the hue, and negative values decrease it.
    ///   - sDelta: The change in saturation, where 0.0 represents no change. Positive values increase saturation, and negative values decrease it.
    ///   - bDelta: The change in brightness, where 0.0 represents no change. Positive values increase brightness, and negative values decrease it.
    ///   - aDelta: The change in alpha (transparency), where 0.0 represents no change. Positive values make the color more opaque, and negative values make it more transparent.
    /// - Returns: A new geometry with the adjusted color.
    ///
    func adjustingColor(hue hDelta: Double = 0, saturation sDelta: Double = 0, brightness bDelta: Double = 0, alpha aDelta: Double = 0) -> any Geometry2D {
        modifyingColor {
            $0?.adjusting(hue: hDelta, saturation: sDelta, brightness: bDelta, alpha: aDelta)
        }
    }
}

public extension Geometry3D {
    /// Apply a color to the geometry.
    ///
    /// - Parameter color: The `Color` instance to apply.
    /// - Returns: A new colored geometry instance.
    func colored(_ color: Color) -> any Geometry3D {
        withEnvironment { $0.withColor(color) }
    }

    /// Apply a color with transparency to the geometry.
    ///
    /// - Parameters:
    ///   - color: The `Color` instance to apply.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A new colored geometry instance with adjusted transparency.
    func colored(_ color: Color, alpha: Double) -> any Geometry3D {
        colored(color.withAlphaComponent(alpha))
    }

    /// Apply a color to the geometry
    /// - Parameters:
    ///   - red: The red component, in the range 0.0 to 1.0.
    ///   - green: The green component, in the range 0.0 to 1.0.
    ///   - blue: The blue component, in the range 0.0 to 1.0.
    ///   - alpha: The alpha component, in the range 0.0 to 1.0.
    /// - Returns: A colored geometry
    func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> any Geometry3D {
        colored(.init(red: red, green: green, blue: blue, alpha: alpha))
    }

    /// Modify the current color of the geometry using a custom modification function.
    ///
    /// This method allows you to adjust or replace the color of the geometry by providing
    /// a closure that receives the current color (if any) and returns a new color.
    ///
    /// - Parameter modifier: A closure that takes the current `Color?` (if any is set)
    ///   and returns an optional `Color`. Returning `nil` will remove any color previously
    ///   applied to the geometry, while returning a `Color` will set the geometry to that color.
    /// - Returns: A new geometry instance with the modified color.
    /// 
    func modifyingColor(_ modifier: @escaping (Color?) -> Color?) -> any Geometry3D {
        withEnvironment { environment in
            environment.withColor(modifier(environment.color))
        }
    }

    /// Adjust the color properties of the geometry.
    ///
    /// This method adjusts the hue, saturation, brightness, and alpha values of the geometry's color.
    /// If the geometry has no color assigned, this method has no effect.
    ///
    /// - Parameters:
    ///   - hDelta: The change in hue, where 0.0 represents no change. Positive values increase the hue, and negative values decrease it.
    ///   - sDelta: The change in saturation, where 0.0 represents no change. Positive values increase saturation, and negative values decrease it.
    ///   - bDelta: The change in brightness, where 0.0 represents no change. Positive values increase brightness, and negative values decrease it.
    ///   - aDelta: The change in alpha (transparency), where 0.0 represents no change. Positive values make the color more opaque, and negative values make it more transparent.
    /// - Returns: A new geometry with the adjusted color.
    ///
    func adjustingColor(hue hDelta: Double = 0, saturation sDelta: Double = 0, brightness bDelta: Double = 0, alpha aDelta: Double = 0) -> any Geometry3D {
        modifyingColor {
            $0?.adjusting(hue: hDelta, saturation: sDelta, brightness: bDelta, alpha: aDelta)
        }
    }
}

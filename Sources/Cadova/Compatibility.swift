import Foundation

public extension Geometry2D {
    @available(*, deprecated, renamed: "fillingHoles")
    func filled() -> any Geometry2D {
        fillingHoles()
    }
}

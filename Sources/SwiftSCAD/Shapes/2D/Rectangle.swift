import Foundation

public struct Rectangle: CoreGeometry2D {
    public let size: Vector2D
    public let center: Axes2D

    public init(_ size: Vector2D, center: Axes2D = []) {
        self.size = size
        self.center = center
    }

    func call(in environment: Environment) -> SCADCall {
        let square = SCADCall(
            name: "square",
            params: ["size": size]
        )

        guard !center.isEmpty else {
            return square
        }

        return SCADCall(
            name: "translate",
            params: ["v": (size / -2).setting(axes: center.inverted, to: 0)],
            body: square
        )
    }
}

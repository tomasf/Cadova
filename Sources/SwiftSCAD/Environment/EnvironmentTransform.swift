import Foundation

public extension Environment {
    static fileprivate var environmentKey: Environment.ValueKey = .init(rawValue: "SwiftSCAD.Transform")

    var transform: AffineTransform3D {
        (self[Self.environmentKey] as? AffineTransform3D) ?? .identity
    }

    func applyingTransform(_ newTransform: AffineTransform3D) -> Environment {
        setting(key: Self.environmentKey, value:newTransform.concatenated(with: transform))
    }
}

import Foundation

public extension Environment {
    static fileprivate var environmentKey: Environment.ValueKey = .init(rawValue: "SwiftSCAD.Transform")

    var transform: AffineTransform {
        (self[Self.environmentKey] as? AffineTransform) ?? .identity
    }

    func applyingTransform(_ newTransform: AffineTransform) -> Environment {
        setting(key: Self.environmentKey, value:newTransform.concatenated(with: transform))
    }
}

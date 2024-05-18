import Foundation

public struct RectangleCorners: OptionSet, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let bottomLeft = Self(rawValue: 1 << 0)
    public static let topLeft = Self(rawValue: 1 << 1)
    public static let topRight = Self(rawValue: 1 << 2)
    public static let bottomRight = Self(rawValue: 1 << 3)

    public static let all: RectangleCorners = [.bottomLeft, .bottomRight, .topRight, .topLeft]
    public static let none: RectangleCorners = []

    public static let top: RectangleCorners = [.topRight, .topLeft]
    public static let bottom: RectangleCorners = [.bottomLeft, .bottomRight]
    public static let left: RectangleCorners = [.bottomLeft, .topLeft]
    public static let right: RectangleCorners = [.bottomRight, .topRight]
}

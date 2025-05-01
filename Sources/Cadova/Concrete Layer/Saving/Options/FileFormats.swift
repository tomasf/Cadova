import Foundation

public extension ModelOptions {
    static func format2D(_ format: FileFormat2D) -> Self { .init(format) }

    enum FileFormat2D: Sendable, ModelOptionItem {
        /// 3MF, 3D Manufacturing Format
        /// 2D thinly extruded to 3D
        case threeMF
        /// SVG, Scalable Vector Graphics
        case svg

        internal static let defaultValue = Self.threeMF
        internal func combined(with other: Self) -> Self { other }
    }
}

public extension ModelOptions {
    static func format3D(_ format: FileFormat3D) -> Self { .init(format) }

    enum FileFormat3D: Sendable, ModelOptionItem {
        /// 3MF, 3D Manufacturing Format
        /// Supports parts and materials
        case threeMF
        /// Binary STL
        /// No support for parts and materials, but a more widely supported format
        case stl

        internal static let defaultValue = Self.threeMF
        internal func combined(with other: Self) -> Self { other }
    }
}

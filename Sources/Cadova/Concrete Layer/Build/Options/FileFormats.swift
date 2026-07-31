import Foundation

public extension ModelOptions {
    /// Sets the desired output file format for 2D geometry export.
    ///
    /// - Parameter format: The 2D file format to use for export.
    /// - Returns: A `ModelOptions` instance representing the selected 2D format.
    static func format2D(_ format: FileFormat2D) -> Self { .init(format) }

    /// Supported output formats for exporting 2D geometry.
    enum FileFormat2D: Sendable, ModelOptionItem {
        /// 3MF (3D Manufacturing Format). Exports 2D geometry as a very thin 3D extrusion.
        case threeMF
        /// SVG (Scalable Vector Graphics). A standard vector format for 2D output.
        case svg

        internal static let defaultValue = Self.threeMF
        internal func combined(with other: Self) -> Self { other }
    }
}

public extension ModelOptions {
    /// Sets the desired output file format for 3D geometry export.
    ///
    /// - Parameter format: The 3D file format to use for export.
    /// - Returns: A `ModelOptions` instance representing the selected 3D format.
    static func format3D(_ format: FileFormat3D) -> Self { .init(format) }

    /// Supported output formats for exporting 3D geometry.
    enum FileFormat3D: Sendable, ModelOptionItem {
        /// 3MF (3D Manufacturing Format). Supports multiple parts and material information.
        case threeMF
        /// Binary STL. A widely supported format with no support for parts or materials.
        case stl

        internal static let defaultValue = Self.threeMF
        internal func combined(with other: Self) -> Self { other }
    }
}

extension ModelOptions {
    func dataProvider(for result: BuildResult<D3>) -> OutputDataProvider {
        switch self[FileFormat3D.self] {
        case .threeMF: return ThreeMFDataProvider(result: result, options: self)
        case .stl: return BinarySTLDataProvider(result: result, options: self)
        }
    }

    func dataProvider(for result: BuildResult<D2>) -> OutputDataProvider {
        switch self[FileFormat2D.self] {
        case .threeMF: return ThreeMFDataProvider(result: result.promotedTo3D(), options: self)
        case .svg: return SVGDataProvider(result: result, options: self)
        }
    }
}

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
    func dataProvider(for result: BuildResult<D3>, in environment: EnvironmentValues) -> OutputDataProvider {
        // A customizer previews every model from its meshes, whatever format it downloads in
        if CustomizerRequest.current?.preview == true {
            return ThreeMFDataProvider(result: result, options: self, environment: environment)
        }
        switch self[FileFormat3D.self] {
        case .threeMF: return ThreeMFDataProvider(result: result, options: self, environment: environment)
        case .stl: return BinarySTLDataProvider(result: result, options: self)
        }
    }

    func dataProvider(for result: BuildResult<D2>, in environment: EnvironmentValues) -> OutputDataProvider {
        if CustomizerRequest.current?.preview == true {
            return ThreeMFDataProvider(result: result.promotedTo3D(), options: self, environment: environment)
        }
        switch format2D {
        case .threeMF:
            return ThreeMFDataProvider(result: result.promotedTo3D(), options: self, environment: environment)
        case .svg:
            return SVGDataProvider(result: result, options: self)
        }
    }

    /// The 2D format to write. A customizer's visitor has no use for a flat 3MF file, so it
    /// downloads SVG unless the model asks for a format itself.
    private var format2D: FileFormat2D {
        if CustomizerRequest.current != nil, !specifies(FileFormat2D.self) {
            return .svg
        }
        return self[FileFormat2D.self]
    }
}

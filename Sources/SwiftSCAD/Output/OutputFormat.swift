import Foundation

public enum OutputFormat2D {
    case scad
    case dxf
    case svg
    case pdf
}

public enum OutputFormat3D {
    case scad
    case stlBinary
    case stlASCII
    case obj
    case threeMF
    case off
    case wrl
    case amf

    static let stl = Self.stlASCII
}

internal protocol OutputFormat: Hashable, Sendable {
    var fileExtension: String { get }
    var openSCADTypeString: String? { get }
}

extension OutputFormat2D: OutputFormat {
    var fileExtension: String {
        String(describing: self)
    }
    
    var openSCADTypeString: String? {
        switch self {
        case .scad: nil
        case .dxf, .svg, .pdf: String(describing: self)
        }
    }
}

extension OutputFormat3D: OutputFormat {
    var fileExtension: String {
        switch self {
        case .scad, .obj, .off, .wrl, .amf: String(describing: self)
        case .stlBinary, .stlASCII: "stl"
        case .threeMF: "3mf"
        }
    }
    
    var openSCADTypeString: String? {
        switch self {
        case .scad: nil
        case .stlBinary: "binstl"
        case .stlASCII: "asciistl"
        case .obj, .threeMF, .off, .wrl, .amf: fileExtension
        }
    }
}

struct OutputFormatSet2D: ResultElement {
    let formats: [OutputFormat2D]

    static func combine(elements: [OutputFormatSet2D], for operation: GeometryCombination) -> OutputFormatSet2D? {
        elements.first
    }
}

struct OutputFormatSet3D: ResultElement {
    let formats: [OutputFormat3D]

    static func combine(elements: [OutputFormatSet3D], for operation: GeometryCombination) -> OutputFormatSet3D? {
        elements.first
    }
}

public extension Geometry2D {
    func usingOutputFormats(_ formats: OutputFormat2D...) -> any Geometry2D {
        withResult(OutputFormatSet2D(formats: formats))
    }
}

public extension Geometry3D {
    func usingOutputFormats(_ formats: OutputFormat3D...) -> any Geometry3D {
        withResult(OutputFormatSet3D(formats: formats))
    }
}

import Foundation
internal import Pelagos

// MARK: - 2D (SVG) Support

extension Import where D == D2 {
    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the SVG document.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.flipped`.
    ///
    public init(svg url: URL, scale: SVGScale = .physical, origin: SVGOrigin = .flipped) {
        self.init {
            readEnvironment(\.scaledSegmentation) { segmentation in
                CachedNode(name: "import-svg", parameters: url, scale, origin, segmentation) {
                    return try SVG(url: url).geometry(segmentation: segmentation, scale: scale, origin: origin)
                }
            }
        }
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the SVG document. Can be relative or absolute.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.flipped`.
    public init(svg path: String, scale: SVGScale = .physical, origin: SVGOrigin = .flipped) {
        self.init(svg: URL(expandingFilePath: path), scale: scale, origin: origin)
    }

    /// Creates a new SVG import from data.
    ///
    /// - Parameters:
    ///   - data: The data of the SVG document.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.flipped`.
    ///
    public init<T: DataProtocol>(svg data: T, scale: SVGScale = .physical, origin: SVGOrigin = .flipped) {
        let resolvedData = Data(data)
        self.init {
            readEnvironment(\.scaledSegmentation) { segmentation in
                CachedNode(name: "import-svg", parameters: resolvedData, scale, origin, segmentation) {
                    return try SVG(data: resolvedData).geometry(segmentation: segmentation, scale: scale, origin: origin)
                }
            }
        }
    }
}

/// Controls how SVG units are interpreted when importing.
public enum SVGScale: Hashable, Sendable, Codable {
    /// Physical units are preserved: 1mm in SVG becomes 1mm in output.
    /// Unitless values (pixels) are converted using the SVG standard of 96 pixels per inch.
    case physical

    /// Unitless values map directly: 1 pixel in SVG becomes 1mm in output.
    /// Physical units are scaled accordingly (e.g., 1mm in SVG becomes ~3.78mm).
    case pixels
}

/// Controls how the SVG coordinate system is mapped to Cadova's coordinate system.
public enum SVGOrigin: Hashable, Sendable, Codable {
    /// Flips the Y axis so the SVG appears the same way it does in browsers/editors.
    case flipped

    /// Preserves the SVG coordinate system as-is.
    /// Y coordinates are unchanged but content appears inverted compared to browsers.
    case native
}

fileprivate extension SVG {
    func geometry(segmentation: Segmentation, scale: SVGScale, origin: SVGOrigin) -> any Geometry2D {
        let renderer = ShapeExtractionRenderer(segmentation: segmentation, scale: scale)
        let scaleFactor = renderer.scale
        render(with: renderer)

        return renderer.output.measuringBounds { output, bounds in
            let size = self.size.map { Vector2D($0 * scaleFactor, $1 * scaleFactor) } ?? bounds.maximum

            if origin == .flipped {
                output
                    .flipped(along: .y)
                    .translated(y: size.y)
            } else {
                output
            }
        }
    }
}

import Foundation
internal import Pelagos

// MARK: - 2D (SVG) Support

extension Import where D == D2 {
    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the SVG document.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg url: URL, scale: SVGScale = .physical, origin: SVGOrigin = .bottomLeft) {
        self.init {
            readEnvironment(\.scaledSegmentation) { segmentation in
                CachedNode(name: "import-svg", parameters: url, scale, origin, segmentation) {
                    let svg = try SVG(url: url)
                    let renderer = ShapeExtractionRenderer(segmentation: segmentation, scale: scale, origin: origin)
                    svg.render(with: renderer)
                    let size = svg.size ?? (width: 100, height: 100)
                    return renderer.extractedShapes(documentSize: size)
                }
            }
        }
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the SVG document. Can be relative or absolute.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg path: String, scale: SVGScale = .physical, origin: SVGOrigin = .bottomLeft) {
        self.init(svg: URL(expandingFilePath: path), scale: scale, origin: origin)
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
        /// Aligns the SVG's bottom-left corner with the origin and flips the Y axis.
        /// The SVG appears the same way it does in browsers/editors.
        case bottomLeft

        /// Keeps the SVG's top-left origin aligned with Cadova's origin.
        /// Y coordinates are preserved but content appears upside-down compared to browsers.
        case topLeft
    }
}

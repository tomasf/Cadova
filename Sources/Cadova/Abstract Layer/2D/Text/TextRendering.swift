import Foundation
internal import Apus

internal enum TextError: Error {
    case fontNotFound (family: String, style: String?)
    case fontLoadingFailed
}

/// Generic fallback families tried, in order, when no requested family is available.
/// Covers the common platforms: Helvetica (Apple), Arial (Windows), and the
/// `sans-serif` generic (Linux/fontconfig).
private let fallbackFontFamilies = ["Helvetica", "Arial", "sans-serif"]

/// Resolves a font from a `font-family` value that may be a CSS-style list of
/// families (e.g. `"Lucida Grande", Helvetica, sans-serif`), trying each in order.
///
/// If none of the requested families are available — including a single family name
/// — resolution falls back to a generic font (see ``fallbackFontFamilies``) so text
/// still renders instead of failing the whole render. Only when no fallback resolves
/// either does it throw.
private func resolveFont(family: String, style: String?, variations: [Apus.FontVariation]) throws -> Font {
    let candidates = family.fontFamilyCandidates
    for candidate in candidates {
        if let font = try? Font(family: candidate, style: style, variations: variations) {
            return font
        }
    }
    for fallback in fallbackFontFamilies where !candidates.contains(fallback) {
        if let font = try? Font(family: fallback, style: style, variations: variations) {
            return font
        }
    }
    throw Font.FontError.fontNotFound(family: family, style: style)
}

private extension String {
    /// Splits a CSS `font-family` value into individual family names, trimming
    /// whitespace and stripping matching surrounding quotes. A plain family name
    /// (no commas) yields a single-element list.
    var fontFamilyCandidates: [String] {
        split(separator: ",").compactMap { part -> String? in
            var name = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count >= 2, let quote = name.first, quote == "\"" || quote == "'", name.last == quote {
                name = String(name.dropFirst().dropLast())
            }
            return name.isEmpty ? nil : name
        }
    }
}

extension TextAttributes {
    func render(text: String, with segmentation: Segmentation) throws -> SimplePolygonList {
        guard let family = fontFace?.family, let size = fontSize else {
            preconditionFailure("render(text:) called on unresolved TextAttributes")
        }

        // Convert Cadova FontVariation to Apus FontVariation
        let apusVariations = (fontVariations ?? []).map { variation in
            Apus.FontVariation(tag: variation.tag, value: variation.value)
        }

        // Load font using Apus
        let font: Font
        if let fontFile {
            let fontData = try Data(contentsOf: fontFile)
            font = try Font(data: fontData, family: family, style: fontFace?.style, variations: apusVariations)
        } else {
            do {
                font = try resolveFont(family: family, style: fontFace?.style, variations: apusVariations)
            } catch Font.FontError.fontNotFound {
                throw TextError.fontNotFound(family: family, style: fontFace?.style)
            }
        }

        // Apus uses 1000pt internally, scale to requested size
        let scale = size / 1000.0

        let textLines = text.components(separatedBy: "\n")

        let trackingAmount = tracking ?? 0

        let lines = textLines.map { line -> (SimplePolygonList, width: Double) in
            let shapedGlyphs = font.glyphs(for: line)

            // Count unique clusters for tracking calculation
            var clusterIndex = 0
            var previousCluster: UInt32?

            let glyphPolygons = shapedGlyphs.compactMap { glyph -> SimplePolygonList? in
                // Increment cluster index when we encounter a new cluster
                if let prev = previousCluster, glyph.cluster != prev {
                    clusterIndex += 1
                }
                previousCluster = glyph.cluster

                let positionedPath = glyph.positionedPath
                guard !positionedPath.isEmpty else { return nil }

                let bezierPaths = positionedPath.toBezierPaths(scale: scale)
                let polygons = bezierPaths.map { path in
                    SimplePolygon(path.points(segmentation: segmentation))
                }
                let glyphPolygonList = SimplePolygonList(polygons)

                // Apply tracking offset based on cluster index
                let trackingOffset = Double(clusterIndex) * trackingAmount
                return glyphPolygonList.translated(x: trackingOffset, y: 0)
            }

            let totalPolygons = SimplePolygonList(glyphPolygons.flatMap(\.polygons))

            // Calculate line width from the last glyph's position + advance, plus total tracking
            let lineWidth: Double
            if let lastGlyph = shapedGlyphs.last {
                let baseWidth = (lastGlyph.position.x + lastGlyph.advance.x) * scale
                // clusterIndex now represents the number of cluster transitions (= unique clusters - 1)
                let totalTracking = Double(clusterIndex) * trackingAmount
                lineWidth = baseWidth + totalTracking
            } else {
                lineWidth = 0
            }

            return (totalPolygons, lineWidth)
        }

        // Get metrics from font, scaled to requested size
        let baseLineHeight = font.metrics.lineHeight * scale
        let lineHeight = baseLineHeight + (lineSpacingAdjustment ?? 0)
        let ascender = font.metrics.ascender * scale
        let descender = font.metrics.descender * scale
        let horizontalAdjustment = horizontalAlignment!.adjustmentFactor

        let lastBaselineOffset = lineHeight * Double(lines.count - 1)

        let verticalOffset: Double = switch verticalAlignment! {
        case .firstBaseline: 0
        case .lastBaseline: lastBaselineOffset
        case .top: -ascender
        case .bottom: lastBaselineOffset - descender
        case .center: (lastBaselineOffset - descender - ascender) / 2
        }

        let adjustedPolygons = lines.enumerated().map(unpacked).map { lineIndex, polygons, width in
            polygons.translated(
                x: horizontalAdjustment * width,
                y: lineHeight * -Double(lineIndex) + verticalOffset
            )
        }

        return SimplePolygonList(adjustedPolygons.flatMap(\.polygons))
    }
}

fileprivate extension HorizontalTextAlignment {
    var adjustmentFactor: Double {
        switch self {
        case .left: 0
        case .center: -0.5
        case .right: -1.0
        }
    }
}

// MARK: - Apus Path to Cadova BezierPath Conversion

fileprivate extension Apus.Path {
    /// Convert Apus Path to array of Cadova BezierPath2D
    /// Each contour (starting with moveTo) becomes a separate BezierPath2D
    func toBezierPaths(scale: Double) -> [BezierPath2D] {
        var paths: [BezierPath2D] = []
        var currentPath: BezierPath2D?

        for element in elements {
            switch element {
            case .moveTo(let point):
                // Save previous path if any, then start a new one
                if let path = currentPath {
                    paths.append(path)
                }
                currentPath = BezierPath2D(startPoint: point.toVector2D(scale: scale))

            case .lineTo(let point):
                if let path = currentPath {
                    currentPath = path.addingLine(to: point.toVector2D(scale: scale))
                }

            case .quadraticTo(let control, let end):
                if let path = currentPath {
                    currentPath = path.addingQuadraticCurve(
                        controlPoint: control.toVector2D(scale: scale),
                        end: end.toVector2D(scale: scale)
                    )
                }

            case .cubicTo(let control1, let control2, let end):
                if let path = currentPath {
                    currentPath = path.addingCubicCurve(
                        controlPoint1: control1.toVector2D(scale: scale),
                        controlPoint2: control2.toVector2D(scale: scale),
                        end: end.toVector2D(scale: scale)
                    )
                }

            case .close:
                // Close is implicit in BezierPath - just continue with current path
                break
            }
        }

        // Add final path
        if let path = currentPath {
            paths.append(path)
        }

        return paths
    }
}

fileprivate extension Apus.Point {
    func toVector2D(scale: Double) -> Vector2D {
        Vector2D(x * scale, y * scale)
    }
}

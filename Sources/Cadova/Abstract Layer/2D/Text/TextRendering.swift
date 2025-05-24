import Foundation
import freetype
import FindFont

internal enum TextError: Error {
    case fontNotFound (family: String, style: String?)
    case freeTypeInitializationFailure
    case fontLoadingFailed
}

extension TextAttributes {
    func render(text: String, in environment: EnvironmentValues) throws -> SimplePolygonList {
        guard let family = fontFace?.family, let size = fontSize else {
            preconditionFailure("render(text:) called on unresolved TextAttributes")
        }

        let fontData: Data
        let effectiveFace: (family: String, style: String?)

        if let fontFile {
            fontData = try! Data(contentsOf: fontFile)
            effectiveFace = (family, fontFace?.style)

        } else {
            guard let match = try FontRepository.matchForFont(family: family, style: fontFace?.style) else {
                throw TextError.fontNotFound(family: family, style: fontFace?.style)
            }
            fontData = match.data
            effectiveFace = (match.familyName, match.style)
        }

        var library: FT_Library?
        guard FT_Init_FreeType(&library) == 0, let library else {
            throw TextError.freeTypeInitializationFailure
        }

        guard let face = try library.faceMatching(family: effectiveFace.family, style: effectiveFace.style, from: fontData) else {
            throw TextError.fontLoadingFailed
        }

        FT_Set_Char_Size(face, 0, FT_F26Dot6(size * 64.0), 72, 72)
        FT_Select_Charmap(face, FT_ENCODING_UNICODE)

        let glyphRenderer = GlyphRenderer()
        let textLines = text.components(separatedBy: "\n")

        let lines = textLines.map { line -> (SimplePolygonList, width: Double) in
            var glyphOffset = Vector2D.zero
            let glyphs = line.unicodeScalars.compactMap { unicodeScalar -> SimplePolygonList? in
                let glyphIndex = FT_Get_Char_Index(face, FT_ULong(unicodeScalar.value))

                guard FT_Load_Glyph(face, glyphIndex, Int32(FT_LOAD_NO_BITMAP | FT_LOAD_NO_HINTING)) == 0 else {
                    logger.error(.init(stringLiteral: String(format: "Failed to load glyph %u (U+%04X)", glyphIndex, unicodeScalar.value)))
                    return nil
                }

                let glyph = face.pointee.glyph.pointee
                guard glyph.format == FT_GLYPH_FORMAT_OUTLINE else {
                    logger.error(.init(stringLiteral: String(format: "Glyph %u (U+%04X) has an incompatible format", glyphIndex, unicodeScalar.value)))
                    return nil
                }

                guard let polygons = glyphRenderer.polygons(for: glyph.outline, in: environment) else { return nil }

                let offsetPolygons = polygons.transformed(.translation(glyphOffset))
                glyphOffset += glyph.advance.cadovaVector
                return offsetPolygons
            }
            let polygons = SimplePolygonList(glyphs.flatMap(\.polygons))
            return (polygons, glyphOffset.x)
        }

        let metrics = face.pointee.size.pointee.metrics
        FT_Done_Face(face)
        FT_Done_FreeType(library)

        let lineHeight = Double(metrics.height) / 64.0
        let ascender = Double(metrics.ascender) / 64.0
        let descender = Double(metrics.descender) / 64.0
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
            polygons.transformed(.translation(
                x: horizontalAdjustment * width,
                y: lineHeight * -Double(lineIndex) + verticalOffset
            ))
        }

        return SimplePolygonList(adjustedPolygons.flatMap(\.polygons))
    }
}

fileprivate extension FT_Library {
    // Caller is responsible for calling FT_Done_Face on a returned face
    func faceMatching(family targetFamily: String, style targetStyle: String?, from fontData: Data) throws -> FT_Face? {
        var face: FT_Face?
        let loadResult = fontData.withUnsafeBytes { buffer in
            FT_New_Memory_Face(self, buffer.baseAddress, FT_Long(buffer.count), -1, &face)
        }
        guard loadResult == 0, let dummyFace = face else {
            throw TextError.fontLoadingFailed
        }

        let faceCount = dummyFace.pointee.num_faces
        FT_Done_Face(dummyFace)

        for i in 0..<faceCount {
            let loadResult = fontData.withUnsafeBytes { buffer in
                FT_New_Memory_Face(self, buffer.baseAddress, FT_Long(buffer.count), i, &face)
            }
            guard loadResult == 0, let face else {
                throw TextError.fontLoadingFailed
            }

            let familyName = String(cString: face.pointee.family_name)
            let faceName = String(cString: face.pointee.style_name)

            if (familyName == targetFamily), (faceName == targetStyle || targetStyle == nil) {
                return face
            }

            FT_Done_Face(face)
        }
        return nil
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

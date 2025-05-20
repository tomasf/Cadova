import Foundation
import freetype

internal enum TextError: Error {
    case freeTypeInitializationFailure
    case fontLoadingFailed
}

extension TextAttributes {
    func render(text: String, in environment: EnvironmentValues) throws -> SimplePolygonList {
        guard let family = fontFace?.family, let size = fontSize else {
            preconditionFailure("render(text:) called on unresolved TextAttributes")
        }

        guard let fontURL = fontFile else {
            preconditionFailure("Font finding is not supported yet")
        }

        var library: FT_Library?
        guard FT_Init_FreeType(&library) == 0, let library else {
            throw TextError.freeTypeInitializationFailure
        }

        guard let fontData = try? Data(contentsOf: fontURL) else {
            throw TextError.fontLoadingFailed
        }

        var face: FT_Face?
        if let style = fontFace?.style {
            face = try library.faceMatching(family: family, style: style, from: fontData)
        } else {
            face = try library.primaryFace(matchingFamily: family, from: fontData)
        }

        guard let face else {
            throw TextError.fontLoadingFailed
        }

        FT_Set_Char_Size(face, 0, Int(size * 64.0), 72, 72)
        FT_Select_Charmap(face, FT_ENCODING_UNICODE)

        var glyphOffset = Vector2D.zero
        let glyphRenderer = GlyphRenderer()

        let glyphs = text.unicodeScalars.compactMap { unicodeScalar -> SimplePolygonList? in
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

        FT_Done_Face(face)
        FT_Done_FreeType(library)

        return SimplePolygonList(glyphs.flatMap(\.polygons))
    }
}

fileprivate extension FT_Library {
    // Caller is responsible for calling FT_Done_Face on a returned face
    func faceMatching(family targetFamily: String?, style targetStyle: String?, from fontData: Data) throws -> FT_Face? {
        var face: FT_Face?
        let loadResult = fontData.withUnsafeBytes { buffer in
            FT_New_Memory_Face(self, buffer.baseAddress, buffer.count, -1, &face)
        }
        guard loadResult == 0, let dummyFace = face else {
            throw TextError.fontLoadingFailed
        }

        let faceCount = dummyFace.pointee.num_faces ?? 0
        FT_Done_Face(dummyFace)

        for i in 0..<faceCount {
            let loadResult = fontData.withUnsafeBytes { buffer in
                FT_New_Memory_Face(self, buffer.baseAddress, buffer.count, i, &face)
            }
            guard loadResult == 0, let face else {
                throw TextError.fontLoadingFailed
            }

            let familyName = String(cString: face.pointee.family_name)
            let faceName = String(cString: face.pointee.style_name)

            if (familyName == targetFamily || targetFamily == nil), (faceName == targetStyle || targetStyle == nil) {
                return face
            }

            FT_Done_Face(face)
        }
        return nil
    }

    // Matches a font family name without a style
    // Caller is responsible for calling FT_Done_Face on a returned face
    func primaryFace(matchingFamily targetFamily: String, from fontData: Data) throws -> FT_Face? {
        var face: FT_Face?
        let loadResult = fontData.withUnsafeBytes { buffer in
            FT_New_Memory_Face(self, buffer.baseAddress, buffer.count, -1, &face)
        }
        guard loadResult == 0, let dummyFace = face else {
            throw TextError.fontLoadingFailed
        }

        let faceCount = dummyFace.pointee.num_faces ?? 0
        FT_Done_Face(dummyFace)

        let allFaces = try (0..<faceCount).compactMap { faceIndex in
            var face: FT_Face?
            let loadResult = fontData.withUnsafeBytes { buffer in
                FT_New_Memory_Face(self, buffer.baseAddress, buffer.count, faceIndex, &face)
            }
            guard loadResult == 0, let face else {
                throw TextError.fontLoadingFailed
            }

            let familyName = String(cString: face.pointee.family_name)
            if familyName == targetFamily {
                return face
            } else {
                FT_Done_Face(face)
                return nil
            }
        }

        defer {
            allFaces.forEach { FT_Done_Face($0) }
        }

        // First, check if there is a style called "Regular"
        if let regularMatch = allFaces.first(where: { String(cString: $0.pointee.style_name) == "Regular" }) {
            FT_Reference_Face(regularMatch)
            return regularMatch
        }

        // If not, try matching one without bold and italic flags
        if let plainMatch = allFaces.first(where: { $0.pointee.style_flags & FT_Long(FT_STYLE_FLAG_ITALIC | FT_STYLE_FLAG_BOLD) == 0 }) {
            FT_Reference_Face(plainMatch)
            return plainMatch
        }

        // Otherwise, fuck it
        if let first = allFaces.first {
            FT_Reference_Face(first)
            return first
        }

        return nil
    }
}

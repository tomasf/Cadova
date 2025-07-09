import Foundation

internal struct TextAttributes: Sendable, Hashable, Codable {
    struct FontFace: Sendable, Hashable, Codable {
        let family: String
        let style: String?

        static var `default`: Self {
            Self(family: "Arial", style: "Regular")
        }
    }

    var fontFace: FontFace?
    var fontSize: Double?
    var fontFile: URL?
    var horizontalAlignment: HorizontalTextAlignment?
    var verticalAlignment: VerticalTextAlignment?

    init(fontFace: FontFace? = nil, fontSize: Double? = nil, fontFile: URL? = nil, horizontalAlignment: HorizontalTextAlignment? = nil, verticalAlignment: VerticalTextAlignment? = nil) {
        self.fontFace = fontFace
        self.fontSize = fontSize
        self.fontFile = fontFile
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }

    func applyingDefaults() -> Self {
        return Self(
            fontFace: fontFace ?? .default,
            fontSize: fontSize ?? 12,
            fontFile: fontFile,
            horizontalAlignment: horizontalAlignment ?? .left,
            verticalAlignment: verticalAlignment ?? .lastBaseline
        )
    }
}

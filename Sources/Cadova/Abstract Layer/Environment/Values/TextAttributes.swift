import Foundation

internal extension EnvironmentValues {
    private static let key = Key("Cadova.TextAttributes")

    var textAttributes: TextAttributes {
        get { self[Self.key] as? TextAttributes ?? TextAttributes() }
        set { self[Self.key] = newValue }
    }

    mutating func setTextAttributes(_ attributes: TextAttributes) {
        textAttributes = attributes
    }
}

public extension EnvironmentValues {
    var fontFamily: String? { textAttributes.fontFace?.family }
    var fontStyle: String? { textAttributes.fontFace?.style }
    var fontFile: URL? { textAttributes.fontFile }

    mutating func setFont(family: String, style: String? = nil, size: Double? = nil, fontFile: URL? = nil) {
        textAttributes = TextAttributes(
            fontFace: .init(family: family, style: style),
            fontSize: size ?? textAttributes.fontSize,
            fontFile: fontFile
        )
    }

    var fontSize: Double? {
        get { textAttributes.fontSize }
        set {
            textAttributes = TextAttributes(
                fontFace: textAttributes.fontFace,
                fontSize: newValue,
                fontFile: textAttributes.fontFile
            )
        }
    }
}

public extension Geometry {
    func withFont(_ fontFamily: String, style: String? = nil, size: Double? = nil, from fontFile: URL? = nil) -> D.Geometry {
        withEnvironment {
            $0.setFont(family: fontFamily, style: style, size: size, fontFile: fontFile)
        }
    }

    func withFontSize(_ fontSize: Double) -> D.Geometry {
        withEnvironment {
            $0.fontSize = fontSize
        }
    }
}

internal struct TextAttributes: Sendable, Hashable, Codable {
    struct FontFace: Sendable, Hashable, Codable {
        let family: String
        let style: String?

        static var `default`: Self {
            Self(family: "Arial", style: "Regular")
        }
    }

    let fontFace: FontFace?
    let fontSize: Double?
    let fontFile: URL?

    init(fontFace: FontFace? = nil, fontSize: Double? = nil, fontFile: URL? = nil) {
        self.fontFace = fontFace
        self.fontSize = fontSize
        self.fontFile = fontFile
    }

    func setting(attributes: Self) -> Self {
        Self(
            fontFace: attributes.fontFace ?? fontFace,
            fontSize: attributes.fontSize ?? fontSize,
            fontFile: attributes.fontFile ?? fontFile
        )
    }
}

import Foundation
import freetype

public struct Text: Shape2D {
    let content: String

    @Environment private var environment
    @Environment(\.textAttributes) private var textAttributes
    @Environment(\.segmentation) private var segmentation

    public init(_ text: String) {
        self.content = text
    }

    public var body: any Geometry2D {
        let attributes = textAttributes.applyingDefaults()

        CachedNode(name: "text", parameters: content, attributes, segmentation) { environment, context in
            #warning("TODO: handle error")
            do {
                let polygons = try attributes.render(text: content, in: environment)
                return .shape(.polygons(polygons, fillRule: .nonZero))
            } catch {
                fatalError("Error: \(error)")
            }
        }
    }
}

extension TextAttributes {
    func applyingDefaults() -> Self {
        return Self(
            fontFace: fontFace ?? .default,
            fontSize: fontSize ?? 12,
            fontFile: fontFile
        )
    }
}


import Foundation

/// Basic OpenSCAD-generated text
public struct BasicText: LeafGeometry2D {
    let text: String
    let font: Font
    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let characterSpacingFactor: Double

    public init(_ text: String, font: Font, horizontalAlignment: HorizontalAlignment = .left, verticalAlignment: VerticalAlignment = .baseline, spacingFactor: Double = 1) {
        self.text = text
        self.font = font
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.characterSpacingFactor = spacingFactor
    }

    public var invocation: Invocation {
        .init(name: "text", parameters: [
            "text": text,
            "size": font.size,
            "font": font.fontString,
            "halign": horizontalAlignment.rawValue,
            "valign": verticalAlignment.rawValue,
            "spacing": characterSpacingFactor
        ])
    }

    public func boundary(in environment: Environment) -> Bounds {
        // We don't know this.
        .empty
    }

    public struct Font {
        public let name: String
        public let size: Double
        public let style: String?

        public init(name: String, size: Double, style: String? = nil) {
            self.name = name
            self.size = size
            self.style = style
        }

        fileprivate var fontString: String {
            if let style = style {
                return name + ":style=" + style
            } else {
                return name
            }
        }
    }

    public enum HorizontalAlignment: String {
        case left
        case center
        case right
    }

    public enum VerticalAlignment: String {
        case top
        case center
        case baseline
        case bottom
    }
}

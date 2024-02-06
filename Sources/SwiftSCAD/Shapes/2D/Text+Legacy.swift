import Foundation

#if canImport(AppKit)
import AppKit

extension Text {
    @available(*, deprecated, message: "Use one of the modern Text initializers instead")
    public init(_ text: String, font: LegacyFont, alignment: (NSTextAlignment, Text.VerticalAlignment) = (.left, .baseline), spacingFactor: Double = 1) {

        self.init(
            text,
            layout: .free,
            font: font.font,
            horizontalAlignment: alignment.0,
            verticalAlignment: alignment.1,
            attributes: AttributeContainer().kern(spacingFactor)
        )
    }

    public struct LegacyFont {
        public let name: String
        public let size: Double
        public let style: String?

        public init(name: String, size: Double, style: String? = nil) {
            self.name = name
            self.size = size
            self.style = style
        }

        fileprivate var font: Text.Font? {
            if let style {
                return .inFamily(name, style: style, size: size)
            } else {
                return .named(name, size: size)
            }
        }
    }
}

public extension Text.VerticalAlignment {
    @available(*, deprecated, message: "Use .firstBaseline or .lastBaseline instead")
    static var baseline: Self { lastBaseline }
}
#endif

import Foundation
import AppKit

public struct Text: Shape2D {
    private let text: AttributedString
    private let layout: Layout
    private let attributes: Attributes

    private init(
        text: AttributedString,
        layout: Layout,
        font: Font?,
        horizontalAlignment: NSTextAlignment,
        verticalAlignment: Text.VerticalAlignment?,
        customAttributes: AttributeContainer?
    ) {
        self.text = text
        self.layout = layout
        let defaultVerticalAlignment: Text.VerticalAlignment = layout == .free ? .lastBaseline : .top

        self.attributes = .init(
            font: font,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment ?? defaultVerticalAlignment,
            customAttributes: customAttributes
        )
    }

    public init(
        _ text: AttributedString,
        layout: Layout = .free,
        font: Font? = nil,
        horizontalAlignment: NSTextAlignment = .left,
        verticalAlignment: Text.VerticalAlignment? = nil
    ) {
        self.init(
            text: text,
            layout: layout,
            font: font,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            customAttributes: nil
        )
    }

    public init(
        markdown markdownString: String,
        options: AttributedString.MarkdownParsingOptions = .init(),
        layout: Layout = .free,
        font: Font? = nil,
        horizontalAlignment: NSTextAlignment = .left,
        verticalAlignment: Text.VerticalAlignment? = nil,
        attributes: AttributeContainer? = nil
    ) throws {
        try self.init(
            text: .init(markdown: markdownString, options: options),
            layout: layout,
            font: font, horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            customAttributes: attributes
        )
    }

    public init(
        _ string: String,
        layout: Layout = .free,
        font: Font? = nil,
        horizontalAlignment: NSTextAlignment = .left,
        verticalAlignment: Text.VerticalAlignment? = nil,
        attributes: AttributeContainer? = nil
    ) {
        self.init(
            text: .init(string),
            layout: layout,
            font: font,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            customAttributes: attributes
        )
    }

    public var body: Geometry2D {
        content()
    }
}

public extension Text {
    var _debugLineFragments: Geometry2D {
        guard let (_, _, fragments, transform) = layoutData() else {
            return Empty()
        }

        let colors: [Color.Name] = [.red, .green, .blue]

        return Union {
            for (index, fragment) in fragments.enumerated() {
                let rectangle = Rectangle(.init(fragment.rect.width, fragment.rect.height))
                rectangle.subtracting {
                    rectangle.offset(amount: -0.01, style: .miter)
                }
                .translated(.init(fragment.rect.origin))
                .colored(colors[index % colors.count])

                let usedRectangle = Rectangle(.init(fragment.usedRect.width, fragment.usedRect.height))
                usedRectangle.subtracting {
                    usedRectangle.offset(amount: -0.005, style: .miter)
                }
                .translated(.init(fragment.usedRect.origin))
                .colored(.black)
            }
        }
        .transformed(transform)
    }
}

fileprivate extension Text {
    var textContainerSize: CGSize {
        switch layout {
        case .constrained(let width, let height):
            return .init(width: width, height: height ?? .infinity)
        case .free:
            return .init(width: 100000, height: CGFloat.infinity)
        }
    }

    var containerHeight: Double? {
        if case .constrained(_, let height) = layout {
            return height
        } else {
            return 0
        }
    }

    func textOffset(contentHeight: CGFloat, firstBaselineOffset: CGFloat, lastBaselineOffset: CGFloat) -> Vector2D {
        var offset = Vector2D.zero
        let boxHeight = containerHeight ?? contentHeight

        switch attributes.verticalAlignment {
        case .bottom:
            offset.y = contentHeight
        case .middle:
            offset.y = (boxHeight + contentHeight) / 2.0
        case .firstBaseline:
            offset.y = firstBaselineOffset
        case .lastBaseline:
            offset.y = contentHeight - lastBaselineOffset
        default:
            offset.y = boxHeight
        }

        if case .free = layout {
            switch attributes.horizontalAlignment {
            case .center:
                offset.x = -textContainerSize.width / 2
            case .right:
                offset.x = -textContainerSize.width
            default:
                break
            }
        }

        return offset
    }

    func layoutData() -> (NSLayoutManager, NSTextStorage, [NSLayoutManager.LineFragment], AffineTransform2D)? {
        guard !text.characters.isEmpty else {
            return nil
        }

        let textStorage = NSTextStorage(attributedString: .init(effectiveAttributedString))

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: textContainerSize)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        layoutManager.textStorage = textStorage

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else {
            return nil
        }

        let fragments = layoutManager.lineFragments(for: textContainer)

        let contentHeight = fragments.last?.rect.maxY ?? 0
        let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: textStorage.length - 1)
        let lastBaselineOffset = layoutManager.typesetter.baselineOffset(in: layoutManager, glyphIndex: lastGlyphIndex)

        let firstFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
        let firstBaselineOffset = firstFragmentRect.maxY - layoutManager.typesetter.baselineOffset(in: layoutManager, glyphIndex: 0)

        let offset = textOffset(contentHeight: contentHeight, firstBaselineOffset: firstBaselineOffset, lastBaselineOffset: lastBaselineOffset)
        let transform = AffineTransform2D.scaling(y: -1).translated(offset)

        return (layoutManager, textStorage, fragments, transform)
    }

    func content() -> Geometry2D {
        guard let (layoutManager, textStorage, fragments, transform) = layoutData() else {
            return Empty()
        }

        var verticalFlip = CGAffineTransform(scaleX: 1, y: -1)

        return Union {
            for fragment in fragments {
                for glyphIndex in fragment.glyphs {
                    let glyph = layoutManager.cgGlyph(at: glyphIndex)
                    let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

                    let font = textStorage.attribute(.font, at: characterIndex, effectiveRange: nil) as? NSFont
                    let color = textStorage.attribute(.foregroundColor, at: characterIndex, effectiveRange: nil) as? NSColor

                    if let font, let path = CTFontCreatePathForGlyph(font, glyph, &verticalFlip) {
                        let geometry = path
                            .translated(.init(layoutManager.location(forGlyphAt: glyphIndex)))
                            .translated(.init(fragment.rect.origin))

                        if let color, let scadColor = Color(color) {
                            Color2D(color: scadColor, content: geometry)
                        } else {
                            geometry
                        }
                    }
                }
            }
        }
        .transformed(transform)
        .usingCGPathFillRule(.evenOdd)
    }

    var effectiveAttributedString: AttributedString {
        text.mergingAttributes(attributes.stringAttributes, mergePolicy: .keepCurrent)
    }
}

public extension Text {
    enum Layout: Equatable {
        case free
        case constrained (width: Double, height: Double? = nil)
    }
}

fileprivate extension NSLayoutManager {
    struct LineFragment {
        let glyphs: Range<Int>
        let rect: CGRect
        let usedRect: CGRect
    }

    func lineFragments(for textContainer: NSTextContainer) -> [LineFragment] {
        var fragments: [LineFragment] = []
        enumerateLineFragments(forGlyphRange: glyphRange(for: textContainer)) { rect, usedRect, textContainer, glyphRange, _ in
            guard let range = Range(glyphRange) else {
                assertionFailure("Invalid glyph range")
                return
            }
            fragments.append(LineFragment(glyphs: range, rect: rect, usedRect: usedRect))
        }
        return fragments
    }
}

fileprivate extension Color {
    init?(_ nsColor: NSColor) {
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return nil
        }
        self = .components(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: rgb.alphaComponent)
    }
}

fileprivate extension Text.Attributes {
    var stringAttributes: AttributeContainer {
        var attributes = AttributeContainer()
        attributes.font = (font ?? .default).nsFont

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = horizontalAlignment
        attributes.paragraphStyle = paragraphStyle

        if let customAttributes {
            attributes.merge(customAttributes, mergePolicy: .keepNew)
        }

        return attributes
    }
}


extension Text {
    fileprivate struct Attributes {
        var font: Text.Font?

        var horizontalAlignment: NSTextAlignment
        var verticalAlignment: VerticalAlignment

        var customAttributes: AttributeContainer?
    }

    public enum VerticalAlignment: Equatable {
        case top
        case middle
        case bottom

        case firstBaseline
        case lastBaseline
    }

    public struct Font {
        fileprivate let nsFont: NSFont

        fileprivate static var `default`: Font {
            Font(nsFont: NSFont(name: "Helvetica", size: 12) ?? .systemFont(ofSize: 12))
        }

        public static func named(_ name: String, size: CGFloat) -> Font? {
            guard let font = NSFont(name: name, size: size) else {
                assertionFailure("Could not find font named \(name)")
                return nil
            }
            return .init(nsFont: font)
        }

        public static func inFamily(_ family: String, style: String, size: CGFloat) -> Font? {
            let descriptor = NSFontDescriptor()
                .withFamily(family)
                .withFace(style)
            guard let font = NSFont(descriptor: descriptor, size: size) else {
                assertionFailure("Could not find font with family \(family) and style \(style)")
                return nil
            }
            return .init(nsFont: font)
        }

        public static func inFamily(_ family: String, weight: NSFont.Weight, size: CGFloat) -> Font? {
            guard let font = NSFont.font(family: family, weight: weight, size: size) else {
                assertionFailure("Could not find font with family \(family) and weight \(weight)")
                return nil
            }
            return .init(nsFont: font)
        }
    }
}


fileprivate extension NSFont {
    static func font(family: String, weight targetWeight: NSFont.Weight, size: CGFloat) -> NSFont? {
        fontsInFamily(family, size: size)?
            .compactMap { (font: NSFont) -> (font: NSFont, distance: CGFloat)? in
                guard let weight = font.weight, !font.fontDescriptor.symbolicTraits.contains(.italic) else {
                    return nil
                }
                return (font, abs(targetWeight - weight))
            }
            .sorted(by: { $0.distance < $1.distance })
            .first?.font
    }

    var weight: NSFont.Weight? {
        guard let traits = fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any] else {
            return nil
        }
        guard let weight = traits[.weight] as? CGFloat else {
            return nil
        }
        return .init(weight)

    }

    static func fontsInFamily(_ family: String, size: CGFloat) -> [NSFont]? {
        let names = NSFontManager.shared.availableMembers(ofFontFamily: family)?.compactMap { $0[0] as? String }
        guard let names else {
            return nil
        }

        return names.compactMap { NSFont(name: $0, size: size) }
    }
}

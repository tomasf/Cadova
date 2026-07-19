/// Enables Xcode's color literal syntax (`#colorLiteral(red:green:blue:alpha:)`), which the source
/// editor renders as an interactive color swatch, to resolve directly to `Color`.
///
/// `_ExpressibleByColorLiteral` is an underscored (unofficial) stdlib protocol, so this isn't a
/// guaranteed-stable API. It's kept in its own file for exactly that reason: if a future Swift
/// version removes it, this file will fail to compile on its own and can simply be deleted.
///
public typealias _ColorLiteralType = Color

extension Color: _ExpressibleByColorLiteral {
    public init(_colorLiteralRed red: Float, green: Float, blue: Float, alpha: Float) {
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

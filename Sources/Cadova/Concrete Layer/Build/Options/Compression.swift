import Foundation

public extension ModelOptions {
    /// Sets the compression level to be used when exporting 3MF model files.
    ///
    /// - Parameter level: The desired compression level.
    /// - Returns: A `ModelOptions` value representing the chosen compression level.
    static func compression(_ level: Compression) -> Self { .init(level) }

    /// Compression level options for 3MF model export.
    enum Compression: Sendable, ModelOptionItem {
        /// Good compression while remaining fast. This is the default setting.
        case standard

        /// Optimized for fastest compression. Produces larger files but saves time.
        case fastest

        /// Optimized for smallest file size. Slower to compress but minimizes output size.
        case smallest

        internal static let defaultValue = Self.standard
        internal func combined(with other: Self) -> Self { other }
    }
}

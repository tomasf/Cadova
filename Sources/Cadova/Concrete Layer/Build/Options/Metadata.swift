import Foundation

/// Descriptive information embedded in exported model files.
///
/// Use `Metadata` within a ``Model`` or ``Project`` to attach attribution, licensing,
/// and other descriptive fields to the output file. The 3MF format supports all of these
/// fields; other formats may ignore them or support only a subset.
///
/// ```swift
/// await Model("my-part") {
///     Metadata(title: "Widget", author: "Jane Doe", license: "MIT")
///     Box(10)
/// }
/// ```
///
public struct Metadata: Sendable {
    /// A short title for the model.
    let title: String?

    /// A longer description providing context or usage notes.
    let description: String?

    /// The name of the creator or designer.
    let author: String?

    /// A license string indicating usage or redistribution terms.
    let license: String?

    /// A date string, typically in ISO 8601 format.
    let date: String?

    /// An identifier or URL of the application that generated the model.
    let application: String?

    /// Creates metadata with the specified fields.
    ///
    /// - Parameters:
    ///   - title: A short title for the model.
    ///   - description: A longer description providing context or usage notes.
    ///   - author: The name of the creator or designer.
    ///   - license: A license string indicating usage or redistribution terms.
    ///   - date: A date string, typically in ISO 8601 format.
    ///   - application: An identifier or URL of the application that generated the model.
    ///
    public init(
        title: String? = nil,
        description: String? = nil,
        author: String? = nil,
        license: String? = nil,
        date: String? = nil,
        application: String? = nil
    ) {
        self.title = title
        self.description = description
        self.author = author
        self.license = license
        self.date = date
        self.application = application
    }
}

extension Metadata: ModelOptionItem {
    static var defaultValue: Metadata {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        return .init(title: nil, description: nil, author: nil, license: nil,
                     date: dateFormatter.string(from: .now),
                     application: "Cadova, https://cadova.org/"
        )
    }

    func combined(with other: Metadata) -> Metadata {
        .init(
            title: other.title ?? title,
            description: other.description ?? description,
            author: other.author ?? author,
            license: license ?? other.license,
            date: date ?? other.date,
            application: application ?? other.application
        )
    }

}

public extension ModelOptions {
    /// Attaches metadata to the exported model file.
    ///
    /// This method allows you to embed descriptive metadata into the model file, such as title, author, license,
    /// and more. These fields can be useful for attribution, versioning, or documentation purposes.
    ///
    /// > Note: The inclusion and usage of metadata depends on the output file format. The 3MF format supports all of
    /// these fields, while other formats may ignore them entirely or support only a subset.
    ///
    /// - Parameters:
    ///   - title: A short title for the model.
    ///   - description: A longer description providing context or usage notes.
    ///   - author: The name of the creator or designer of the model.
    ///   - license: A license string indicating how the model may be used or redistributed.
    ///   - date: A date string (usually in ISO 8601 format) to indicate when the model was created or last updated.
    ///   - application: An identifier or URL of the application that generated the model.
    /// - Returns: A `ModelOptions` value containing the specified metadata.
    static func metadata(title: String? = nil,
                         description: String? = nil,
                         author: String? = nil,
                         license: String? = nil,
                         date: String? = nil,
                         application: String? = nil
    ) -> Self {
        .init(Metadata(
            title: title,
            description: description,
            author: author,
            license: license,
            date: date,
            application: application
        ))
    }
}

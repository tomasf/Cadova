import Foundation

internal struct Metadata: Sendable {
    let title: String?
    let description: String?
    let author: String?
    let license: String?
    let date: String?
    let application: String?

    init(title: String?, description: String?, author: String?, license: String?, date: String?, application: String?) {
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
    static func metadata(title: String? = nil,
                         description: String? = nil,
                         author: String? = nil,
                         license: String? = nil,
                         date: String? = nil,
                         application: String? = nil
    ) -> Self {
        .init(Metadata(title: title, description: description, author: author, license: license, date: date, application: application))
    }
}

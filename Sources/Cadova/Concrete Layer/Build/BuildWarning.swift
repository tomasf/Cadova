import Foundation

public enum BuildWarning {
    case onlyModifier
    case undefinedAnchors (Set<Anchor>)
    case undefinedTags (Set<Tag>)

    public var description: String {
        switch self {
        case .onlyModifier:
            return "Model uses only() modifier; saving a partial geometry tree"

        case .undefinedAnchors (let anchors):
            return "Undefined anchors: \(anchors)"

        case .undefinedTags (let tags):
            return "Undefined tags: \(tags)"
        }
    }
}

extension BuildResult {
    var buildWarnings: [BuildWarning] {
        var warnings: [BuildWarning] = []
        let referenceState = elements[ReferenceState.self]

        if !referenceState.undefinedTags.isEmpty {
            warnings.append(.undefinedTags(referenceState.undefinedTags))
        }
        if !referenceState.undefinedAnchors.isEmpty {
            warnings.append(.undefinedAnchors(referenceState.undefinedAnchors))
        }
        if hasOnly {
            warnings.append(.onlyModifier)
        }
        return warnings
    }
}

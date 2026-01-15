import Foundation

internal struct ReferenceState: ResultElement {
    private(set) var definedAnchors: [Anchor: Set<Transform3D>]
    private(set) var usedAnchors: Set<Anchor>

    private(set) var definedTags: [Tag: [BuildResult<D3>]]
    private(set) var usedTags: Set<Tag>

    private init(
        definedAnchors: [Anchor: Set<Transform3D>] = [:],
        usedAnchors: Set<Anchor> = [],
        definedTags: [Tag: [BuildResult<D3>]] = [:],
        usedTags: Set<Tag> = []
    ) {
        self.definedAnchors = definedAnchors
        self.usedAnchors = usedAnchors
        self.definedTags = definedTags
        self.usedTags = usedTags
    }

    init() {
        self.init(definedAnchors: [:])
    }

    init(combining elements: [ReferenceState]) {
        self.init(
            definedAnchors: elements.map(\.definedAnchors).reduce(into: [:]) {
                $0.merge($1) { $0.union($1) }
            },
            usedAnchors: elements.reduce([]) { $0.union($1.usedAnchors) },
            definedTags: elements.map(\.definedTags).reduce(into: [:]) {
                $0.merge($1) { $0 + $1 }
            },
            usedTags: elements.reduce([]) { $0.union($1.usedTags) }
        )
    }
}

extension ReferenceState {
    mutating func define(anchor: Anchor, at transform: Transform3D) {
        definedAnchors[anchor, default: []].insert(transform)
    }

    mutating func read(anchor: Anchor) -> Set<Transform3D> {
        usedAnchors.insert(anchor)
        return definedAnchors[anchor] ?? []
    }

    var undefinedAnchors: Set<Anchor> {
        usedAnchors.subtracting(definedAnchors.keys)
    }
}

extension ReferenceState {
    mutating func define(tag: Tag, as buildResult: BuildResult<D3>) {
        definedTags[tag, default: []].append(buildResult)
    }

    @discardableResult
    mutating func read(tag: Tag) -> [BuildResult<D3>] {
        usedTags.insert(tag)
        return definedTags[tag] ?? []
    }

    var undefinedTags: Set<Tag> {
        usedTags.subtracting(definedTags.keys)
    }
}

extension ReferenceState {
    var hasUsedReferences: Bool { !usedAnchors.isEmpty || !usedTags.isEmpty }

    func definesReferences(usedIn otherState: ReferenceState) -> Bool {
        otherState.usedAnchors.intersection(definedAnchors.keys).count > 0 || otherState.usedTags.intersection(definedTags.keys).count > 0
    }
}

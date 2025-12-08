import Foundation
import Manifold3D

// This internal environment value is used to inject references (anchors and tags) upstream

internal extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.UpstreamReferences")

    fileprivate struct UpstreamReferences {
        let anchors: [Anchor: Set<Transform3D>]
        let tags: [Tag: [BuildResult<D3>]]
    }

    fileprivate var upstreamReferences: UpstreamReferences? {
        get { self[Self.environmentKey] as? UpstreamReferences }
        set { self[Self.environmentKey] = newValue }
    }

    func withDefinedReferences(_ referenceState: ReferenceState) -> Self {
        setting(key: Self.environmentKey, value: UpstreamReferences(
            anchors: referenceState.definedAnchors,
            tags: referenceState.definedTags
        ))
    }

    func transforms(for anchor: Anchor) -> Set<Transform3D> {
        upstreamReferences?.anchors[anchor] ?? []
    }

    func buildResults(for tag: Tag) -> [BuildResult<D3>] {
        upstreamReferences?.tags[tag] ?? []
    }
}

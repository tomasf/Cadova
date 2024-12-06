internal extension Boundary {
    enum MergeStrategy {
        case union
        case boxIntersection
        case first
        case minkowskiSum
        case custom (([Boundary]) -> Boundary)

        func apply(_ bounds: [Boundary]) -> Boundary {
            switch self {
            case .union:
                .union(bounds)
            case .boxIntersection:
                bounds.compactMap(\.boundingBox)
                    .reduce { $0.intersection(with: $1) ?? .zero }
                    .map { Boundary(boundingBox: $0) }
                ?? .empty
            case .first:
                bounds.first ?? .empty
            case .minkowskiSum:
                bounds.reduce { $0.minkowskiSum($1) } ?? .empty
            case .custom (let function):
                function(bounds)
            }
        }
    }
}

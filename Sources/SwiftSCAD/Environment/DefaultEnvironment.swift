import Foundation

public extension Environment {
    static var defaultEnvironment: Environment {
        Environment()
            .withFacets(.defaults)
    }
}

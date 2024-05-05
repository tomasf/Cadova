import Foundation

internal extension Environment {
    static var defaultEnvironment: Environment {
        Environment()
            .withFacets(.defaults)
    }
}

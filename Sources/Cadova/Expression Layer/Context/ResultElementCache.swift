import Foundation

actor ResultElementCache {
    internal var entries: [OpaqueKey: ResultElements] = [:]

    func setResultElements(_ resultElements: ResultElements?, for key: OpaqueKey) {
        entries[key] = resultElements
    }
}

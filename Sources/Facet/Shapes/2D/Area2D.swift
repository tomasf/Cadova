import Foundation

public protocol Area2D {
    var area: Double { get }
    func pyramidVolume(height: Double) -> Double
}

public extension Area2D {
    func pyramidVolume(height: Double) -> Double {
        return (area * height) / 3.0
    }
}

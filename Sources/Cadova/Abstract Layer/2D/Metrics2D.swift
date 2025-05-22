import Foundation

public protocol Area {
    var area: Double { get }
}

public protocol Perimeter {
    var perimeter: Double { get }
}

public extension Area {
    func pyramidVolume(height: Double) -> Double {
        return (area * height) / 3.0
    }
}

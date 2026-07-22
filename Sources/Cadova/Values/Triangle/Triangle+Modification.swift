import Foundation

public extension Triangle {
    /// Returns a new triangle where `a` is set to `newA`, uniformly scaling all sides so angles remain unchanged.
    func withA(_ newA: Double) -> Triangle {
        precondition(newA.isFinite && newA > 0, "newA must be a positive, finite number")
        let scale = newA / a
        return Triangle(
            a: newA,
            b: b * scale,
            c: c * scale,
            alpha: alpha,
            beta: beta,
            gamma: gamma
        )
    }

    /// Returns a new triangle where `b` is set to `newB`, uniformly scaling all sides so angles remain unchanged.
    func withB(_ newB: Double) -> Triangle {
        precondition(newB.isFinite && newB > 0, "newB must be a positive, finite number")
        let scale = newB / b
        return Triangle(
            a: a * scale,
            b: newB,
            c: c * scale,
            alpha: alpha,
            beta: beta,
            gamma: gamma
        )
    }

    /// Returns a new triangle where `c` is set to `newC`, uniformly scaling all sides so angles remain unchanged.
    func withC(_ newC: Double) -> Triangle {
        precondition(newC.isFinite && newC > 0, "newC must be a positive, finite number")
        let scale = newC / c
        return Triangle(
            a: a * scale,
            b: b * scale,
            c: newC,
            alpha: alpha,
            beta: beta,
            gamma: gamma
        )
    }
}

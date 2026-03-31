import Testing
@testable import Cadova

struct ShapingFunctionTests {
    let builtins: [ShapingFunction] = [
        .linear,
        .exponential(2),
        .exponential(0.5),
        .easeIn,
        .easeOut,
        .easeInOut,
        .easeInCubic,
        .easeOutCubic,
        .easeInOutCubic,
        .smoothstep,
        .smootherstep,
        .circularEaseIn,
        .circularEaseOut,
        .sine,
        .bezier([0.25, 0.1], [0.25, 1.0]),
    ]

    @Test func `all built-in shaping functions map 0 to 0 and 1 to 1`() {
        for f in builtins {
            #expect(f(0.0) ≈ 0.0, "f(0) should be 0 for \(f)")
            #expect(f(1.0) ≈ 1.0, "f(1) should be 1 for \(f)")
        }
    }
}

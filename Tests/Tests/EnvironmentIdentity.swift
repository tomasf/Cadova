import Foundation
import Testing
@testable import Cadova

/// `EnvironmentValues.id` is the token `whileCurrent` uses to decide whether the task-local
/// binding can be reused. If it fails to change on a mutation, nested builders silently read a
/// stale environment, so these tests pin down exactly when it must and must not change.
struct EnvironmentIdentityTests {
    @Test func `separately created environments have distinct identities`() {
        let a = EnvironmentValues()
        let b = EnvironmentValues()
        #expect(a.id != b.id)
    }

    @Test func `copying an environment preserves its identity`() {
        let original = EnvironmentValues()
        let copy = original
        #expect(copy.id == original.id)
    }

    @Test func `writing through the subscript changes the identity`() {
        var environment = EnvironmentValues()
        let before = environment.id
        environment[EnvironmentValues.Key("Test.Key")] = 42
        #expect(environment.id != before)
    }

    @Test func `removing a value through the subscript changes the identity`() {
        let key = EnvironmentValues.Key("Test.Key")
        var environment = EnvironmentValues()
        environment[key] = 42
        let before = environment.id
        environment[key] = nil
        #expect(environment.id != before)
    }

    @Test func `writing through a key path changes the identity`() {
        var environment = EnvironmentValues()
        let before = environment.id
        environment.tolerance = 0.5
        #expect(environment.id != before)
    }

    @Test func `setting returns an environment with a new identity`() {
        let environment = EnvironmentValues()
        let derived = environment.setting(key: EnvironmentValues.Key("Test.Key"), value: 42)
        #expect(derived.id != environment.id)
    }

    // The behavioral consequence of the invariants above: if a mutation failed to change the
    // identity, whileCurrent would treat the mutated environment as already current, skip the
    // rebinding, and reads inside would see the outer environment's values instead.
    @Test func `a nested environment rebinds so reads see the inner values`() async {
        let outer = EnvironmentValues().setting(key: .init("Test.Unused"), value: 0)
        var inner = outer
        inner.tolerance = 0.5

        let observed = await outer.whileCurrent {
            // The explicit `async` picks the async overload, the only one that consults `id` to
            // decide whether to skip rebinding. The synchronous overload always rebinds, so it
            // would pass this test no matter what `id` did.
            await inner.whileCurrent { () async -> Double in
                EnvironmentValues.current.tolerance
            }
        }
        #expect(observed == 0.5)
    }

    @Test func `an unchanged environment stays current when nested in itself`() async {
        var environment = EnvironmentValues()
        environment.tolerance = 0.25

        let observed = await environment.whileCurrent {
            await environment.whileCurrent { () async -> Double in
                EnvironmentValues.current.tolerance
            }
        }
        #expect(observed == 0.25)
    }
}

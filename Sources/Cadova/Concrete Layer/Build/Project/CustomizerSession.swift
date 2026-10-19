#if os(WASI)
import Foundation
import WASILibc
@_spi(ExperimentalCustomExecutors) import _Concurrency

/// Keeps a model executable running between a customizer's requests, so that each build reuses the
/// geometry cache of the ones before it, the way reusing a ``ModelFileGenerator`` does.
///
/// A customizer asks for a session by setting `CADOVA_CUSTOMIZER_SESSION`. The executable handles
/// the request it was started with as usual, but if that succeeds, it then ends with the status
/// ``suspendedStatus`` rather than exiting, which leaves the WebAssembly instance, and everything
/// in its memory, in place. For each further request, the customizer writes the request to the
/// same file and calls the exported `cadova_customizer_request` function, which returns the status
/// the executable would otherwise have exited with.
///
/// A failure that ends the process while handling a request still does, so the customizer has to
/// start a new instance after any other exit or trap.
///
/// This is a contract between Cadova and its customizer page, not a public interface.
internal final class CustomizerSession: @unchecked Sendable {
    /// The status the executable reports instead of exiting, once it's ready for further requests.
    static let suspendedStatus: Int32 = 51920

    private let build: ProjectBuild
    private let context = EvaluationContext()

    // Accessed only by the executable's single thread
    nonisolated(unsafe) private static var current: CustomizerSession?
    nonisolated(unsafe) private static var isWaiting = false

    private init(build: ProjectBuild) {
        self.build = build
    }

    /// Whether the customizer that started the executable asked for a session.
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["CADOVA_CUSTOMIZER_SESSION"] != nil
    }

    /// Handles the request the executable was started with, then suspends the executable to wait for
    /// more, or exits if that request failed.
    static func start(_ build: ProjectBuild) async -> Never {
        let session = CustomizerSession(build: build)
        let status = await session.handleRequest()
        guard status == EXIT_SUCCESS else { exit(status) }
        current = session
        suspendOnExit()
        await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
        fatalError("A customizer session's main task is never resumed")
    }

    /// Suspends the executable to wait for more requests once it ends, rather than right away, so
    /// that every standalone model in it gets to handle the request it was started with. Each
    /// standalone model calls this once it has. If the request failed in any of them, the
    /// executable exits instead.
    static func suspendAtExit(_ build: ProjectBuild, failed: Bool) {
        startFailed = startFailed || failed
        if current == nil {
            current = CustomizerSession(build: build)
        }
        // Again for each model, since the latest registration is the one that has to come after
        // the C++ destructors of whatever the models before it set up
        suspendOnExit()
    }

    // Whether the request the executable was started with failed in a standalone model
    nonisolated(unsafe) private static var startFailed = false

    // Once nothing is left to run, the executor exits the process, and that's when control can
    // return to the customizer. This handler is registered after every C++ destructor, so it runs
    // first, and _Exit then skips them, keeping the session's state intact. An exit while a request
    // is being handled is a real one, so it goes ahead normally.
    private static func suspendOnExit() {
        atexit {
            guard CustomizerSession.isWaiting else { return }
            fflush(nil)
            _Exit(CustomizerSession.startFailed ? EXIT_FAILURE : CustomizerSession.suspendedStatus)
        }
        isWaiting = true
    }

    /// Handles a request written after the executable suspended, and returns its exit status.
    static func handleNextRequest() -> Int32 {
        guard let session = current else {
            logger.error("A customizer request arrived without a customizer session")
            return EXIT_FAILURE
        }
        return runToCompletion { await session.handleRequest() } ?? EXIT_FAILURE
    }

    /// Prunes the session's cache to about the given size, removing what was used least recently. The
    /// customizer does this once it has a request's output, so that pruning doesn't delay it.
    static func pruneCache(toApproximateByteCount byteCount: Int) {
        guard let session = current else { return }
        runToCompletion { await session.context.pruneCache(toApproximateByteCount: byteCount) }
    }

    /// An estimate of how much memory the session's cache takes up, in bytes.
    static var approximateCacheByteCount: Int {
        guard let session = current else { return 0 }
        return runToCompletion { await session.context.approximateCacheByteCount } ?? 0
    }

    // The exports are called from outside any task, so they run the executor until their work is done
    @discardableResult
    private static func runToCompletion<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> T? {
        isWaiting = false
        defer {
            isWaiting = true
            fflush(nil)
        }

        let outcome = Outcome<T>()
        Task {
            outcome.value = await operation()
        }
        do {
            try MainActor.executor.runUntil { outcome.value != nil }
        } catch {
            logger.error("Failed to run a customizer session's work: \(error.descriptiveString)")
            return nil
        }
        return outcome.value
    }

    private func handleRequest() async -> Int32 {
        guard let request = try? CustomizerRequest.readFromEnvironment() else { return EXIT_FAILURE }
        let failures = await CustomizerRequest.$overridden.withValue(request) {
            await build.run(request: request, context: context)
        }
        return ProjectBuild.reportSuccess(failureCount: failures) ? EXIT_SUCCESS : EXIT_FAILURE
    }

    private final class Outcome<T>: @unchecked Sendable {
        var value: T?
    }
}

// WebAssembly exports have to be global functions
@_expose(wasm, "cadova_customizer_request")
@_cdecl("cadova_customizer_request")
func cadovaCustomizerRequest() -> Int32 {
    CustomizerSession.handleNextRequest()
}

@_expose(wasm, "cadova_customizer_prune_cache")
@_cdecl("cadova_customizer_prune_cache")
func cadovaCustomizerPruneCache(_ byteCount: Int) {
    CustomizerSession.pruneCache(toApproximateByteCount: byteCount)
}

@_expose(wasm, "cadova_customizer_cache_byte_count")
@_cdecl("cadova_customizer_cache_byte_count")
func cadovaCustomizerCacheByteCount() -> Int {
    CustomizerSession.approximateCacheByteCount
}
#endif

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

        // Once nothing is left to run, the executor exits the process, and that's when control can
        // return to the customizer. This handler is registered after every C++ destructor, so it
        // runs first, and _Exit then skips them, keeping the session's state intact. An exit while
        // a request is being handled is a real one, so it goes ahead normally.
        atexit {
            guard CustomizerSession.isWaiting else { return }
            fflush(nil)
            _Exit(CustomizerSession.suspendedStatus)
        }
        isWaiting = true
        await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
        fatalError("A customizer session's main task is never resumed")
    }

    /// Handles a request written after the executable suspended, and returns its exit status.
    static func handleNextRequest() -> Int32 {
        guard let session = current else {
            logger.error("A customizer request arrived without a customizer session")
            return EXIT_FAILURE
        }
        isWaiting = false
        defer {
            isWaiting = true
            fflush(nil)
        }

        // The export is called from outside any task, so run the executor here until the request is done
        let outcome = Outcome()
        Task {
            outcome.status = await session.handleRequest()
        }
        do {
            try MainActor.executor.runUntil { outcome.status != nil }
        } catch {
            logger.error("Failed to run the customizer request: \(error.descriptiveString)")
            return EXIT_FAILURE
        }
        return outcome.status ?? EXIT_FAILURE
    }

    private func handleRequest() async -> Int32 {
        guard let request = try? CustomizerRequest.readFromEnvironment() else { return EXIT_FAILURE }
        let failures = await CustomizerRequest.$overridden.withValue(request) {
            await build.run(request: request, context: context)
        }
        return ProjectBuild.reportSuccess(failureCount: failures) ? EXIT_SUCCESS : EXIT_FAILURE
    }

    private final class Outcome: @unchecked Sendable {
        var status: Int32?
    }
}

// WebAssembly exports have to be global functions
@_expose(wasm, "cadova_customizer_request")
@_cdecl("cadova_customizer_request")
func cadovaCustomizerRequest() -> Int32 {
    CustomizerSession.handleNextRequest()
}
#endif

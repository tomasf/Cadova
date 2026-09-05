import Foundation

/// One thing that went wrong while building a ``Model``, a ``Group`` or a `Project`.
///
/// A failure never stops the rest of the build: the models that can be built still are, and every
/// failure is collected into the ``BuildOutcome`` the build returns.
public struct BuildFailure: Error, Sendable, CustomStringConvertible {
    /// What the build was doing when it failed.
    public enum Stage: Sendable, Hashable {
        /// Assembling the model's geometry tree and deciding which output format it takes.
        case evaluating

        /// Producing the output file's contents and saving them to disk.
        ///
        /// Output providers generate their contents on demand, so an error in the geometry itself
        /// usually surfaces here rather than in ``evaluating``.
        case writing

        /// Creating the directory that output files are written to.
        case creatingDirectory
    }

    /// The stage of the build that failed.
    public let stage: Stage

    /// The name of the model that failed, prefixed with the names of the groups containing it, or
    /// `nil` when the failure isn't attributable to a single model.
    public let modelName: String?

    /// The file or directory involved, when the failure happened late enough for it to be known.
    public let url: URL?

    /// The error that caused the failure.
    public let underlyingError: any Error

    internal init(stage: Stage, modelName: String?, url: URL?, underlyingError: any Error) {
        self.stage = stage
        self.modelName = modelName
        self.url = url
        self.underlyingError = underlyingError
    }

    public var description: String {
        let subject = modelName.map { "model \"\($0)\"" } ?? "model"
        let action = switch stage {
        case .evaluating: "Failed to build \(subject)"
        case .writing: "Failed to write \(subject)" + (url.map { " to \($0.path)" } ?? "")
        case .creatingDirectory: "Failed to create output directory" + (url.map { " \($0.path)" } ?? "")
        }
        return "\(action): \(underlyingError.descriptiveString)"
    }
}

extension BuildFailure: LocalizedError {
    public var errorDescription: String? { description }
}

/// The result of building a ``Model``, a ``Group`` or a `Project`.
///
/// Everything that could be built was; anything that couldn't is listed in ``failures``. See
/// ``BuildFailureBehavior`` for what happens to the process when ``failures`` isn't empty.
public struct BuildOutcome: Sendable {
    /// The output files that this build created and that didn't exist beforehand.
    ///
    /// Files that were overwritten are deliberately left out: this is what gets revealed in the
    /// Finder or the file manager, and a file that's already open in a viewer doesn't need
    /// pointing out again.
    public let createdFiles: [URL]

    /// Everything that went wrong, in no particular order.
    public let failures: [BuildFailure]

    /// Whether the whole build succeeded.
    public var succeeded: Bool { failures.isEmpty }

    internal init(createdFiles: [URL] = [], failures: [BuildFailure] = []) {
        self.createdFiles = createdFiles
        self.failures = failures
    }

    internal init(combining outcomes: some Sequence<BuildOutcome>) {
        createdFiles = outcomes.flatMap(\.createdFiles)
        failures = outcomes.flatMap(\.failures)
    }
}

internal extension BuildOutcome {
    /// Ends a top-level build, applying the current ``BuildFailureBehavior`` to any failures. Under
    /// the default behavior that means ending the process, which is what the name says out loud.
    ///
    /// Called by `Project` and by a standalone ``Model``, and by nothing in between: a group's
    /// failures belong to the project that contains it.
    func terminateIfFailed() {
        guard failures.isEmpty == false else { return }

        logger.error("Build failed with \(failures.count) error\(failures.count == 1 ? "" : "s").")

        if BuildFailureBehavior.current == .terminateProcess {
            exit(EXIT_FAILURE)
        }
    }
}

internal extension FileManager {
    /// Creates a build's output directory, reporting a failure instead of throwing one.
    ///
    /// Without this directory there is nowhere for any of the models below it to go, so the failure
    /// belongs to the directory and is reported once, rather than once per model that then can't be
    /// saved into it.
    func createOutputDirectory(at url: URL, modelName: String?) -> BuildFailure? {
        do {
            try createDirectory(at: url, withIntermediateDirectories: true)
            return nil
        } catch {
            let failure = BuildFailure(
                stage: .creatingDirectory, modelName: modelName, url: url, underlyingError: error
            )
            logger.error("\(failure)")
            return failure
        }
    }
}

/// What ``Model`` and `Project` do when part of a build fails.
///
/// ``Model`` and `Project` are the entry points of a command-line model program, so by default a
/// failed build ends that program with a non-zero exit status. That's the only signal a shell, a
/// Makefile or a CI job can act on; a log line isn't one, and neither is the returned
/// ``BuildOutcome``, since nothing obliges the caller to look at it.
///
/// Choose ``report`` when Cadova is embedded in a program that has to stay alive — although an
/// application or a server is usually better served by ``ModelFileGenerator``, which reports every
/// failure by throwing.
///
/// ```swift
/// let outcome = await BuildFailureBehavior.report.whileCurrent {
///     await Project(root: outputDirectory) {
///         await Model("widget") { Widget() }
///     }
/// }
/// for failure in outcome.failures {
///     presentToUser(failure)
/// }
/// ```
public enum BuildFailureBehavior: Sendable, Hashable {
    /// Log the failures and end the process with a non-zero exit status once the build has
    /// finished. This is the default.
    case terminateProcess

    /// Log the failures and return normally, leaving them to the caller to act on through the
    /// returned ``BuildOutcome``.
    ///
    /// A standalone ``Model`` has no return value to carry an outcome, so under this behavior its
    /// failures are only logged.
    case report

    /// The behavior in effect for the current task.
    @TaskLocal public static var current: BuildFailureBehavior = .terminateProcess

    /// Runs `body` with this behavior in effect.
    public func whileCurrent<T>(_ body: () async throws -> T) async rethrows -> T {
        try await Self.$current.withValue(self, operation: body)
    }
}

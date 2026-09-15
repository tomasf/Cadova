import Foundation

/// What a `Project` does when part of its build fails.
///
/// `Project` is the entry point of a command-line model program, so by default a failed build ends
/// that program with a non-zero exit status. That status is the only thing a shell, a Makefile or a
/// CI job can act on. A logged error is not, since nothing obliges the caller to read it.
///
/// Choose ``report`` when Cadova is embedded in a program that has to stay alive, although such a
/// program is usually better served by ``ModelFileGenerator``.
///
/// ```swift
/// await BuildFailureBehavior.report.whileCurrent {
///     await Project {
///         await Model("part") { Box(10) }
///     }
/// }
/// ```
public enum BuildFailureBehavior: Sendable, Hashable {
    /// Log the failures and end the process with a non-zero exit status once the build has
    /// finished. This is the default.
    case terminateProcess

    /// Log the failures and return normally.
    case report

    /// The behavior in effect for the current task.
    @TaskLocal public static var current: BuildFailureBehavior = .terminateProcess

    /// Runs `body` with this behavior in effect.
    public func whileCurrent<T>(_ body: () async throws -> T) async rethrows -> T {
        try await Self.$current.withValue(self, operation: body)
    }
}

internal extension BuildFailureBehavior {
    /// Ends a build that reported a failure, applying the behavior in effect.
    ///
    /// Called once, by the `Project` that started the build. A failure is logged where it happens,
    /// so this only says how many there were and what to do about them.
    static func endBuild(failureCount: Int) {
        guard failureCount > 0 else { return }

        logger.error("Build failed with \(failureCount) error\(failureCount == 1 ? "" : "s").")

        if current == .terminateProcess {
            exit(EXIT_FAILURE)
        }
    }
}

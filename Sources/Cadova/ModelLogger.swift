import Foundation

/// Logs the steps of building one model. Every line names the model, so with several models built at once, each
/// line shows which one it's about.
internal struct ModelLogger: Sendable {
    let modelName: String?

    /// The model being built. Set for the whole build, so everything it runs, including the tasks it starts, logs
    /// through it; outside a build, lines name no model.
    @TaskLocal static var current = ModelLogger(modelName: nil)

    private func prefixed(_ message: Logger.Message) -> Logger.Message {
        Logger.Message(stringLiteral: modelName.map { "[\($0)] \(message.value)" } ?? message.value)
    }

    func debug(_ message: @autoclosure () -> Logger.Message) {
        logger.debug(prefixed(message()))
    }

    func info(_ message: @autoclosure () -> Logger.Message) {
        logger.info(prefixed(message()))
    }

    func warning(_ message: @autoclosure () -> Logger.Message) {
        logger.warning(prefixed(message()))
    }

    func error(_ message: @autoclosure () -> Logger.Message) {
        logger.error(prefixed(message()))
    }

    // The steps of a model's build

    func generating() {
        info("Generating...")
    }

    func buildWarning(_ buildWarning: BuildWarning) {
        warning("\(buildWarning)")
    }

    func builtAndEvaluated(in duration: Duration) {
        debug("Built and evaluated geometry in \(duration.logDescription)")
    }

    func noGeometry() {
        error("No geometry")
    }

    func evaluationFailed(_ failure: any Error) {
        error("Cadova caught an error while evaluating the model:\n\(failure)\n")
    }

    func wrote(to url: URL) {
        info("Wrote model to \(url.path)")
    }

    func failedToSave(to url: URL, _ failure: any Error) {
        error("Failed to save model file to \(url.path): \(failure.descriptiveString)")
    }

    func skippedLiveLinkPush(for url: URL, because reason: String) {
        debug("Skipped live link push for \(url.lastPathComponent): \(reason)")
    }

    func pushedToViewer() {
        info("Pushed to Cadova Viewer")
    }

    func generated3MF(triangleCount: Int, in duration: Duration) {
        debug("Generated 3MF file with \(triangleCount) triangles in \(duration.logDescription)")
    }

    func exportingEmpty3MF() {
        warning("Model contains no objects. Exporting an empty 3MF file.")
    }
}

internal extension Duration {
    /// The duration rounded for reading in a log: milliseconds below a second, with a decimal below ten, and
    /// seconds with two decimals above
    var logDescription: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let milliseconds = seconds * 1000
        if milliseconds < 10 { return String(format: "%.1f ms", milliseconds) }
        if milliseconds < 1000 { return String(format: "%.0f ms", milliseconds) }
        return String(format: "%.2f s", seconds)
    }
}

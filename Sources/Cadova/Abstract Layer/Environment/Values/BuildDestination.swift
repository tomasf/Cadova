import Foundation

/// Where the result of a build is going.
///
/// Read it with `@Environment(\.buildDestination)` to make a model differ between the places it's
/// built for. A model usually looks the same everywhere, so that what you see is what you print, but
/// sometimes presenting it calls for something printing doesn't. A sign that prints face down, for
/// example, can face the viewer in a customizer's preview:
///
/// ```swift
/// @Environment(\.buildDestination) var destination
///
/// Sign()
///     .rotated(x: destination == .customizerPreview ? 0° : 180°)
/// ```
///
/// Keep such differences few and obvious, since a customizer's visitors expect the file they
/// download to be what they saw.
///
public enum BuildDestination: Sendable, Hashable {
    /// A model file written by running the model package, such as with `swift run`.
    case file

    /// The live 3D preview in a web customizer.
    case customizerPreview

    /// A model file that a web customizer's visitor downloads.
    case customizerDownload
}

public extension EnvironmentValues {
    static fileprivate let buildDestinationKey = Key("Cadova.BuildDestination")

    /// Where the result of the current build is going.
    ///
    /// This is ``BuildDestination/file`` unless a web customizer is building the model. See
    /// ``BuildDestination`` for how to use it.
    ///
    var buildDestination: BuildDestination {
        self[Self.buildDestinationKey] as? BuildDestination ?? .file
    }
}

internal extension EnvironmentValues {
    /// Sets where the build is going. Models can read it but not change it.
    mutating func setBuildDestination(_ destination: BuildDestination) {
        self[Self.buildDestinationKey] = destination
    }
}

internal extension BuildDestination {
    /// The destination of the builds a customizer request asks for. Listing parameters belongs with
    /// the preview, since the page shows the parameters next to it.
    init(request: CustomizerRequest?) {
        switch request {
        case nil: self = .file
        case let request? where request.preview || request.parameterListPath != nil: self = .customizerPreview
        default: self = .customizerDownload
        }
    }
}

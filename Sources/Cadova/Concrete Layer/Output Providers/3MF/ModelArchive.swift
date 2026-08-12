import Foundation

/// Write access to the archive while it's being generated, along with the geometry it was generated
/// from and the means to measure it.
///
/// Passed to closures registered with ``Geometry/withArchiveFinalizer(_:)``, which run after the
/// model and its meshes have been written but before the archive is sealed.
@_spi(ArchiveFinalizer) public struct ModelArchive: Sendable {
    /// The entire geometry this archive was built from, as a single 3D geometry.
    ///
    /// This is the finished model: everything the archive contains, after all boolean operations,
    /// transforms and modifiers in the tree have been applied, and with every part's content
    /// attached. Reading it through ``evaluator`` costs nothing beyond the read itself; the geometry
    /// is already built, so no part of the tree is evaluated a second time.
    ///
    /// Models built from 2D geometry are represented by their extruded 3D form, the same shape
    /// written into the archive.
    public let rootGeometry: any Geometry3D

    /// An evaluator for reading derived values from ``rootGeometry`` or any other geometry in scope.
    ///
    /// Its reads share the export's evaluation context and cache, so measuring geometry that was
    /// already built for the archive doesn't rebuild it. See ``GeometryEvaluator`` for the available
    /// reads.
    ///
    /// ```swift
    /// .withArchiveFinalizer { archive in
    ///     let bounds = await archive.evaluator.bounds(of: archive.rootGeometry) ?? .zero
    ///     try archive.addFile(at: "Metadata/size.txt", data: Data("\(bounds.size)".utf8))
    /// }
    /// ```
    public let evaluator: GeometryEvaluator

    private let objectIDsByPart: [Part: Int]
    private let resultElements: ResultElements
    private let addFileHandler: @Sendable (String, String?, String?, Bool, Data) throws -> Void
    private let fileExistsHandler: @Sendable (String) -> Bool

    internal init(
        rootGeometry: any Geometry3D,
        evaluator: GeometryEvaluator,
        objectIDsByPart: [Part: Int],
        resultElements: ResultElements,
        addFileHandler: @escaping @Sendable (String, String?, String?, Bool, Data) throws -> Void,
        fileExistsHandler: @escaping @Sendable (String) -> Bool
    ) {
        self.rootGeometry = rootGeometry
        self.evaluator = evaluator
        self.objectIDsByPart = objectIDsByPart
        self.resultElements = resultElements
        self.addFileHandler = addFileHandler
        self.fileExistsHandler = fileExistsHandler
    }
}

@_spi(ArchiveFinalizer) public extension ModelArchive {
    /// The 3MF item id assigned to `part`'s object in the file being written, if the part was included
    /// in the output.
    func objectID(for part: Part) -> Int? {
        objectIDsByPart[part]
    }

    /// Every part included in the output. Use ``objectID(for:)`` to look up each one's 3MF item id.
    var parts: Set<Part> {
        Set(objectIDsByPart.keys)
    }

    /// The given result element, merged across the entire geometry tree that produced this archive.
    /// The same value any point in the tree would see reading this element directly.
    ///
    /// Useful when a finalizer needs to see data contributed from many places in the tree (not just
    /// wherever it itself happened to be attached).
    func resultElement<E: ResultElement>(_ type: E.Type) -> E {
        resultElements[E.self]
    }

    /// Whether a file has already been added to the archive at the given path.
    ///
    /// Since finalizers may be registered redundantly from several places in a geometry tree (see
    /// ``Geometry/withArchiveFinalizer(_:)``), check this before adding a file whose content is
    /// assembled from tree-wide data (via ``resultElement(_:)``): adding the same path twice doesn't
    /// throw — the second write silently replaces the first — so without this check, whichever
    /// finalizer happens to run last would win, rather than all of them contributing consistently.
    func fileExists(at path: String) -> Bool {
        fileExistsHandler(path)
    }

    /// Embeds a file into the archive at the given path, replacing any existing content there.
    ///
    /// - Parameters:
    ///   - path: The file's path within the archive (e.g. `"Metadata/model_settings.config"`).
    ///   - contentType: The file's MIME type, registered in the archive's content types. Pass `nil`
    ///     (the default) to leave it unregistered — plenty of slicer-specific sidecar files aren't,
    ///     and most 3MF readers don't require it, but a properly OPC-compliant file should set this.
    ///   - relationshipType: An OPC relationship type to record for this file, if any.
    ///   - relativeToRootModel: Whether the relationship (if any) is scoped to the root model file
    ///     rather than the package as a whole. Ignored when `relationshipType` is `nil`.
    ///   - data: The file's contents.
    func addFile(
        at path: String,
        contentType: String? = nil,
        relationshipType: String? = nil,
        relativeToRootModel: Bool = false,
        data: Data
    ) throws {
        try addFileHandler(path, contentType, relationshipType, relativeToRootModel, data)
    }
}

internal enum ModelArchiveError: Error {
    case invalidArchivePath(String)
}

internal struct ArchiveFinalizers: ResultElement {
    // Keyed by an id generated once per `withArchiveFinalizer` call (not per execution), so reusing
    // the same geometry value at several points in a tree — which carries the same id along with it,
    // being a plain value — collapses back to one registration instead of running redundantly once
    // per occurrence. Genuinely separate calls get distinct ids and all run, same as before.
    var finalizers: [UUID: @Sendable (ModelArchive) async throws -> Void]

    init() { finalizers = [:] }
    init(combining elements: [ArchiveFinalizers]) {
        finalizers = elements.reduce(into: [:]) { result, element in
            result.merge(element.finalizers) { existing, _ in existing }
        }
    }
}

@_spi(ArchiveFinalizer) public extension Geometry {
    /// Registers a closure that runs while this geometry's 3MF archive is being generated, after the
    /// model and its meshes have been written but before the archive is sealed, with the chance to
    /// add extra files to it.
    ///
    /// The closure can be attached anywhere in a geometry tree, including deep inside a helper
    /// function. It always runs once per exported archive, regardless of nesting. Multiple
    /// registrations from different calls to this method (e.g. on separate components) accumulate
    /// rather than replace one another; reusing the same already-finalizer-attached geometry value
    /// at more than one point in the tree does not run its finalizer more than once.
    ///
    /// Ignored when exporting to other formats (e.g. STL).
    ///
    /// The closure is asynchronous, so it can read from the finished model through the archive's
    /// ``ModelArchive/evaluator`` while assembling the file it adds:
    ///
    /// ```swift
    /// .withArchiveFinalizer { archive in
    ///     let bounds = await archive.evaluator.bounds(of: archive.rootGeometry) ?? .zero
    ///     try archive.addFile(at: "Metadata/size.txt", data: Data("\(bounds.size)".utf8))
    /// }
    /// ```
    ///
    /// - Parameter finalizer: A closure receiving a ``ModelArchive``, used to look up parts'
    ///   assigned object ids, measure the finished geometry, and add files to the archive.
    func withArchiveFinalizer(
        _ finalizer: @Sendable @escaping (ModelArchive) async throws -> Void
    ) -> D.Geometry {
        let id = UUID()
        return modifyingResult(ArchiveFinalizers.self) { $0.finalizers[id] = finalizer }
    }
}

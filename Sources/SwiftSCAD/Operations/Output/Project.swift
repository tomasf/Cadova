import Foundation

/// Save related pieces of geometry to a common root directory
///
/// ## Example
/// ```swift
///Project(root: "~/Projects/Lamp") {
///    Product("base") {
///        lampBase()
///    }
///
///    Product("arm") {
///        lampArm()
///    }
///
///    Product("platter") {
///        lampBase()
///        lampArm()
///            .translated(x: lampBaseDiameter / 2 + 10)
///    }
///
///    Group("views") {
///        Product("base-cross-section") {
///            lampBase()
///                .crossSectioned(axis: .x)
///        }
///        Product("arm-short") {
///            lampArm(length: 30)
///        }
///    }
///}.process()
///```
/// This code produces the following files:
/// * `~/Projects/Lamp/base.scad`
/// * `~/Projects/Lamp/arm.scad`
/// * `~/Projects/Lamp/platter.scad`
/// * `~/Projects/Lamp/views/base-cross-section.scad`
/// * `~/Projects/Lamp/views/arm-short.scad`

public struct Project {
    let root: URL
    let environment: Environment
    let content: [ProjectContent]

    /// Create a project
    /// - Parameters:
    ///   - rootPath: The root directory for the products in this project. The tilde character (`~`) is expanded to your home directory.
    ///   - environment: The default environment to use for geometry
    ///   - content: A result builder generating ``Group``s and ``Product``s
    public init(root rootPath: String, environment: Environment = Environment(), @ProjectContentBuilder content: () -> [ProjectContent]) {
        self.root = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath)
        self.environment = environment
        self.content = content()
    }

    /// Output all contained products
    public func process() {
        let params = ProjectParameters(directory: root, environment: environment)
        try? FileManager().createDirectory(at: root, withIntermediateDirectories: false)

        do {
            for item in self.content {
                try item.process(using: params)
            }
        } catch {
            preconditionFailure("Failed to export project \(self.root): \(error)")
        }
    }
}

/// A group inside a project, collecting related geometry in a subdirectory
public struct Group: ProjectContent {
    let name: String
    let environment: Environment?
    let content: [ProjectContent]

    public init(_ name: String, environment: Environment? = nil, @ProjectContentBuilder content: () -> [ProjectContent]) {
        self.name = name
        self.environment = environment
        self.content = content()
    }

    public func process(using parentParameters: ProjectParameters) throws {
        let newParameters = ProjectParameters(
            directory: parentParameters.directory.appendingPathComponent(name),
            environment: environment ?? parentParameters.environment
        )

        try? FileManager().createDirectory(at: newParameters.directory, withIntermediateDirectories: false)

        for item in content {
            try item.process(using: newParameters)
        }
    }
}

/// A named geometry that exists as part of a ``Project``
public struct Product: ProjectContent {
    let name: String
    let environment: Environment?
    let body: Geometry

    /// Create a product
    /// - Parameters:
    ///   - name: The file name. "`.scad`" is appended to this.
    ///   - environment: The environment to use. If `nil`, the environment of the closest ``Group`` or the ``Project`` is used.
    ///   - body: The geometry to save
    public init(_ name: String, environment: Environment? = nil, @UnionBuilder body: () -> Geometry3D) {
        self.init(name, environment: environment, body: body())
    }

    public init(_ name: String, environment: Environment? = nil, body: Geometry3D) {
        self.name = name
        self.environment = environment
        self.body = body
    }

    public func process(using parameters: ProjectParameters) throws {
        let environment = self.environment ?? parameters.environment

        let outputGeometry: Geometry
        if let body = body as? Geometry3D {
            outputGeometry = body.usingFacets(environment.facets)
        } else if let body = body as? Geometry2D {
            outputGeometry = body.usingFacets(environment.facets)
        } else {
            outputGeometry = body
        }

        let string = outputGeometry.scadString(in: environment)
        var url = parameters.directory.appendingPathComponent(name)
        if url.pathExtension != "scad" {
            url.appendPathExtension("scad")
        }
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}

@resultBuilder public struct ProjectContentBuilder {
    public static func buildBlock(_ components: ProjectContent...) -> [ProjectContent] {
        components
    }
}

public struct ProjectParameters {
    let directory: URL
    let environment: Environment
}

public protocol ProjectContent {
    func process(using parameters: ProjectParameters) throws
}

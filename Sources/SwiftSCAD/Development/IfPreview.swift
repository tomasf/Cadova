import Foundation

struct IfPreview3D: Geometry3D {
    let previewBody: Geometry3D?
    let renderBody: Geometry3D?

    init(ifPreview previewBody: Geometry3D? = nil, ifRender renderBody: Geometry3D? = nil) {
        self.previewBody = previewBody
        self.renderBody = renderBody
    }

    func scadString(in environment: Environment) -> String {
        let previewCode = previewBody?.scadString(in: environment)
        let renderCode = renderBody?.scadString(in: environment)

        if let preview = previewCode, let render = renderCode {
            return "if ($preview) { \(preview) } else { \(render) }"
        } else if let preview = previewCode {
            return "if ($preview) { \(preview) }"
        } else if let render = renderCode {
            return "if (!$preview) { \(render) }"
        } else {
            preconditionFailure("previewBody and renderBody can't both be nil.")
        }
    }
}

public func IfPreview(@UnionBuilder3D _ preview: () -> Geometry3D, @UnionBuilder3D else render: () -> Geometry3D) -> Geometry3D {
    IfPreview3D(ifPreview: preview(), ifRender: render())
}

public func IfPreview(@UnionBuilder3D _ preview: () -> Geometry3D) -> Geometry3D {
    IfPreview3D(ifPreview: preview())
}

public func IfRender(@UnionBuilder3D _ render: () -> Geometry3D, @UnionBuilder3D else preview: () -> Geometry3D) -> Geometry3D {
    IfPreview3D(ifPreview: preview(), ifRender: render())
}

public func IfRender(@UnionBuilder3D _ render: () -> Geometry3D) -> Geometry3D {
    IfPreview3D(ifRender: render())
}


struct IfPreview2D: Geometry2D {
    let previewBody: Geometry2D?
    let renderBody: Geometry2D?

    init(ifPreview previewBody: Geometry2D? = nil, ifRender renderBody: Geometry2D? = nil) {
        self.previewBody = previewBody
        self.renderBody = renderBody
    }

    func scadString(in environment: Environment) -> String {
        let previewCode = previewBody?.scadString(in: environment)
        let renderCode = renderBody?.scadString(in: environment)

        if let preview = previewCode, let render = renderCode {
            return "if ($preview) { \(preview) } else { \(render) }"
        } else if let preview = previewCode {
            return "if ($preview) { \(preview) }"
        } else if let render = renderCode {
            return "if (!$preview) { \(render) }"
        } else {
            preconditionFailure("previewBody and renderBody can't both be nil.")
        }
    }
}

public func IfPreview(@UnionBuilder2D _ preview: () -> Geometry2D, @UnionBuilder2D else render: () -> Geometry2D) -> Geometry2D {
    IfPreview2D(ifPreview: preview(), ifRender: render())
}

public func IfPreview(@UnionBuilder2D _ preview: () -> Geometry2D) -> Geometry2D {
    IfPreview2D(ifPreview: preview())
}

public func IfRender(@UnionBuilder2D _ render: () -> Geometry2D, @UnionBuilder2D else preview: () -> Geometry2D) -> Geometry2D {
    IfPreview2D(ifPreview: preview(), ifRender: render())
}

public func IfRender(@UnionBuilder2D _ render: () -> Geometry2D) -> Geometry2D {
    IfPreview2D(ifRender: render())
}

public extension Geometry2D {
    func ifPreview() -> Geometry2D {
        IfPreview { self }
    }

    func ifRender() -> Geometry2D {
        IfRender { self }
    }
}

public extension Geometry3D {
    func ifPreview() -> Geometry3D {
        IfPreview { self }
    }

    func ifRender() -> Geometry3D {
        IfRender { self }
    }
}

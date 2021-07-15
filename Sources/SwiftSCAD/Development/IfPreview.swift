import Foundation

struct IfPreview3D: Geometry3D {
	let previewBody: Geometry3D
	let renderBody: Geometry3D

	init(ifPreview previewBody: Geometry3D, ifRender renderBody: Geometry3D) {
		self.previewBody = previewBody
		self.renderBody = renderBody
	}

	func scadString(in environment: Environment) -> String {
		let previewCode = previewBody.scadString(in: environment)
		let renderCode = renderBody.scadString(in: environment)
		return "if ($preview) { \(previewCode) } else { \(renderCode) }"
	}
}

public func IfPreview(@UnionBuilder _ preview: () -> Geometry3D, @UnionBuilder ifRender render: () -> Geometry3D = { Empty() }) -> Geometry3D {
	IfPreview3D(ifPreview: preview(), ifRender: render())
}

public func IfRender(@UnionBuilder _ render: () -> Geometry3D, @UnionBuilder ifPreview preview: () -> Geometry3D = { Empty() }) -> Geometry3D {
	IfPreview3D(ifPreview: preview(), ifRender: render())
}


struct IfPreview2D: Geometry2D {
	let previewBody: Geometry2D
	let renderBody: Geometry2D

	init(ifPreview previewBody: Geometry2D, ifRender renderBody: Geometry2D) {
		self.previewBody = previewBody
		self.renderBody = renderBody
	}

	func scadString(in environment: Environment) -> String {
		let previewCode = previewBody.scadString(in: environment)
		let renderCode = renderBody.scadString(in: environment)
		return "if ($preview) { \(previewCode) } else { \(renderCode) }"
	}
}

func IfPreview(@UnionBuilder _ preview: () -> Geometry2D, @UnionBuilder ifRender render: () -> Geometry2D = { Empty() }) -> Geometry2D {
	IfPreview2D(ifPreview: preview(), ifRender: render())
}

func IfRender(@UnionBuilder _ render: () -> Geometry2D, @UnionBuilder ifPreview preview: () -> Geometry2D = { Empty() }) -> Geometry2D {
	IfPreview2D(ifPreview: preview(), ifRender: render())
}

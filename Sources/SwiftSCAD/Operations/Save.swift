import Foundation

fileprivate func saveToFile(string: String, to path: String) {
	let fullPath = (path as NSString).expandingTildeInPath
	do {
		try string.write(toFile: fullPath, atomically: false, encoding: .utf8)
	} catch {
		preconditionFailure("Failed to write to file \(fullPath)")
	}
}

public extension Geometry3D {
	@discardableResult func save(to path: String) -> Geometry3D {
		let string = self.withDefaultFacets().scadString(in: Environment())
		saveToFile(string: string, to: path)
		return self
	}
}

public extension Geometry2D {
	@discardableResult func save(to path: String) -> Geometry2D {
		let string = self.withDefaultFacets().scadString(in: Environment())
		saveToFile(string: string, to: path)
		return self
	}
}

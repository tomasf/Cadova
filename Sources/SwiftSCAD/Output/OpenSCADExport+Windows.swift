#if os(Windows)
import Foundation

// On Windows, we try calling AssocQueryStringW from shlwapi.dll to find what application is associated with the .scad file extension

internal extension OpenSCADExport {
    static func findExecutableAutomatically() -> URL? {
        if let path = associatedExecutable(forExtension: ".scad"), path.range(of: "openscad", options: .caseInsensitive) != nil {
            return URL(filePath: path)
        } else {
            return nil
        }
    }

    @_silgen_name("AssocQueryStringW")
    static func AssocQueryStringW(
        flags: UInt32,
        str: UInt32,
        pszAssoc: UnsafePointer<UInt16>?,
        pszExtra: UnsafePointer<UInt16>?,
        pszOut: UnsafeMutablePointer<UInt16>?,
        pcchOut: UnsafeMutablePointer<UInt32>?
    ) -> UInt32

    static let ASSOCF_NONE: UInt32 = 0
    static let ASSOCSTR_EXECUTABLE: UInt32 = 2

    static func associatedExecutable(forExtension fileExtension: String) -> String? {
        var bufferSize: UInt32 = 0
        let fileExtensionBuffer = Array(fileExtension.utf16) + [0]
        _ = fileExtensionBuffer.withUnsafeBufferPointer { fileExtensionPointer in
            AssocQueryStringW(flags: ASSOCF_NONE, str: ASSOCSTR_EXECUTABLE, pszAssoc: fileExtensionPointer.baseAddress, pszExtra: nil, pszOut: nil, pcchOut: &bufferSize)
        }
        guard bufferSize > 0 else { return nil }

        let resultBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: Int(bufferSize))
        defer {
            resultBuffer.deallocate()
        }

        let result = fileExtensionBuffer.withUnsafeBufferPointer { fileExtensionPointer in
            AssocQueryStringW(flags: ASSOCF_NONE, str: ASSOCSTR_EXECUTABLE, pszAssoc: fileExtensionPointer.baseAddress, pszExtra: nil, pszOut: resultBuffer, pcchOut: &bufferSize
            )
        }

        return result == 0 ? String(decodingCString: resultBuffer, as: UTF16.self) : nil
    }

}

#endif

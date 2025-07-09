import Foundation

struct Platform {
    enum Error: Swift.Error {
        case filePathConversionFailed
        case unsupportedPlatform
        case invalidPIDLClone
        case invalidChildPIDL
    }
}

#if os(macOS)
import AppKit
#endif

#if os(Windows)
import WinSDK

struct WindowsError: Error {
    let hresult: HRESULT

    init(_ hresult: HRESULT) {
        self.hresult = hresult
    }

    var localizedDescription: String {
        "Windows API failed with HRESULT 0x\(String(hresult, radix: 16, uppercase: true))"
    }
}
#endif

extension Platform {
    static func revealFiles(_ urls: [URL]) throws {
        guard !urls.isEmpty else { return }
        
#if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting(urls.map(\.absoluteURL))

#elseif os(Linux)
        let formattedURLs = urls.map { "\"" + $0.absoluteString + "\"" }.joined(separator: ",")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "dbus-send",
            "--session",
            "--dest=org.freedesktop.FileManager1",
            "--type=method_call",
            "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1.ShowItems",
            "array:string:\(formattedURLs)",
            "string:\"\""
        ]
        try process.run()

#elseif os(Windows)
        guard !urls.isEmpty else { return }

        let hrInit = CoInitializeEx(nil, DWORD(COINIT_MULTITHREADED.rawValue))
        guard hrInit == S_OK || hrInit == S_FALSE else {
            throw WindowsError(hrInit)
        }
        defer { CoUninitialize() }

        var parentPIDL: UnsafeMutablePointer<ITEMIDLIST>?
        var childPIDLs: [UnsafeMutablePointer<ITEMIDLIST>] = []

        for url in urls {
            let nativePath = try url.withUnsafeFileSystemRepresentation {
                guard let path = $0 else {
                    throw Error.filePathConversionFailed
                }
                return String(cString: path)
            }

            let widePath: [WCHAR] = Array(nativePath.utf16) + [0]

            var fullPIDL: UnsafeMutablePointer<ITEMIDLIST>?
            let hrParse = SHParseDisplayName(widePath, nil, &fullPIDL, 0, nil)
            guard hrParse == S_OK, let fullPIDLUnwrapped = fullPIDL else {
                throw WindowsError(hrParse)
            }

            // Clone full PIDL and remove last ID to get parent
            guard let parent = ILClone(fullPIDLUnwrapped) else {
                CoTaskMemFree(fullPIDLUnwrapped)
                throw Error.invalidPIDLClone
            }
            ILRemoveLastID(parent)

            // Get last ID for child
            guard ILFindLastID(fullPIDLUnwrapped) != nil else {
                CoTaskMemFree(fullPIDLUnwrapped)
                CoTaskMemFree(parent)
                throw Error.invalidChildPIDL
            }

            if parentPIDL == nil {
                parentPIDL = parent
            } else {
                CoTaskMemFree(parent)
            }

            childPIDLs.append(fullPIDLUnwrapped)
        }

        defer {
            for fullPIDL in childPIDLs {
                CoTaskMemFree(fullPIDL)
            }
            if let parent = parentPIDL {
                CoTaskMemFree(parent)
            }
        }

        var childPIDLArray: [LPCITEMIDLIST?] = childPIDLs.map { LPCITEMIDLIST(ILFindLastID($0)) }
        let hrOpen = childPIDLArray.withUnsafeMutableBufferPointer {
            SHOpenFolderAndSelectItems(parentPIDL, UInt32($0.count), $0.baseAddress, 0)
        }
        guard hrOpen == S_OK else {
            throw WindowsError(hrOpen)
        }
#else
        throw Error.unsupportedPlatform
#endif
    }
}

import Foundation

extension CodeFragment {
    func save(to fileURL: URL, format: any OutputFormat) {
        do {
            let data = if format.openSCADTypeString != nil {
                try OpenSCADExport(inputCode: scadData, outputFormat: format).run()
            } else {
                scadData
            }

            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("\(error.localizedDescription)")
            return
        }
        logger.info("Wrote output to \(fileURL.path)")
    }

    var scadData: Data { Data(scadCode.utf8) }
}


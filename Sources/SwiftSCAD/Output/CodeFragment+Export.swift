import Foundation

extension CodeFragment {
    func save(to fileURL: URL, format: any OutputFormat) {
        if format.openSCADTypeString != nil {
            let operation = OpenSCADExport(inputCode: scadData, outputFormat: format)
            do {
                try operation.run().write(to: fileURL, options: .atomic)
            } catch {
                logger.error("Export failed: \(error.localizedDescription)")
                return
            }
        } else {
            do {
                try scadData.write(to: fileURL, options: .atomic)
            } catch {
                logger.error("Failed to write to file \(fileURL)")
                return
            }
        }
        logger.info("Wrote output to \(fileURL.path)")
    }

    var scadData: Data { Data(scadCode.utf8) }
}


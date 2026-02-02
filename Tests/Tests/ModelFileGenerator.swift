import Foundation
import Testing
@testable import Cadova

struct ModelFileGeneratorTests {

    @Test func `model generator creates valid files`() async throws {

        let generator = ModelFileGenerator()
        let defaultNameModelFile = try await generator.build(options: .format3D(.threeMF)) {
            Box(x: 10, y: 10, z: 5)
        }
        
        #expect(defaultNameModelFile.fileExtension == "3mf")
        #expect(defaultNameModelFile.suggestedFileName == "Model.3mf")
        
        let namedModelFile = try await generator.build(named: "My Cool Model", options: .format3D(.threeMF)) {
            Box(x: 10, y: 10, z: 5)
        }
        
        #expect(namedModelFile.fileExtension == "3mf")
        #expect(namedModelFile.suggestedFileName == "My Cool Model.3mf")
        
        let illegallyNamedModelFile = try await generator.build(named: "/////", options: .format3D(.threeMF)) {
            Box(x: 10, y: 10, z: 5)
        }
        
        #expect(illegallyNamedModelFile.fileExtension == "3mf")
        #expect(illegallyNamedModelFile.suggestedFileName == "Model.3mf")
        
        let partialIllegallyNamedModelFile = try await generator.build(named: "//My Cool Model//", options: .format3D(.threeMF)) {
            Box(x: 10, y: 10, z: 5)
        }
        
        #expect(partialIllegallyNamedModelFile.fileExtension == "3mf")
        #expect(partialIllegallyNamedModelFile.suggestedFileName == "My Cool Model.3mf")
        
        let results = [defaultNameModelFile, namedModelFile, illegallyNamedModelFile, partialIllegallyNamedModelFile]
        
        for result in results {
            let data = try await result.data()
            #expect(!data.isEmpty)
        }
    }
}

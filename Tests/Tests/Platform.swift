import Testing
@testable import Cadova

struct PlatformTests {
    @Test func `CADOVA_REVEAL_FILES false disables automatic file revealing`() {
        #expect(Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "false"]))
        #expect(Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "0"]))
        #expect(Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "no"]))
        #expect(Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "off"]))
    }

    @Test func `CADOVA_REVEAL_FILES defaults to revealing files`() {
        #expect(!Platform.defaultRevealingFilesDisabled(environment: [:]))
        #expect(!Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "true"]))
        #expect(!Platform.defaultRevealingFilesDisabled(environment: ["CADOVA_REVEAL_FILES": "1"]))
    }
}

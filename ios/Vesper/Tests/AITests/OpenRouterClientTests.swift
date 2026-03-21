// OpenRouterClientTests.swift
// Vesper - Unit tests for OpenRouterClient parsing helpers

import XCTest
@testable import Vesper

final class OpenRouterClientTests: XCTestCase {

    func testParseCommandDetailedUnwrapsCodeFencedArrayPayload() {
        let client = OpenRouterClient(settingsStore: SettingsStore())
        let arguments = #"""
        ```json
        [{
          "action": "create_directory",
          "args": {
            "path": "/ext/apps/new_folder"
          },
          "justification": "Create a new folder",
          "expected_effect": "Folder created"
        }]
        ```
        """#

        let parsed = client.parseCommandDetailed(arguments)

        XCTAssertNotNil(parsed.command)
        XCTAssertNil(parsed.error)
        XCTAssertEqual(parsed.command?.action, .createDirectory)
        XCTAssertEqual(parsed.command?.args.path, "/ext/apps/new_folder")
        XCTAssertEqual(parsed.command?.justification, "Create a new folder")
    }

    func testParseCommandDetailedSupportsAliasArguments() {
        let client = OpenRouterClient(settingsStore: SettingsStore())
        let arguments = #"{"action":"execute_command","args":{"command":"version"}}"#

        let parsed = client.parseCommandDetailed(arguments)

        XCTAssertNotNil(parsed.command)
        XCTAssertNil(parsed.error)
        XCTAssertEqual(parsed.command?.action, .executeCli)
        XCTAssertEqual(parsed.command?.args.command, "version")
    }
}

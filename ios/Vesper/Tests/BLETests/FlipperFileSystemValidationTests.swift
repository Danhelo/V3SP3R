// FlipperFileSystemValidationTests.swift
// Vesper - Unit tests for file-system content size validation

import XCTest
@testable import Vesper

final class FlipperFileSystemValidationTests: XCTestCase {

    func testContentSizeLimitMatchesInputValidator() {
        XCTAssertEqual(FlipperFileSystem.maxContentSize, InputValidator.maxContentSizeBytes)
    }

    func testValidateContentSizeAllowsAndroidSizedPayload() throws {
        let payload = Data(repeating: 0x41, count: InputValidator.maxContentSizeBytes)
        XCTAssertNoThrow(try FlipperFileSystem.validateContentSize(payload))
    }

    func testValidateContentSizeRejectsPayloadOverLimit() {
        let payload = Data(repeating: 0x41, count: InputValidator.maxContentSizeBytes + 1)

        XCTAssertThrowsError(try FlipperFileSystem.validateContentSize(payload)) { error in
            guard let flipperError = error as? FlipperException else {
                return XCTFail("Expected FlipperException")
            }

            XCTAssertTrue(flipperError.message.contains("maximum size"))
        }
    }
}

// AuditStoreTests.swift
// Vesper - Unit tests for SwiftData-backed audit persistence

import XCTest
import SwiftData
@testable import Vesper

final class AuditStoreTests: XCTestCase {

    func testAuditStorePersistsAndQueriesEntries() async throws {
        let container = try ModelContainer(for: AuditEntryEntity.self)
        let store = AuditStore(modelContainer: container)

        let entry = AuditEntry(
            actionType: .commandExecuted,
            sessionId: "session-123",
            metadata: ["source": "unit-test"]
        )

        try await MainActor.run {
            try store.log(entry)
        }

        let fetched = try await MainActor.run {
            try store.queryBySession(sessionId: "session-123")
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, entry.id)
        XCTAssertEqual(fetched.first?.metadata["source"], "unit-test")
    }
}

// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing

@testable import datadog_session_replay

@Test
func setsReplayBaggage_WhenSetHasReplay() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = FlutterSessionReplay.Configuration()
    let feature = try FlutterSessionReplayFeature(core: core, configuration: config)

    // When
    let expectedValue: Bool = .mockRandom()
    feature.setHasReplay(expectedValue)

    // Then
    let value = try core.context.baggages["sr_has_replay"]?.encode() as? Bool
    #expect(value == expectedValue)
}

@Test
func setsBackage_WhenSetRecordCount() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = FlutterSessionReplay.Configuration()
    let feature = try FlutterSessionReplayFeature(core: core, configuration: config)

    // When
    let viewId: String = .mockRandom()
    let expectedCount: Int = .mockRandom()
    feature.setRecordCount(for: viewId, count: expectedCount)

    // Then
    let baggage = try core.context.baggages["sr_records_count_by_view_id"]?.encode() as? [String: Any]
    let value = baggage?[viewId] as? Int
    #expect(value == expectedCount)
}

@Test
func setsBackage_WhenSetRecordCount_MultipleViews() throws {
    // Given
    let core = PassthroughCoreMock()
    let config = FlutterSessionReplay.Configuration()
    let feature = try FlutterSessionReplayFeature(core: core, configuration: config)

    // When
    let viewIdA: String = .mockRandom()
    let viewIdB: String = .mockRandom()
    let expectedCountA: Int = .mockRandom()
    let expectedCountB: Int = .mockRandom()
    feature.setRecordCount(for: viewIdA, count: expectedCountA)
    feature.setRecordCount(for: viewIdB, count: expectedCountB)

    // Then
    let baggage = try core.context.baggages["sr_records_count_by_view_id"]?.encode() as? [String: Any]
    let valueA = baggage?[viewIdA] as? Int
    #expect(valueA == expectedCountA)
    let valueB = baggage?[viewIdB] as? Int
    #expect(valueB == expectedCountB)
}

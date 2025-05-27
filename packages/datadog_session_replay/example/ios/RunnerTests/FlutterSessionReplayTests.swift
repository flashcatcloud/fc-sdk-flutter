// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import Testing
import DatadogInternal

@testable import datadog_session_replay

@Test
func decodeConfigurationCorrectly() {
    // Given
    let encodedConfiguration = [
        "customEndpoint": "https://example.com"
    ]

    // When
    let configuration = FlutterSessionReplay.Configuration(fromEncoded: encodedConfiguration)

    // Then
    #expect(configuration?.customEndpoint == URL(string: "https://example.com"))
}

@Test
func enableRegistersToCore() {
    // Given
    let config: FlutterSessionReplay.Configuration = .init()
    let mockCore = PassthroughCoreMock()

    // When
    let createdFeature = FlutterSessionReplay.enable(with: config, in: mockCore)

    // Then
    let feature = mockCore.get(feature: FlutterSessionReplayFeature.self)
    #expect(feature != nil)
    #expect(feature === createdFeature)
}

@Test
func writeSegmentWritesWrappedSegmentToCore() {
    // Given
    let config: FlutterSessionReplay.Configuration = .init()
    let mockCore = PassthroughCoreMock()
    let createdFetaure = FlutterSessionReplay.enable(with: config, in: mockCore)

    // When
    let mockSegment = "{}"
    createdFetaure?.writeSegment(segment: mockSegment)

    // Then
    let events: [RecordWrapper] = mockCore.events()
    #expect(events.count == 1)
    #expect(events[0].recordJson == mockSegment)
}

@Test
func changeInRumContextCallOnContextChanged() throws {
    // Given
    var config: FlutterSessionReplay.Configuration = .init()
    var recievedContext: RUMCoreContext?
    config.onContextChanged = { context in
        recievedContext = context
    }
    let mockCore = PassthroughCoreMock()
    _ = FlutterSessionReplay.enable(with: config, in: mockCore)

    // When
    let expectedRumContext: RUMCoreContext = .mockRandom()
    var datadogContext: DatadogContext = .mockRandom()
    datadogContext.set(additionalContext: expectedRumContext)

    mockCore.send(message: .context(datadogContext), else: {})

    // Then
    #expect(recievedContext != nil)
    #expect(recievedContext == expectedRumContext)
}

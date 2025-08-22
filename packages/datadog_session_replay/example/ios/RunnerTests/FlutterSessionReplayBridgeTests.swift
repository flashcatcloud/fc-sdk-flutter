//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import DatadogInternal
@testable import datadog_session_replay

extension FlutterSessionReplay {
    func enable(withMock mock: FlutterSessionReplayFeatureMock) {
        feature = mock
    }
}

@Suite(.serialized)
class FlutterSessionReplayBridgeTests {
    @Test
    func enableRegistersToCore() throws {
        // Given
        let mockCore = PassthroughCoreMock()
        CoreRegistry.unregisterDefault()
        CoreRegistry.register(default: mockCore)

        let config: FlutterSessionReplayConfiguration = .init()
        let flutterSessionReplay: FlutterSessionReplay = .init()

        // When
        flutterSessionReplay.enable(with: config)

        // Then
        let feature = mockCore.get(feature: DefaultFlutterSessionReplayFeature.self)
        #expect(feature != nil)
    }

    @Test
    func changeInRumContextCallOnContextChanged() throws {
        // Given
        let mockCore = PassthroughCoreMock()
        CoreRegistry.unregisterDefault()
        CoreRegistry.register(default: mockCore)

        var recievedContext: FlutterRUMCoreContext?
        let config: FlutterSessionReplayConfiguration = .init { context in
            recievedContext = context
        }
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(with: config)

        // When
        let expectedRumContext: RUMCoreContext = .mockRandom()
        var datadogContext: DatadogContext = .mockRandom()
        datadogContext.set(additionalContext: expectedRumContext)

        mockCore.send(message: .context(datadogContext), else: {})

        // Then
        #expect(recievedContext != nil)
        #expect(recievedContext?.applicationID == expectedRumContext.applicationID)
        #expect(recievedContext?.viewID == expectedRumContext.viewID)
        #expect(recievedContext?.sessionID == expectedRumContext.sessionID)
    }

    @Test
    func writeSegment_WritesToFeature() throws {
        // Given
        let mockFeature = FlutterSessionReplayFeatureMock()
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(withMock: mockFeature)

        // When
        let mockSegment = "{}"
        flutterSessionReplay.writeSegment(segment: mockSegment)

        // Then
        try #require(mockFeature.writtenSegments.count == 1)
        #expect(mockFeature.writtenSegments[0] == mockSegment)
    }

    @Test
    func setHasReplay_WritesToFeature() {
        // Given
        let mockFeature = FlutterSessionReplayFeatureMock()
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(withMock: mockFeature)

        // When
        let value: Bool = .mockRandom()
        flutterSessionReplay.setHasReplay(hasReplay: value)

        // Then
        #expect(mockFeature.hasReplay == value)
    }

    @Test
    func setRecordCount_WritesToFeature() {
        // Given
        let mockFeature = FlutterSessionReplayFeatureMock()
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(withMock: mockFeature)

        // When
        let key: String = .mockRandom()
        let count: Int = .mockRandom()
        flutterSessionReplay.setRecordCount(for: key, count: count)

        // Then
        #expect(mockFeature.recordCount[key] == Int64(count))
    }

    @Test
    func saveImageForProcessing_CallsThroughToResourceResolver() throws {
        // Given
        let mockFeature = FlutterSessionReplayFeatureMock()
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(withMock: mockFeature)

        // When
        let key: Int = .mockRandom()
        let width: Int = .mockRandom()
        let height: Int = .mockRandom()
        let data: Data = Data()

        flutterSessionReplay.saveImageForProcessing(resourceKey: key, width: width, height: height, data: data)

        // Then
        let mockResolver = mockFeature.resourceResolver as! ResourceResolverMock
        try #require(mockResolver.trackedResources.count == 1)
        #expect(mockResolver.trackedResources[0].key == key)
        #expect(mockResolver.trackedResources[0].width == width)
        #expect(mockResolver.trackedResources[0].height == height)
        #expect(mockResolver.trackedResources[0].data == data)
    }

    @Test
    func resourceIdForKey_CallsThroughToResourceResolver() {
        // Given
        let mockFeature = FlutterSessionReplayFeatureMock()
        let flutterSessionReplay: FlutterSessionReplay = .init()
        flutterSessionReplay.enable(withMock: mockFeature)

        let mockResolver = mockFeature.resourceResolver as! ResourceResolverMock
        let mockKey: Int = .mockRandom()
        let resourceId: String = .mockRandom()
        mockResolver.trackedResources.append(
            ResourceResolverMock.TrackedResource(
                key: mockKey,
                width: .mockRandom(),
                height: .mockRandom(),
                data: Data(),
                resourceId: resourceId
            )
        )

        // When
        let id = flutterSessionReplay.resourceId(forKey: mockKey)

        // Then
        #expect(id == resourceId)
    }
}

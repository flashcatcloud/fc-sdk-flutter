//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import Flutter
import DatadogInternal

@testable import datadog_session_replay

extension FlutterError: EquatableInTests {

}

func checkResult(_ result: ResultStatus, expectedError: NSObject) {
    switch result {
    case .called(let value):
        #expect((value as? NSObject) === expectedError)
    default:
        #expect(Bool(false), "Unexpected result: \(result)")
    }
}

func checkResult(_ result: ResultStatus, errorCode: String, errorMessage: String) throws {
    switch result {
    case .called(let value):
        let error = value as? FlutterError
        try #require(error != nil, "Unexpected error type: \(type(of: value))")
        #expect(error?.code == errorCode)
        #expect(error?.message == errorMessage)
    default:
        #expect(Bool(false), "Unexpected result: \(result)")
    }
}

@Suite(.serialized)
class SessionReplayPluginTests {
    let mockCore = PassthroughCoreMock()
    let mockChannel = FlutterMethodChannel()

    init() {
        CoreRegistry.register(default: mockCore)
    }

    deinit {
        CoreRegistry.unregisterDefault()
    }

    @Test
    func returnNotImplemented_WhenUnknownMethod() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let arguments: [String: Any] = [:]
        let methodCall = FlutterMethodCall(methodName: "unknown", arguments: arguments)

        // When
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        checkResult(status, expectedError: FlutterMethodNotImplemented)
    }

    @Test
    func returnInvalidOperation_WhenBadArguments() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let methodCall = FlutterMethodCall(methodName: "unknown", arguments: 22)

        // When
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        try checkResult(status, errorCode: "DatadogSdk:InvalidOperation", errorMessage: "No arguments in call to unknown")
    }

    @Test
    func enablesFeature_WhenEnableMethodCall() {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let arguments: [String: Any] = [
            "configuration": [String: Any]()
        ]
        let methodCall = FlutterMethodCall(methodName: "enable", arguments: arguments)

        // When
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        #expect(status == .called(value: true))
        #expect(mockCore.get(feature: FlutterSessionReplayFeature.self) != nil)
    }

    @Test
    func returnsError_WhenEnableMethodCall_MissingConfiguration() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let arguments: [String: Any] = [:]
        let methodCall = FlutterMethodCall(methodName: "enable", arguments: arguments)

        // When
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        try checkResult(status, errorCode: "DatadogSdk:ContractViolation", errorMessage: "Missing parameter in call to enable")
    }

    @Test
    func setsContext_WhenSetHasReplayMethodCall() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let expectedValue: Bool = .mockRandom()
        let arguments: [String: Any] = [
            "hasReplay": expectedValue
        ]
        let methodCall = FlutterMethodCall(methodName: "setHasReplay", arguments: arguments)

        // When
        plugin.enable(configuration: .init())
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        #expect(status == .called(value: nil))
        let value = mockCore.context.additionalContext(ofType: SessionReplayCoreContext.HasReplay.self)
        #expect(value?.value == expectedValue)
    }

    @Test
    func returnsError_WhenSetHasReplayMethodCall_InvalidParameter() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let arguments: [String: Any] = [
            "hasReplay": "true"
        ]
        let methodCall = FlutterMethodCall(methodName: "setHasReplay", arguments: arguments)

        // When
        plugin.enable(configuration: .init())
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        try checkResult(status, errorCode: "DatadogSdk:ContractViolation", errorMessage: "Missing parameter in call to setHasReplay")
    }

    @Test
    func setsContext_WhenSetRecordCountMethodCall() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let expectedValue: Int64 = .mockRandom()
        let expectedViewId: String = .mockRandom()
        let arguments: [String: Any] = [
            "viewId": expectedViewId,
            "count": expectedValue
        ]
        let methodCall = FlutterMethodCall(methodName: "setRecordCount", arguments: arguments)

        // When
        plugin.enable(configuration: .init())
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        #expect(status == .called(value: nil))
        let value = mockCore.context.additionalContext(ofType: SessionReplayCoreContext.RecordsCount.self)
        #expect(value?.value.count == 1)
        #expect(value?.value[expectedViewId] as? Int64 == expectedValue)
    }

    @Test
    func broadcastsRumContext_WhenContextChanges() throws {
        // Given
        let methodChannelMock = FlutterMethodChannelMock()
        let plugin = DatadogSessionReplayPlugin(channel: methodChannelMock)
        plugin.enable(configuration: .init())

        // When
        let expectedRumContext: RUMCoreContext = .mockRandom()
        var datadogContext: DatadogContext = .mockRandom()
        datadogContext.set(additionalContext: expectedRumContext)
        mockCore.send(message: .context(datadogContext), else: {})

        // Then
        // Push to the back of the main queue, as method channel must send
        // callbacks on the main queue
        try DispatchQueue.main.sync {
            try #require(methodChannelMock.invocations.count == 1)
            let argument = methodChannelMock.invocations[0].arguments as? [String: Any?]
            try #require(argument != nil)
            if let argument = argument {
                #expect(argument["applicationId"] as? String == expectedRumContext.applicationID)
                #expect(argument["sessionId"] as? String == expectedRumContext.sessionID)
                #expect(argument["viewId"] as? String == expectedRumContext.viewID)
                #expect(argument["viewServerTimeOffset"] as? TimeInterval == expectedRumContext.viewServerTimeOffset)
            }
        }
    }

    @Test
    func writesSegment_WhenWriteSegment() throws {
        // Given
        let plugin = DatadogSessionReplayPlugin(channel: FlutterMethodChannelMock())
        let segment: String = .mockRandom(length: 100)
        let arguments: [String: Any] = [
            "segment": segment
        ]
        let methodCall = FlutterMethodCall(methodName: "writeSegment", arguments: arguments)

        // When
        plugin.enable(configuration: .init())
        var status: ResultStatus = .notCalled
        plugin.handle(methodCall) { result in
            status = .called(value: result)
        }

        // Then
        #expect(status == .called(value: nil))
        #expect(mockCore.writer.events.count == 1)
        let recordEvent = try #require(mockCore.writer.events[0] as? RecordWrapper)
        #expect(recordEvent.recordJson == segment)
    }
}

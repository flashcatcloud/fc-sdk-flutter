// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import DatadogCore
import DatadogInternal

// Force symbols to be retained during linking
@_silgen_name("__datadog_session_replay_keep_symbols")
public func __datadog_session_replay_keep_symbols() {
    // Reference all classes to prevent dead code elimination
    _ = FlutterRUMCoreContext.self
    _ = FlutterSessionReplayConfiguration.self 
    _ = FlutterSessionReplay.self
}

@objc(FlutterRUMCoreContext) public class FlutterRUMCoreContext: NSObject {
    @objc public var sessionID: String
    @objc public var viewID: String?
    @objc public var applicationID: String

    internal init(sessionID: String, viewID: String?, applicationID: String) {
        self.sessionID = sessionID
        self.viewID = viewID
        self.applicationID = applicationID
        super.init()
    }
}

@objc(FlutterSessionReplayConfiguration) public class FlutterSessionReplayConfiguration: NSObject {
    @objc public var customEndpoint: URL?

    public var onContextChanged: ((FlutterRUMCoreContext?) -> Void)?

    @objc public init(
        customEndpoint: URL? = nil,
        onContextChanged: ((FlutterRUMCoreContext?) -> Void)? = nil
    ) {
        self.customEndpoint = customEndpoint
        self.onContextChanged = onContextChanged
        super.init()
    }    
}

@objc(FlutterSessionReplay) public class FlutterSessionReplay: NSObject {
    var feature: FlutterSessionReplayFeature?

    @objc public func enable(with configuration: FlutterSessionReplayConfiguration) {
        do {
            feature = try enableOrThrow(with: configuration, in: CoreRegistry.default)
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    internal func enableOrThrow(
        with configuration: FlutterSessionReplayConfiguration,
        in core: DatadogCoreProtocol
    ) throws -> FlutterSessionReplayFeature {
        guard !(core is NOPDatadogCore) else {
            throw ProgrammerError(
                description: "Datadog SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        let mappedConfiguration = FlutterSessionReplayFeature.Configuration(
            customEndpoint: configuration.customEndpoint,
            onContextChanged: { context in
                if let context = context {
                    configuration.onContextChanged?(FlutterRUMCoreContext(
                        sessionID: context.sessionID,
                        viewID: context.viewID,
                        applicationID: context.applicationID
                    ))
                } else {
                    configuration.onContextChanged?(nil)
                }
            }
        )

        let sessionReplay = try FlutterSessionReplayFeature(core: core, configuration: mappedConfiguration)
        try core.register(feature: sessionReplay)

        // sessionReplay.writer.startWriting(to: core)

        return sessionReplay
    }

    @objc public func setHasReplay(hasReplay: Bool) {
        feature?.setHasReplay(hasReplay)
    }

    @objc public func setRecordCount(for viewId: String, count: Int) {
        feature?.setRecordCount(for: viewId, count: Int64(count))
    }

    @objc public func writeSegment(segment segmentJson: String) {
        feature?.writeSegment(segment: segmentJson)
    }

    @objc public func postTelemetryDebug(id: String, message: String) {
        Datadog._internal.telemetry.debug(id: "datadog_flutter:\(id)", message: message)
    }

    @objc public func postTelemetryError(message: String, kind: String, stackTrace: String) {
        Datadog._internal.telemetry.error(id: "datadog_flutter:\(String(describing: kind)):\(message)",
                                          message: message, kind: kind, stack: stackTrace)
    }
}

// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Foundation
import DatadogInternal

class FlutterSessionReplayFeature: DatadogRemoteFeature {
    static var name: String = "session-replay"

    let requestBuilder: DatadogInternal.FeatureRequestBuilder
    let messageReceiver: DatadogInternal.FeatureMessageReceiver

    private var core: DatadogCoreProtocol?
    private var featureScope: FeatureScope?

    private var recordCountByViewId: [String: Int] = [:]

    init(
        core: DatadogCoreProtocol,
        configuration: FlutterSessionReplay.Configuration
    ) throws {
        self.core = core
        self.featureScope = core.scope(for: FlutterSessionReplayFeature.self)

        self.requestBuilder = RequestBuilder(
            customUploadURL: configuration.customEndpoint,
            telemetry: core.telemetry
        )

        let contextReciever = RUMContextReceiver()
        if let onContextChanged = configuration.onContextChanged {
            contextReciever.observe(notify: { context in
                onContextChanged(context)
            })
        }
        self.messageReceiver = contextReciever
    }

    func setHasReplay(_ hasReplay: Bool) {
        core?.set(baggage: hasReplay, forKey: RUMDependency.hasReplay)
    }

    func setRecordCount(for viewId: String, count: Int) {
        recordCountByViewId[viewId] = count
        core?.set(baggage: recordCountByViewId, forKey: RUMDependency.recordsCountByViewID)
    }

    func writeSegment(segment: String) {
        let wrapper = RecordWrapper(recordJson: segment)
        featureScope?.eventWriteContext(bypassConsent: true) { _, writer in
            writer.write(value: wrapper)
        }
    }
}

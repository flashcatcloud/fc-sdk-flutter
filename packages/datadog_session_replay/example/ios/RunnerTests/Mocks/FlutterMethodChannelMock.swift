//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Flutter

class FlutterMethodChannelMock: FlutterMethodChannel {
    struct MockInvocation {
        let method: String
        let arguments: Any?
    }

    public var invocations: [MockInvocation] = []

    override func invokeMethod(_ method: String, arguments: Any?) {
        invocations.append(
            .init(method: method, arguments: arguments)
        )
    }

    override func invokeMethod(_ method: String, arguments: Any?, result callback: FlutterResult? = nil) {
        invocations.append(
            .init(method: method, arguments: arguments)
        )
        if let callback = callback {
            callback(nil)
        }
    }

    override func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
        // NOOP
    }

    override func resizeBuffer(_ bufferSize: Int) {
        // NOOP
    }
}

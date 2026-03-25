// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter

public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    private init(messenger: AnyObject) {
        self.messenger = messenger
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger() as AnyObject
        let instance = DatadogSessionReplayPlugin(messenger: messenger)
        // FFI plugins do not receive engine lifecycle events, so we cannot determine
        // which engine called enable() from within the FFI call itself. Instead, after
        // calling enable() via FFI, Dart fires a non-awaited 'claimOwnership' message
        // through this method channel. Because method channels route to the plugin
        // instance for their specific engine, we can reliably associate the enable()
        // call with this engine's messenger and set listenerOwner correctly.
        // See: https://github.com/flutter/flutter/issues/184124
        let channel = FlutterMethodChannel(
            name: "datadog_session_replay/engine",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "claimOwnership" {
            FlutterSessionReplay.claimOwnership(messenger: messenger)
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        // Null out the context callback only if this engine is the registered owner.
        // Prevents a detaching secondary engine from clearing a live engine's callback,
        // which would cause DLRT_GetFfiCallbackMetadata crashes on the next context update.
        FlutterSessionReplay.detachFromEngine(messenger: registrar.messenger() as AnyObject)
    }
}

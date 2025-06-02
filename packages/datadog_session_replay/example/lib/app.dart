// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SessionReplayCapture(
      key: captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Session Replay example app')),
          body: Center(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(width: 2),
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.blueAccent,
              ),
              width: 200.0,
              height: 200.0,
              alignment: Alignment.center,
              child: Text('Running\n'),
            ),
          ),
        ),
      ),
    );
  }
}

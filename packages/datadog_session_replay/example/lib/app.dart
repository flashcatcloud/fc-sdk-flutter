// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/main_screen.dart';
import 'screens/simple_containers_screen.dart';
import 'screens/text_recording_screen.dart';

const Color datadogPurple = Color.fromARGB(255, 99, 44, 166);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final captureKey = GlobalKey();

  final router = GoRouter(
    observers: [DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/simple_containers',
        builder: (context, state) => const SimpleContainersScreen(),
      ),
      GoRoute(
        path: '/text_recording',
        builder: (context, state) => TextRecordingScreen(),
      ),
    ],
  );

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
      child: MaterialApp.router(color: datadogPurple, routerConfig: router),
    );
  }
}

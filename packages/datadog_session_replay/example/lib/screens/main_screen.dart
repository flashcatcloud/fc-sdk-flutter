// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';

@immutable
class _RouteScreen {
  final String title;
  final String route;

  const _RouteScreen(this.title, this.route);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final routes = [
    _RouteScreen('Simple Containers', Routes.simpleContainers),
    _RouteScreen('Text Rendering', Routes.textRecording),
    _RouteScreen('Cupertino Widgets', Routes.cupertinoWidgets),
    _RouteScreen('Material Widgets', Routes.materialWidgets),
    _RouteScreen('Text Fields', Routes.textFieldWidgets),
    _RouteScreen('Slivers', Routes.slivers),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Session Replay Example')),
      body: Center(
        child: ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return InkWell(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        route.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    Icon(Icons.arrow_right_sharp),
                  ],
                ),
              ),
              onTap: () {
                context.push(route.route);
              },
            );
          },
        ),
      ),
    );
  }
}

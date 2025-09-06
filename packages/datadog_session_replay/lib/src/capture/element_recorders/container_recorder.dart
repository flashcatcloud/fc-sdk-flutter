// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';

class ContainerRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const ContainerRecorder(this.keyGenerator);

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    // Material is also considered a container
    if (widget is! ColoredBox &&
        widget is! Material &&
        widget is! DecoratedBox) {
      return null;
    }

    ContainerStyle? style;
    switch (widget) {
      case Material widget:
        style = _captureMaterialStyle(widget, attributes);
        break;
      case ColoredBox widget:
        style = ContainerStyle(backgroundColor: widget.color.toHexString());
        break;
      case DecoratedBox box:
        final decoration = box.decoration;
        style = ContainerStyle.fromDecoration(decoration, attributes);
        style ??= ContainerStyle(backgroundColor: null);
        break;
    }

    final key = keyGenerator.keyForElement(element);
    final node = ContainerNode(attributes, wireframeId: key, style: style!);
    return AmbiguousElement(nodes: [node]);
  }

  ContainerStyle _captureMaterialStyle(
    Material widget,
    CapturedViewAttributes attributes,
  ) {
    Color? backgroundColor = widget.color;

    final surfaceTint = widget.surfaceTintColor;
    if (backgroundColor != null && surfaceTint != null) {
      // TODO: Check for useMaterial3
      backgroundColor = ElevationOverlay.applySurfaceTint(
        backgroundColor,
        surfaceTint,
        widget.elevation,
      );
    }

    final borderStyle = CapturedBorderStyle.fromShapeBorder(
      widget.shape,
      attributes,
    );

    return ContainerStyle(
      backgroundColor: backgroundColor?.toHexString(),
      borderColor: borderStyle?.color,
      borderWidth: borderStyle?.width,
      cornerRadius: borderStyle?.cornerRadius ?? 0.0,
    );
  }
}

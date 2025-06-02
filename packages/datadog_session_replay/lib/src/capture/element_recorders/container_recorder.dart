// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

class ContainerRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const ContainerRecorder(this.keyGenerator);

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final widget = element.widget;
    // Material is also considered a container
    if (widget is! Container && widget is! Material) return null;

    Color? backgroundColor;
    double? cornerRadius;
    double? borderWidth;
    Color? borderColor;
    if (widget is Container) {
      backgroundColor = widget.color;
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        // TODO: TextDirection
        cornerRadius = decoration.borderRadius?.resolve(null).topLeft.x;

        // It is illegal to supply both Container.color and Decoration.color,
        // so overwriting the background color here is okay.
        backgroundColor = decoration.color;
        if (decoration.border case final border?) {
          // TODO: Look into non-uniform borders for SR
          if (border.top.width > 0) {
            borderWidth = border.top.width;
            borderColor = border.top.color;
          } else if (border.bottom.width > 0) {
            borderWidth = border.bottom.width;
            borderColor = border.bottom.color;
          }
        }
      }
    }

    final key = keyGenerator.keyForElement(element);
    final node = _ContainerNode(
      attributes,
      wireframeId: key,
      backgroundColor: backgroundColor,
      borderWidth: borderWidth,
      borderColor: borderColor,
      cornerRadius: cornerRadius ?? 0,
    );
    return AmbiguousElement(nodes: [node]);
  }
}

@immutable
class _ContainerNode extends CaptureNode {
  final int wireframeId;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double cornerRadius;

  const _ContainerNode(
    super.attributes, {
    required this.wireframeId,
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius = 0.0,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final attrs = attributes;
    SRShapeStyle? style;
    SRShapeBorder? border;
    if (backgroundColor != null || borderWidth != null) {
      style = SRShapeStyle(
        backgroundColor:
            backgroundColor?.toHexString() ?? srTransparentColorString,
        cornerRadius: cornerRadius,
      );

      if (borderWidth != null) {
        border = SRShapeBorder(
          color: borderColor!.toHexString(),
          width: borderWidth!.round(),
        );
      }
    }
    return [
      SRShapeWireframe(
        id: wireframeId,
        x: attrs.x,
        y: attrs.y,
        width: attrs.width,
        height: attrs.height,
        shapeStyle: style,
        border: border,
      ),
    ];
  }
}

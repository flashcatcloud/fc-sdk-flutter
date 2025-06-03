// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

@immutable
class _ContainerStyle {
  final String? backgroundColor;
  final String? borderColor;
  final double? borderWidth;
  final double cornerRadius;

  const _ContainerStyle({
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius = 0.0,
  });
}

@immutable
class _BorderStyle {
  final double? cornerRadius;
  final double? width;
  final String? color;

  const _BorderStyle({
    required this.cornerRadius,
    required this.width,
    required this.color,
  });
}

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
    if (widget is! Container &&
        widget is! Material &&
        widget is! DecoratedBox) {
      return null;
    }

    _ContainerStyle? style;
    switch (widget) {
      case Material widget:
        style = _captureMaterialStyle(widget, attributes);
        break;
      case Container widget:
        final decoration = widget.decoration;
        if (decoration != null) {
          style = _captureDecoration(decoration, attributes);
        }
        style ??= _ContainerStyle(backgroundColor: widget.color?.toHexString());
        break;
      case DecoratedBox box:
        final decoration = box.decoration;
        style = _captureDecoration(decoration, attributes);
        style ??= _ContainerStyle(backgroundColor: null);
        break;
    }

    final key = keyGenerator.keyForElement(element);
    final node = _ContainerNode(attributes, wireframeId: key, style: style!);
    return AmbiguousElement(nodes: [node]);
  }

  _ContainerStyle? _captureDecoration(
    Decoration decoration,
    CapturedViewAttributes attributes,
  ) {
    switch (decoration) {
      case BoxDecoration boxDecoration:
        return _captureBoxDecoration(boxDecoration);
      case ShapeDecoration shapeDecoration:
        return _captureShapeDecoration(shapeDecoration, attributes);
    }
    return null;
  }

  _ContainerStyle _captureBoxDecoration(BoxDecoration decoration) {
    double? cornerRadius = decoration.borderRadius?.resolve(null).topLeft.x;
    Color? backgroundColor = decoration.color;
    double? borderWidth;
    Color? borderColor;
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

    return _ContainerStyle(
      backgroundColor: backgroundColor?.toHexString(),
      borderColor: borderColor?.toHexString(),
      borderWidth: borderWidth,
      cornerRadius: cornerRadius ?? 0.0,
    );
  }

  _ContainerStyle _captureShapeDecoration(
    ShapeDecoration decoration,
    CapturedViewAttributes attributes,
  ) {
    final borderStyle = _extractShapeBorder(decoration.shape, attributes);
    return _ContainerStyle(
      backgroundColor: decoration.color?.toHexString(),
      borderColor: borderStyle?.color,
      borderWidth: borderStyle?.width,
      cornerRadius: borderStyle?.cornerRadius ?? 0.0,
    );
  }

  _ContainerStyle _captureMaterialStyle(
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

    final borderStyle = _extractShapeBorder(widget.shape, attributes);

    return _ContainerStyle(
      backgroundColor: backgroundColor?.toHexString(),
      borderColor: borderStyle?.color,
      borderWidth: borderStyle?.width,
      cornerRadius: borderStyle?.cornerRadius ?? 0.0,
    );
  }

  _BorderStyle? _extractShapeBorder(
    ShapeBorder? shape,
    CapturedViewAttributes attributes,
  ) {
    switch (shape) {
      case final StadiumBorder _:
        final shortSide = attributes.paintBounds.shortestSide;
        return _BorderStyle(
          cornerRadius: shortSide / 2,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final CircleBorder _:
        final shortSide = attributes.paintBounds.shortestSide;
        return _BorderStyle(
          cornerRadius: shortSide / 2,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final RoundedRectangleBorder shape:
        // TODO: TextDirection
        return _BorderStyle(
          cornerRadius: shape.borderRadius.resolve(null).topLeft.x,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
    }
    return null;
  }
}

@immutable
class _ContainerNode extends CaptureNode {
  final int wireframeId;
  final _ContainerStyle style;

  const _ContainerNode(
    super.attributes, {
    required this.wireframeId,
    required this.style,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final attrs = attributes;
    SRShapeStyle? shapeStyle;
    SRShapeBorder? shapeBorder;
    if (style.backgroundColor != null || style.borderWidth != null) {
      shapeStyle = SRShapeStyle(
        backgroundColor: style.backgroundColor ?? srTransparentColorString,
        cornerRadius: style.cornerRadius,
      );

      if (style.borderWidth != null) {
        shapeBorder = SRShapeBorder(
          color: style.borderColor!,
          width: style.borderWidth!.round(),
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
        shapeStyle: shapeStyle,
        border: shapeBorder,
      ),
    ];
  }
}

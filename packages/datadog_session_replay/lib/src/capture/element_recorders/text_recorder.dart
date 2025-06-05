// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

class TextElementRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const TextElementRecorder(this.keyGenerator);

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final widget = element.widget;
    if (widget is! RichText) {
      return null;
    }

    final textSpan = widget.text;
    if (textSpan is TextSpan) {
      final style = textSpan.style;
      final alignment = _getDatadogHorizontalAlignment(widget);

      // For now, contact all child spans into a single string.
      // TODO(RUM-10230: Research how to support inline spans with different styles
      final stringBuilder = StringBuffer();
      bool hasWidgetChildern = _getText(textSpan, stringBuilder);

      final node = _TextElementCaptureNode(
        attributes,
        wireframeId: keyGenerator.keyForElement(element),
        text: stringBuilder.toString(),
        color: style?.color?.toHexString() ?? Colors.black.toHexString(),
        family: style?.fontFamily ?? '',
        size: style?.fontSize?.round() ?? 10,
        alignment: alignment,
      );

      return SpecificElement(
        subtreeStrategy:
            hasWidgetChildern
                ? CaptureNodeSubtreeStrategy.record
                : CaptureNodeSubtreeStrategy.ignore,
        nodes: [node],
      );
    }
    return null;
  }

  bool _getText(TextSpan span, StringBuffer buffer) {
    bool hasWidgetChildren = false;
    if (span.text case final text?) {
      buffer.write(text);
    }

    span.children?.forEach((inlineSpan) {
      if (inlineSpan is TextSpan) {
        hasWidgetChildren |= _getText(inlineSpan, buffer);
      } else if (inlineSpan is WidgetSpan) {
        hasWidgetChildren = true;
      }
    });
    return hasWidgetChildren;
  }

  SRHorizontalAlignment _getDatadogHorizontalAlignment(RichText widget) {
    final textDirection = widget.textDirection;
    switch (widget.textAlign) {
      case TextAlign.left:
      case TextAlign.justify:
        return SRHorizontalAlignment.left;
      case TextAlign.start:
        return textDirection == TextDirection.rtl
            ? SRHorizontalAlignment.right
            : SRHorizontalAlignment.left;
      case TextAlign.right:
        return SRHorizontalAlignment.right;
      case TextAlign.end:
        return textDirection == TextDirection.rtl
            ? SRHorizontalAlignment.left
            : SRHorizontalAlignment.right;
      case TextAlign.center:
        return SRHorizontalAlignment.center;
    }
  }
}

@immutable
class _TextElementCaptureNode extends CaptureNode {
  final int wireframeId;
  final String text;
  final String color;
  final String family;
  final int size;
  final SRHorizontalAlignment alignment;

  const _TextElementCaptureNode(
    super.attributes, {
    required this.wireframeId,
    required this.text,
    required this.color,
    required this.family,
    required this.size,
    required this.alignment,
  });

  @override
  List<SRWireframe> buildWireframes() {
    return [
      SRTextWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        text: text,
        textStyle: SRTextStyle(color: color, family: family, size: size),
        textPosition: SRTextPosition(
          alignment: SRAlignment(horizontal: alignment),
        ),
      ),
    ];
  }
}

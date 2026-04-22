// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';

import '../material_widgets/radio_recorder.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../recording_extensions.dart';

const double _kOuterRadius = 7.0;
const double _kInnerRadius = 2.975;
const double _kBorderOutlineStrokeWidth = 1; // Should be 0.3

final Color _kDisabledOuterColor =
    CupertinoColors.white.withValues(alpha: 0.50);
const Color _kDisabledInnerColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(64, 0, 0, 0),
  darkColor: Color.fromARGB(64, 255, 255, 255),
);
const Color _kDisabledBorderColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(64, 0, 0, 0),
  darkColor: Color.fromARGB(64, 0, 0, 0),
);
const CupertinoDynamicColor _kDefaultBorderColor =
    CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(255, 209, 209, 214),
  darkColor: Color.fromARGB(64, 0, 0, 0),
);
const CupertinoDynamicColor _kDefaultInnerColor =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.white,
  darkColor: Color.fromARGB(255, 222, 232, 248),
);
const CupertinoDynamicColor _kDefaultOuterColor =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.activeBlue,
  darkColor: Color.fromARGB(255, 50, 100, 215),
);

/// Detects 'CupertinoRadio' widgets and places a Radio icon
/// on SessionReplay.
class CupertinoRadioRecorder implements GenericElementRecorder {
  final KeyGenerator keyGenerator;

  const CupertinoRadioRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [];

  @override
  bool accepts(Widget widget) => widget is CupertinoRadio;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! CupertinoRadio) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.isMasked;

    final Set<WidgetState> states = RadioRecorder.getState(
        element: element, widget: widget, isMasked: isMasked);

    final Color backgroundColor =
        _getBackgroundColor(element: element, widget: widget, states: states);
    final Color fillColor =
        _getFillColor(element: element, widget: widget, states: states);
    final BorderSide borderSide =
        _getBorderSide(element: element, states: states);
    // cupertino inner radius is not customize

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: _kOuterRadius * 2.0 * attributes.scaleX,
      height: _kOuterRadius * 2.0 * attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final double dotRadius = RadioRecorder.getRadius(
        attributes: attributes, radius: _kInnerRadius * attributes.scaleX);

    // WireFrame keys
    final backgroundWireframeKey =
        keyGenerator.keyForElement(element, wireFrame: 0);
    final foregroundWireframeKey =
        keyGenerator.keyForElement(element, wireFrame: 1);

    final node = RadioNode(
      attributes,
      backgroundWireframeId: backgroundWireframeKey,
      foregroundWireframeId: foregroundWireframeKey,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      side: borderSide,
      innerRadius: dotRadius,
      isSelected: states.contains(WidgetState.selected),
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  Color _getBackgroundColor({
    required Element element,
    required CupertinoRadio<dynamic> widget,
    required Set<WidgetState> states,
  }) {
    return states.contains(WidgetState.disabled)
        ? _kDisabledOuterColor.resolveColor(element)
        : states.contains(WidgetState.selected)
            ? (widget.activeColor ?? _kDefaultOuterColor.resolveColor(element))
            : (widget.inactiveColor ?? CupertinoColors.white);
  }

  Color _getFillColor({
    required Element element,
    required CupertinoRadio<dynamic> widget,
    required Set<WidgetState> states,
  }) {
    return (states.contains(WidgetState.disabled) &&
            states.contains(WidgetState.selected))
        ? widget.fillColor ?? _kDisabledInnerColor.resolveColor(element)
        : states.contains(WidgetState.selected)
            ? widget.fillColor ?? _kDefaultInnerColor.resolveColor(element)
            : CupertinoColors.white;
  }

  BorderSide _getBorderSide({
    required Element element,
    required Set<WidgetState> states,
  }) {
    return (states.contains(WidgetState.selected) &&
            !states.contains(WidgetState.disabled))
        ? BorderSide(
            color: CupertinoColors.transparent,
            width: _kBorderOutlineStrokeWidth,
          )
        : states.contains(WidgetState.disabled)
            ? BorderSide(
                color: _kDisabledBorderColor.resolveColor(element),
                width: _kBorderOutlineStrokeWidth,
              )
            : BorderSide(
                color: _kDefaultBorderColor.resolveColor(element),
                width: _kBorderOutlineStrokeWidth,
              );
  }
}

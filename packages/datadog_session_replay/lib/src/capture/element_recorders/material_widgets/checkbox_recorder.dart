// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../datadog_session_replay.dart';
import '../../../extensions.dart';
import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';

// Characters to represent the checkbox states
const String checkmark = '\u2713';
const String dash = '\u2014';
const String maskedSymbol = 'x';

// Scale for the text size within the box
const double textScale = 0.7;

// Corner radius for the box.
const double checkboxRadius = 2.0;

// Default checkbox size
const double _checkboxVisualSize = 18.0;

/// Detects `CheckBox` widgets and places a check box
/// in SessionReplay.
class CheckboxRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CheckboxRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [Checkbox, CupertinoCheckbox];

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if ( (widget is! Checkbox) && (widget is! CupertinoCheckbox) ) return null;

    final bool? value;
    final bool isEnabled;
    final Color? checkColor;
    final Color? activeColor;
    final WidgetStateProperty<Color?>? fillColor;
    final BorderSide? widgetSide;
    final VisualDensity? visualDensity;

    Color backgroundColor;
    Color symbolColor;
    BorderSide? borderSide;


    if (widget is Checkbox) {

      // Resolves for checkbox state, either checked and enabled
      isEnabled = widget.onChanged != null;       // checkbox mutability state
      value = widget.value;                       // true = checked, false = unchecked, null = tristate (undeterminate)

      checkColor = widget.checkColor;
      activeColor = widget.activeColor;
      fillColor = widget.fillColor;
      widgetSide = widget.side;
      visualDensity = widget.visualDensity;

    } else if (widget is CupertinoCheckbox) {

      // Resolves for checkbox state, either checked and enabled
      isEnabled = widget.onChanged != null;        // checkbox mutability state
      value = widget.value;                        // true = checked, false = unchecked, null = tristate (undeterminate)

      checkColor = widget.checkColor;
      activeColor = widget.activeColor;
      fillColor = widget.fillColor;
      widgetSide = widget.side;
      visualDensity = null;                         // CupertinoCheckbox does not has visualDensity property

    } else {
      // It must be never be reached
      throw UnsupportedError('Unsupported widget type: ${widget.runtimeType}');
    }

    // Resolve checkbox theme for colors and border
    final theme = Theme.of(element);
    final checkboxTheme = theme.checkboxTheme;

    // Build the widget state set to drive theme resolution.
    // TODO: include WidgetState.focused and WidgetState.hovered for richer theme resolution.
    final states = <WidgetState> {
      if (!isEnabled) WidgetState.disabled,
      if (value == true) WidgetState.selected
    };

    // Resolves for privacy settings
    final bool isMasked =
      capturePrivacy.textAndInputPrivacyLevel == TextAndInputPrivacyLevel.maskAllInputs ||
      capturePrivacy.textAndInputPrivacyLevel == TextAndInputPrivacyLevel.maskAll;

    if (!isMasked) {

      // Resolve fill color: checked and tristate (value != false) use the active color,
      // unchecked uses transparent since the border conveys the unchecked state instead.
      backgroundColor = fillColor?.resolve(states) ??
          ((value != false)
            ? (activeColor ?? theme.colorScheme.primary)
            : Colors.transparent);
      if (!isEnabled && value != false) backgroundColor = backgroundColor.withValues(alpha: 0.38);

      // Resolve for checkmark color
      symbolColor = checkColor
          ?? checkboxTheme.checkColor?.resolve(states)
          ?? theme.colorScheme.onPrimary;

      // Resolve for checkbox border just in case the checkbox value is false (all borders are the same)
      // If checkbox value is true or null, there is a fill color and the border is redundant
      if (value == false) {
        borderSide = widgetSide
              ?? (widget is Checkbox ? checkboxTheme.side : null)
              ?? BorderSide(
                color: isEnabled
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                width: 2.0,
              );
      }
    } else {

      borderSide = widgetSide
          ?? (widget is Checkbox ? checkboxTheme.side : null)
          ?? BorderSide(
            color: isEnabled
              ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
            width: 2.0,
          );
      backgroundColor = Colors.transparent;
      symbolColor = borderSide.color;
    }

    final density = visualDensity ?? theme.visualDensity;
    final visualSizeWidth = _checkboxVisualSize + density.baseSizeAdjustment.dx;
    final visualSizeHeight = _checkboxVisualSize + density.baseSizeAdjustment.dy;

    final center = attributes.paintBounds.center;
    final adjustedBounds = Rect.fromCenter(
      center: center,
      width: visualSizeWidth * attributes.scaleX,
      height: visualSizeHeight * attributes.scaleY,
    );
    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final wireframeKey = keyGenerator.keyForElement(element);

    final node = CheckboxNode(
          attributes,
          wireframeId: wireframeKey,
          value: value,
          fillColor: backgroundColor,
          symbolColor: symbolColor,
          side: borderSide,
          isMasked: isMasked,
        );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,       // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }
}

/// Holds the resolved visual properties of a [Checkbox] widget and builds
/// the corresponding [SRTextWireframe], using the text field to render the
/// checkmark symbol and the shape style for the box background and border.
@immutable
class CheckboxNode extends CaptureNode {

  final int wireframeId;
  final bool? value;
  final Color fillColor;
  final Color symbolColor;
  final BorderSide? side;
  final bool isMasked;

  const CheckboxNode(
    super.attributes, {
      required this.value,
      required this.wireframeId,
      required this.symbolColor,
      required this.fillColor,
      required this.side,
      required this.isMasked,
    }
  );

  // Renders the checkbox as a single SRTextWireframe: the box shape is drawn
  // via shapeStyle/border, and the checkmark symbol is centered as text.
  @override
  List<SRWireframe> buildWireframes() {

    final symbol = isMasked ? maskedSymbol : switch (value) {
      true => checkmark,
      false => '',
      null => dash
    };

    return[
      SRTextWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        text: symbol,
        textStyle: SRTextStyle(
          color: symbolColor.toHexString(),
          family: 'sans-serif',
          size: (attributes.height * textScale).round(),
        ),
        textPosition: SRTextPosition(
          alignment: SRAlignment(
            horizontal: SRHorizontalAlignment.center,
            vertical: SRVerticalAlignment.center,
          ),
        ),
        border :
          side != null ? SRShapeBorder(color: side!.color.toHexString(), width: side!.width.round()) : null,
        shapeStyle: SRShapeStyle(
            backgroundColor: fillColor.toHexString(),
            cornerRadius: checkboxRadius,
          ),
        )
    ];
  }
}

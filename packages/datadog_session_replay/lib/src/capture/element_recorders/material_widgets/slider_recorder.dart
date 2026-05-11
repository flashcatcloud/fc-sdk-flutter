// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../extensions.dart';
import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../recording_extensions.dart';

enum _SliderThumbStyle { round, handle }

typedef _SliderThumbGeometry = ({
  Rect rect,
  BorderRadius borderRadius,
  _SliderThumbStyle style,
});

typedef _SliderTrackSegmentGeometry = ({
  Rect rect,
  BorderRadius borderRadius,
});

typedef _SliderGeometry = ({
  _SliderThumbGeometry thumb,
  _SliderTrackSegmentGeometry inactiveTrack,
  _SliderTrackSegmentGeometry activeTrack,
  _SliderTrackSegmentGeometry? secondaryActiveTrack,
});

/// Detects 'Slider' widgets and places an slider
/// in SessionReplay.
class SliderRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const SliderRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is Slider;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    // Check for cupertino slider style
    {
      bool isCupertinoAdaptive = false;
      element.visitChildElements((child) {
        if (child.widget is CupertinoSlider) isCupertinoAdaptive = true;
      });
      if (isCupertinoAdaptive) return null;
    }

    final widget = element.widget;
    if (widget is! Slider) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Resolve slider theme for colors
    final ThemeData theme = Theme.of(element);

    final bool year2023 =
        widget.year2023 ?? theme.sliderTheme.year2023 ?? true;

    final isEnabled = widget.onChanged != null;

    final Color activeColor = _getActiveColor(
      widget: widget, 
      isEnabled: isEnabled, 
      theme: theme, 
      year2023: year2023
    );
    final Color inactiveColor = _getInactiveColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      year2023: year2023
    );
    final Color secondaryActiveColor = _getSecondaryActiveColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      year2023: year2023
    );
    final Color thumbColor = _getThumbColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      year2023: year2023
    );

    final _SliderGeometry geometry = _getSliderGeometry(
      widget: widget,
      theme: theme,
      year2023: year2023,
      bounds: attributes.paintBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final inactiveTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 0);
    final secondaryActiveTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 1);
    final activeTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 2);
    final thumbKey = 
        keyGenerator.keyForElement(element, wireframeId: 3);

    final node = SliderNode(
      attributes,
      inactiveTrackWireframeId: inactiveTrackKey,
      secondaryActiveTrackWireframeId: secondaryActiveTrackKey,
      activeTrackWireframeId: activeTrackKey,
      thumbWireframeId: thumbKey,
      inactiveTrackRect: geometry.inactiveTrack.rect,
      activeTrackRect: geometry.activeTrack.rect,
      secondaryActiveTrackRect: geometry.secondaryActiveTrack?.rect,
      thumbRect: geometry.thumb.rect,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      secondaryActiveColor: secondaryActiveColor,
      thumbColor: thumbColor,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  Color _getActiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required bool year2023,
  }) {
    if (isEnabled) return widget.activeColor ?? theme.sliderTheme.activeTrackColor ?? theme.colorScheme.primary;
    Color? disabledColor = theme.sliderTheme.disabledActiveTrackColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3) return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return theme.colorScheme.onSurface.withValues(alpha: 0.32);
  }

  Color _getInactiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required bool year2023,
  }) {
    if (isEnabled) {
      Color? inactiveColor = widget.inactiveColor ?? theme.sliderTheme.inactiveTrackColor;
      if (inactiveColor != null) return inactiveColor;
      if (theme.useMaterial3) {
        if (year2023) return theme.colorScheme.surfaceContainerHighest;
        return theme.colorScheme.secondaryContainer;
      }
      return theme.colorScheme.primary.withValues(alpha: 0.24);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.12);
  }

  Color _getSecondaryActiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required bool year2023,
  }) {
    if (isEnabled) {
      return widget.secondaryActiveColor ??
          theme.sliderTheme.secondaryActiveTrackColor ??
          theme.colorScheme.primary.withValues(alpha: 0.54);
    }
    Color? disabledColor = theme.sliderTheme.disabledSecondaryActiveTrackColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3 && !year2023) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.12);
  }

  Color _getThumbColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required bool year2023,
  }) {
    if (isEnabled) {
      return widget.thumbColor ??
          widget.activeColor ??
          theme.sliderTheme.thumbColor ??
          theme.colorScheme.primary;
    }
    Color? disabledColor = theme.sliderTheme.disabledThumbColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3 && !year2023) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }
    return Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.38),
      theme.colorScheme.surface,
    );
  }

  _SliderGeometry _getSliderGeometry({
    required Slider widget,
    required ThemeData theme,
    required bool year2023,
    required Rect bounds,
    required double scaleX,
    required double scaleY,
  }) {
    final SliderThemeData sliderTheme = theme.sliderTheme;
    final bool isGapped = theme.useMaterial3 && !year2023;

    // Uniform scale preserves circles/pills and ensures dimensions fit within
    // anisotropic bounds.
    final double scale = math.min(scaleX, scaleY);

    final double trackHeight =
        (sliderTheme.trackHeight ?? (isGapped ? 16.0 : 4.0)) * scale;

    final _SliderThumbStyle thumbStyle;
    final Size thumbSize;
    if (isGapped) {
      thumbStyle = _SliderThumbStyle.handle;
      final Size logicalThumbSize =
          sliderTheme.thumbSize?.resolve(<WidgetState>{}) ??
              const Size(4.0, 44.0);
      thumbSize = Size(
        logicalThumbSize.width * scale,
        logicalThumbSize.height * scale,
      );
    } else {
      thumbStyle = _SliderThumbStyle.round;
      thumbSize = Size(20.0 * scale, 20.0 * scale);
    }

    // RoundSliderOverlayShape default radius is 24 → 48px diameter.
    final double overlayWidth = 48.0 * scale;
    final double horizontalInset = sliderTheme.padding != null
        ? 0.0
        : math.max(thumbSize.width, overlayWidth) / 2;

    final double trackLeft = bounds.left + horizontalInset;
    final double trackRight = bounds.right - horizontalInset;
    final double trackTop = bounds.center.dy - trackHeight / 2;
    final double trackBottom = trackTop + trackHeight;
    final double trackWidth = trackRight - trackLeft;

    final double range = widget.max - widget.min;
    final double valueRatio = range == 0
        ? 0.0
        : ((widget.value - widget.min) / range).clamp(0.0, 1.0).toDouble();
    final double thumbCenterX = trackLeft + trackWidth * valueRatio;

    final Radius trackEndRadius = Radius.circular(trackHeight / 2);
    final Radius trackInsideRadius = Radius.circular(2.0 * scale);
    final double trackGap =
        isGapped ? (sliderTheme.trackGap ?? 6.0) * scale : 0.0;

    final _SliderTrackSegmentGeometry activeTrack;
    if (isGapped) {
      final double activeRight =
          math.max(trackLeft, thumbCenterX - trackGap);
      activeTrack = (
        rect: Rect.fromLTRB(trackLeft, trackTop, activeRight, trackBottom),
        borderRadius: BorderRadius.only(
          topLeft: trackEndRadius,
          bottomLeft: trackEndRadius,
          topRight: trackInsideRadius,
          bottomRight: trackInsideRadius,
        ),
      );
    } else {
      activeTrack = (
        rect: Rect.fromLTRB(
          trackLeft,
          trackTop,
          thumbCenterX + trackHeight / 2,
          trackBottom,
        ),
        borderRadius: BorderRadius.all(trackEndRadius),
      );
    }

    final _SliderTrackSegmentGeometry inactiveTrack;
    if (isGapped) {
      final double inactiveLeft =
          math.min(trackRight, thumbCenterX + trackGap);
      inactiveTrack = (
        rect: Rect.fromLTRB(inactiveLeft, trackTop, trackRight, trackBottom),
        borderRadius: BorderRadius.only(
          topLeft: trackInsideRadius,
          bottomLeft: trackInsideRadius,
          topRight: trackEndRadius,
          bottomRight: trackEndRadius,
        ),
      );
    } else {
      inactiveTrack = (
        rect: Rect.fromLTRB(trackLeft, trackTop, trackRight, trackBottom),
        borderRadius: BorderRadius.all(trackEndRadius),
      );
    }

    _SliderTrackSegmentGeometry? secondaryActiveTrack;
    final double? secValue = widget.secondaryTrackValue;
    if (secValue != null) {
      final double clampedSec =
          secValue.clamp(widget.min, widget.max).toDouble();
      final double secRatio =
          range == 0 ? 0.0 : (clampedSec - widget.min) / range;
      final double secX = trackLeft + trackWidth * secRatio;
      if (isGapped) {
        final double secLeft = thumbCenterX + trackGap;
        if (secX > secLeft) {
          secondaryActiveTrack = (
            rect: Rect.fromLTRB(secLeft, trackTop, secX, trackBottom),
            borderRadius: BorderRadius.only(
              topLeft: trackInsideRadius,
              bottomLeft: trackInsideRadius,
              topRight: trackEndRadius,
              bottomRight: trackEndRadius,
            ),
          );
        }
      } else if (secX > thumbCenterX) {
        secondaryActiveTrack = (
          rect: Rect.fromLTRB(thumbCenterX, trackTop, secX, trackBottom),
          borderRadius: BorderRadius.only(
            topRight: trackEndRadius,
            bottomRight: trackEndRadius,
          ),
        );
      }
    }

    final Rect thumbRect = Rect.fromCenter(
      center: Offset(thumbCenterX, bounds.center.dy),
      width: thumbSize.width,
      height: thumbSize.height,
    );
    final _SliderThumbGeometry thumb = (
      rect: thumbRect,
      borderRadius:
          BorderRadius.all(Radius.circular(thumbSize.shortestSide / 2)),
      style: thumbStyle,
    );

    return (
      thumb: thumb,
      inactiveTrack: inactiveTrack,
      activeTrack: activeTrack,
      secondaryActiveTrack: secondaryActiveTrack,
    );
  }
}

/// Holds the resolved visual properties of a [Slider] widget and builds the
/// corresponding [SRShapeWireframe]s: an inactive track (full background),
/// an optional secondary active segment, an active segment, and a thumb on
/// top. Each piece is rendered as a pill (cornerRadius = shortestSide / 2).
@immutable
class SliderNode extends CaptureNode {
  final int inactiveTrackWireframeId;
  final int secondaryActiveTrackWireframeId;
  final int activeTrackWireframeId;
  final int thumbWireframeId;
  final Rect inactiveTrackRect;
  final Rect activeTrackRect;
  final Rect? secondaryActiveTrackRect;
  final Rect thumbRect;
  final Color activeColor;
  final Color inactiveColor;
  final Color secondaryActiveColor;
  final Color thumbColor;

  const SliderNode(
    super.attributes, {
    required this.inactiveTrackWireframeId,
    required this.secondaryActiveTrackWireframeId,
    required this.activeTrackWireframeId,
    required this.thumbWireframeId,
    required this.inactiveTrackRect,
    required this.activeTrackRect,
    required this.secondaryActiveTrackRect,
    required this.thumbRect,
    required this.activeColor,
    required this.inactiveColor,
    required this.secondaryActiveColor,
    required this.thumbColor,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final wireframes = <SRWireframe>[
      _shape(
        id: inactiveTrackWireframeId,
        rect: inactiveTrackRect,
        color: inactiveColor,
      ),
    ];

    if (secondaryActiveTrackRect != null) {
      wireframes.add(_shape(
        id: secondaryActiveTrackWireframeId,
        rect: secondaryActiveTrackRect!,
        color: secondaryActiveColor,
      ));
    }

    wireframes.add(_shape(
      id: activeTrackWireframeId,
      rect: activeTrackRect,
      color: activeColor,
    ));

    wireframes.add(_shape(
      id: thumbWireframeId,
      rect: thumbRect,
      color: thumbColor,
    ));

    return wireframes;
  }

  static SRShapeWireframe _shape({
    required int id,
    required Rect rect,
    required Color color,
  }) {
    return SRShapeWireframe(
      id: id,
      x: rect.left.round(),
      y: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
      shapeStyle: SRShapeStyle(
        backgroundColor: color.toHexString(),
        cornerRadius: rect.shortestSide / 2,
      ),
    );
  }
}

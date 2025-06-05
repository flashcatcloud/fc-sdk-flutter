// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../sr_data_models.dart';

@immutable
class CapturedViewAttributes {
  final Rect paintBounds;
  final double scaleX;
  final double scaleY;

  int get x => paintBounds.left.round();
  int get y => paintBounds.top.round();
  int get width => paintBounds.width.round();
  int get height => paintBounds.height.round();

  const CapturedViewAttributes({
    required this.paintBounds,
    required this.scaleX,
    required this.scaleY,
  });
}

@immutable
abstract class CaptureNode {
  final CapturedViewAttributes attributes;

  const CaptureNode(this.attributes);

  List<SRWireframe> buildWireframes();
}

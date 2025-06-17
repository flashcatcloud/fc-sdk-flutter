// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

// This size was chosen so that 'Content Image' would fit without
// overlappping other content in the replay.
const int labelMinWidth = 200;

class ImageRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const ImageRecorder(this.keyGenerator);

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    CapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! Image) return null;

    final elementId = keyGenerator.keyForElement(element);
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: [_ImageNode(attributes, wireframeId: elementId)],
    );
  }
}

@immutable
class _ImageNode extends CaptureNode {
  final int wireframeId;

  const _ImageNode(super.attributes, {required this.wireframeId});

  @override
  List<SRWireframe> buildWireframes() {
    final label = attributes.width < labelMinWidth ? null : 'Content Image';
    return [
      SRPlaceholderWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        label: label,
      ),
    ];
  }
}

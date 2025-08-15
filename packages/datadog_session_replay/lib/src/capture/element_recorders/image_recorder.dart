// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../datadog_session_replay_platform_interface.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

// This size was chosen so that 'Content Image' would fit without
// overlappping other content in the replay.
const int labelMinWidth = 200;

class ImageRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final DatadogSessionReplayPlatform platform;

  const ImageRecorder(this.keyGenerator, this.platform);

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    CapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! RawImage) return null;

    final elementId = keyGenerator.keyForElement(element);
    final uiImage = widget.image;
    if (uiImage == null) {
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [_PlaceholderImageNode(attributes, wireframeId: elementId)],
      );
    }

    final hasResourceKey = keyGenerator.hasImageKey(uiImage);
    if (hasResourceKey) {
      final resourceKey = keyGenerator.keyForImage(uiImage);
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          _ResourceImageNode(
            attributes,
            wireframeId: elementId,
            resourceKey: resourceKey,
          ),
        ],
      );
    }

    return AdditionalProcessingElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      process: () => _captureImage(elementId, element, attributes, widget),
    );
  }

  Future<CaptureNodeSemantics> _captureImage(
    int elementId,
    Element element,
    CapturedViewAttributes attributes,
    RawImage widget,
  ) async {
    final List<CaptureNode> nodes = [];
    if (widget.image case final image?) {
      // Prevent conversion of the image data to speed things up, we're going to
      // be hashing / compressing in the processor anyway
      ByteData? byteData = await image.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      if (byteData != null) {
        final resourceKey = keyGenerator.keyForImage(image);
        platform.saveImageForProcessing(
          resourceKey,
          image.width,
          image.height,
          byteData,
        );
      }
    }

    if (nodes.isEmpty) {
      nodes.add(_PlaceholderImageNode(attributes, wireframeId: elementId));
    }

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: nodes,
    );
  }
}

@immutable
class _PlaceholderImageNode extends CaptureNode {
  final int wireframeId;

  const _PlaceholderImageNode(super.attributes, {required this.wireframeId});

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

@immutable
class _ResourceImageNode extends CaptureNode {
  final int wireframeId;
  final int resourceKey;

  const _ResourceImageNode(
    super.attributes, {
    required this.wireframeId,
    required this.resourceKey,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final resourceId = DatadogSessionReplayPlatform.instance.resourceIdForKey(
      resourceKey,
    );

    return [
      SRImageWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        resourceId: resourceId,
      ),
    ];
  }
}

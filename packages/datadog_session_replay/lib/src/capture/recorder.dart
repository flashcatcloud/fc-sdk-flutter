// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import '../widgets.dart';
import 'capture_node.dart';
import 'element_recorders/container_recorder.dart';
import 'element_recorders/custom_paint_recorder.dart';
import 'element_recorders/editable_text_recorder.dart';
import 'element_recorders/text_recorder.dart';
import 'pointer_capture.dart';
import 'view_tree_snapshot.dart';

/// Capture privacy for the current tree of nodes. This is set by the configuration,
/// to start, but can change if the capture encounters a Widget that modifies it.
@immutable
class CapturePrivacy {
  final TextAndInputPrivacyLevel textAndInputPrivacyLevel;

  const CapturePrivacy({required this.textAndInputPrivacyLevel});

  @override
  bool operator ==(Object other) {
    if (other is! CapturePrivacy) return false;

    return other.textAndInputPrivacyLevel == textAndInputPrivacyLevel;
  }

  @override
  int get hashCode {
    return textAndInputPrivacyLevel.hashCode;
  }
}

abstract interface class ElementRecorder {
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    CapturePrivacy capturePrivacy,
  );
}

class KeyGenerator {
  // This is close to JavaScript's MAX_SAFE_INT (53-bit)
  static const int maxKey = 0x20000000000000;
  var _nextKey = 0;

  final Expando<int> _nodeIdExpando = Expando('sr-key');
  // ignore: unused_field
  final Expando<List<int>> _nodeIdsExpando = Expando('multi-sr-key');

  int keyForElement(Element e) {
    var value = _nodeIdExpando[e];
    if (value != null) return value;

    value = _nextKey;
    _nextKey = _nextKey + 1;
    if (_nextKey >= maxKey) _nextKey = 0;

    _nodeIdExpando[e] = value;

    return value;
  }
}

@immutable
class CaptureResult {
  final ViewTreeSnapshot viewTreeSnapshot;
  final PointerSnapshot? pointerSnapshot;

  const CaptureResult(this.viewTreeSnapshot, this.pointerSnapshot);
}

class SessionReplayRecorder {
  final Map<Key, Element> _elements = {};

  RUMContext? _currentContext;

  final DatadogTimeProvider _timeProvider;
  final List<ElementRecorder> _elementRecorders;
  CapturePrivacy _defaultCapturePrivacy;

  @visibleForTesting
  set defaultCapturePrivacy(CapturePrivacy value) =>
      _defaultCapturePrivacy = value;
  CapturePrivacy get defaultCapturePrivacy => _defaultCapturePrivacy;

  SessionReplayRecorder({
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required CapturePrivacy defaultCapturePrivacy,
  }) : this._(KeyGenerator(), timeProvider, defaultCapturePrivacy);

  SessionReplayRecorder._(
    KeyGenerator keyGenerator,
    this._timeProvider,
    this._defaultCapturePrivacy,
  ) : _elementRecorders = [
        ContainerRecorder(keyGenerator),
        TextElementRecorder(keyGenerator),
        EditableTextRecorder(keyGenerator),
        InputDecoratorRecorder(keyGenerator),
        CustomPaintRecorder(keyGenerator),
      ];

  @visibleForTesting
  SessionReplayRecorder.withCustomRecorders(
    this._elementRecorders, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required CapturePrivacy defaultCapturePrivacy,
  }) : _timeProvider = timeProvider,
       _defaultCapturePrivacy = defaultCapturePrivacy;

  void updateContext(RUMContext? context) {
    _currentContext = context;
  }

  void addElement(Key key, Element e) {
    _elements[key] = e;
  }

  void removeElement(Key key) {
    _elements.remove(key);
  }

  CaptureResult? performCapture() {
    final context = _currentContext;
    if (context == null) {
      return null;
    }

    DateTime now = _timeProvider.now();
    List<CaptureNode> nodes = [];
    List<PointerSnapshot> pointerSnapshots = [];
    var size = Size.zero;
    for (final e in _elements.values) {
      // During hot reload, elements can be inserted that still need layout, and
      // these will throw when we get their size. Avoid capturing these
      if (kDebugMode) {
        if (e.renderObject?.debugNeedsLayout == true) continue;
      }
      final elementSize = e.size;
      if (elementSize != null) {
        // Need to copy this value because the size class
        // returned by the element is not serializable over the isolate
        size = Size(elementSize.width, elementSize.height);
      }
      _captureElement(e, nodes, pointerSnapshots, _defaultCapturePrivacy);
    }

    if (nodes.isEmpty) return null;

    final viewTreeSnapshot = ViewTreeSnapshot(
      date: now,
      context: context,
      viewportSize: size,
      nodes: nodes,
    );

    // We shouldn't have multiple pointer snapshots, but even if we
    // do, for now just take the first one.
    final pointerSnapshot = pointerSnapshots.firstOrNull;

    return CaptureResult(viewTreeSnapshot, pointerSnapshot);
  }

  void onContextChanged(RUMContext context) {
    _currentContext = context;

    DatadogSessionReplayPlatform.instance.setHasReplay(context.viewId != null);
  }

  void _captureElement(
    Element topElement,
    List<CaptureNode> nodes,
    List<PointerSnapshot> pointerSnapshots,
    CapturePrivacy capturePrivacy,
  ) {
    void visit(Element e, CapturePrivacy capturePrivacy, int depth) {
      if (e.widget case final PointerRecorder snapshotWidget) {
        if (snapshotWidget.snapshotRecorder.takeSnapshot()
            case final snapshot?) {
          pointerSnapshots.add(snapshot);
        }
      }

      final renderObject = e.renderObject;
      if (renderObject == null) return;

      // During hot reload, the recorder can try to capture items that still need
      // layout, which will throw. Prevent this.
      if (kDebugMode && renderObject.debugNeedsLayout) return;

      final transformMatrix = renderObject.getTransformTo(
        topElement.renderObject,
      );
      final untransformedPaintBounds = renderObject.paintBounds;

      final paintBounds = MatrixUtils.transformRect(
        transformMatrix,
        renderObject.paintBounds,
      );
      // Don't capture things that take up no space.
      if (paintBounds.width == 0 || paintBounds.height == 0) return;

      final scaleX = paintBounds.width / untransformedPaintBounds.width;
      final scaleY = paintBounds.height / untransformedPaintBounds.height;
      final viewAttributes = CapturedViewAttributes(
        paintBounds: paintBounds,
        scaleX: scaleX,
        scaleY: scaleY,
      );

      final elementSemantics = _elementSemantics(
        e,
        viewAttributes,
        capturePrivacy,
      );
      if (elementSemantics.subtreePrivacy case final newCapturePrivacy?) {
        capturePrivacy = newCapturePrivacy;
      }

      nodes.addAll(elementSemantics.nodes);

      if (elementSemantics.subtreeStrategy ==
          CaptureNodeSubtreeStrategy.record) {
        e.visitChildElements((child) {
          final renderObject = child.renderObject;
          if (renderObject == null) return;

          visit(child, capturePrivacy, depth + 1);
        });
      }
    }

    visit(topElement, capturePrivacy, 0);
  }

  CaptureNodeSemantics _elementSemantics(
    Element element,
    CapturedViewAttributes viewAttributes,
    CapturePrivacy capturePrivacy,
  ) {
    CaptureNodeSemantics semantics = const UnknownElement();

    for (final recorder in _elementRecorders) {
      final nextSemantics = recorder.captureSemantics(
        element,
        viewAttributes,
        capturePrivacy,
      );
      if (nextSemantics == null) continue;

      if (nextSemantics.importance >= semantics.importance) {
        semantics = nextSemantics;
        if (semantics.importance == CaptureNodeSemantics.maxImporance) {
          break;
        }
      }
    }

    return semantics;
  }
}

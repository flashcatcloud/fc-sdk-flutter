// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/widgets.dart';

import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import '../widgets.dart';
import 'capture_node.dart';
import 'element_recorders/container_recorder.dart';
import 'pointer_capture.dart';
import 'view_tree_snapshot.dart';

abstract interface class ElementRecorder {
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
  );
}

class KeyGenerator {
  // This is close to JavaScript's MAX_SAFE_INT (53-bit)
  static const int maxKey = 0x20000000000000;
  var nextKey = 0;

  final Expando<int> _nodeIdExpando = Expando('sr-key');
  final Expando<List<int>> _nodeIdsExpando = Expando('multi-sr-key');

  @override
  int keyForElement(Element e) {
    var value = _nodeIdExpando[e];
    if (value != null) return value;

    value = nextKey;
    nextKey = nextKey + 1;
    if (nextKey >= maxKey) nextKey = 0;

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

  SessionReplayRecorder({
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
  }) : this._(KeyGenerator(), timeProvider);

  SessionReplayRecorder._(KeyGenerator keyGenerator, this._timeProvider)
    : _elementRecorders = [ContainerRecorder(keyGenerator)];

  @visibleForTesting
  SessionReplayRecorder.withCustomRecorders(
    this._elementRecorders, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
  }) : _timeProvider = timeProvider;

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
      final elementSize = e.size;
      if (elementSize != null) {
        // Need to copy this value because the size class
        // returned by the element is not serializable over the isolate
        size = Size(elementSize.width, elementSize.height);
      }
      _captureElement(e, nodes, pointerSnapshots);
    }

    if (nodes.isEmpty) return null;

    final viewTreeSnapshot = ViewTreeSnapshot(
      date: now,
      context: context,
      viewportSize: size,
      nodes: nodes,
    );

    // TODO: We dhouldn't have multiple pointer snapshots, but even if we
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
  ) {
    void visit(Element e, int depth) {
      if (e.widget case final PointerRecorder snapshotWidget) {
        if (snapshotWidget.snapshotRecorder.takeSnapshot()
            case final snapshot?) {
          pointerSnapshots.add(snapshot);
        }
      }

      final renderObject = e.renderObject;
      if (renderObject == null) return;

      final transformMatrix = renderObject.getTransformTo(
        topElement.renderObject,
      );
      final paintBounds = MatrixUtils.transformRect(
        transformMatrix,
        renderObject.paintBounds,
      );
      final viewAttributes = CapturedViewAttributes(
        paintBounds: paintBounds,
        scaleX: 1.0,
        scaleY: 1,
      );

      final elementSemantics = _elementSemantics(e, viewAttributes);

      nodes.addAll(elementSemantics.nodes);

      if (elementSemantics.subtreeStrategy ==
          CaptureNodeSubtreeStrategy.record) {
        e.visitChildElements((child) {
          final renderObject = child.renderObject;
          if (renderObject == null) return;

          visit(child, depth + 1);
        });
      }
    }

    visit(topElement, 0);
  }

  CaptureNodeSemantics _elementSemantics(
    Element element,
    CapturedViewAttributes viewAttributes,
  ) {
    CaptureNodeSemantics semantics = const UnknownElement();

    for (final recorder in _elementRecorders) {
      final nextSemantics = recorder.captureSemantics(element, viewAttributes);
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

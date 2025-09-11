// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ui' as ui;

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
import 'element_recorders/image_recorder.dart';
import 'element_recorders/privacy_recorder.dart';
import 'element_recorders/text_recorder.dart';
import 'pointer_capture.dart';
import 'view_tree_snapshot.dart';

/// Capture privacy for the current tree of nodes. This is set by the configuration,
/// to start, but can change if the capture encounters a Widget that modifies it.
@immutable
class TreeCapturePrivacy {
  final TextAndInputPrivacyLevel textAndInputPrivacyLevel;
  final ImagePrivacyLevel imagePrivacyLevel;

  const TreeCapturePrivacy({
    required this.textAndInputPrivacyLevel,
    required this.imagePrivacyLevel,
  });

  @override
  bool operator ==(Object other) {
    if (other is! TreeCapturePrivacy) return false;

    return other.textAndInputPrivacyLevel == textAndInputPrivacyLevel &&
        other.imagePrivacyLevel == imagePrivacyLevel;
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
    TreeCapturePrivacy capturePrivacy,
  );
}

class KeyGenerator {
  // This is close to JavaScript's MAX_SAFE_INT (53-bit)
  static const int maxKey = 0x20000000000000;
  // Starting key for resources
  static const int startingResourceKey = 0x100000;

  var _nextElementKey = 0;
  var _nextResourceKey = startingResourceKey;

  final Expando<int> _nodeIdExpando = Expando('sr-key');
  final Expando<int> _resourceIdExpando = Expando('sr-resource-key');

  int keyForElement(Element e) {
    var value = _nodeIdExpando[e];
    if (value != null) return value;

    value = _nextElementKey;
    _nextElementKey = _nextElementKey + 1;
    if (_nextElementKey >= maxKey) _nextElementKey = 0;

    _nodeIdExpando[e] = value;

    return value;
  }

  bool hasImageKey(ui.Image e) => _resourceIdExpando[e] != null;

  int keyForImage(ui.Image e) {
    var value = _resourceIdExpando[e];
    if (value != null) return value;

    value = _nextResourceKey;
    _nextResourceKey = _nextResourceKey + 1;
    if (_nextResourceKey >= maxKey) _nextResourceKey = startingResourceKey;

    _resourceIdExpando[e] = value;
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
  final DatadogTimeProvider _timeProvider;
  final List<ElementRecorder> _elementRecorders;

  final Map<Key, Element> _elements = {};
  RUMContext? _currentContext;
  bool _captureInProgress = false;
  TreeCapturePrivacy _defaultTreeCapturePrivacy;
  // TODO(RUM-11681): Support touch privacy
  // ignore: unused_field
  TouchPrivacyLevel _touchPrivacyLevel;

  @visibleForTesting
  set defaultTreeCapturePrivacy(TreeCapturePrivacy value) =>
      _defaultTreeCapturePrivacy = value;
  TreeCapturePrivacy get defaultTreeCapturePrivacy =>
      _defaultTreeCapturePrivacy;

  SessionReplayRecorder({
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required TreeCapturePrivacy defaultCapturePrivacy,
    required TouchPrivacyLevel touchPrivacyLevel,
  }) : this._(
         KeyGenerator(),
         timeProvider,
         defaultCapturePrivacy,
         touchPrivacyLevel,
       );

  SessionReplayRecorder._(
    KeyGenerator keyGenerator,
    this._timeProvider,
    this._defaultTreeCapturePrivacy,
    this._touchPrivacyLevel,
  ) : _elementRecorders = [
        ContainerRecorder(keyGenerator),
        TextElementRecorder(keyGenerator),
        EditableTextRecorder(keyGenerator),
        InputDecoratorRecorder(keyGenerator),
        ImageRecorder(keyGenerator),
        CustomPaintRecorder(keyGenerator),
        PrivacyRecorder(keyGenerator),
      ];

  @visibleForTesting
  SessionReplayRecorder.withCustomRecorders(
    this._elementRecorders, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required TreeCapturePrivacy defaultCapturePrivacy,
    required TouchPrivacyLevel touchPrivacyLevel,
  }) : _timeProvider = timeProvider,
       _defaultTreeCapturePrivacy = defaultCapturePrivacy,
       _touchPrivacyLevel = touchPrivacyLevel;

  void updateContext(RUMContext? context) {
    _currentContext = context;
  }

  void addElement(Key key, Element e) {
    _elements[key] = e;
  }

  void removeElement(Key key) {
    _elements.remove(key);
  }

  Future<CaptureResult?> performCapture() async {
    final context = _currentContext;
    if (context == null) {
      return null;
    }

    // We're currently in the middle of a capture (async processing is still
    // occurring), don't start another frame until this one is done.
    if (_captureInProgress) return null;

    _captureInProgress = true;
    DateTime now = _timeProvider.now();
    List<CaptureNodeSemantics> capturedSemantics = [];
    List<PointerSnapshot> pointerSnapshots = [];
    var size = Size.zero;
    for (final e in _elements.values) {
      final renderObject = e.renderObject;
      if (kDebugMode) {
        // During hot reload, elements can be inserted that still need layout, and
        // these will throw when we get their size. Avoid capturing these
        if (renderObject?.debugNeedsLayout == true) continue;
      }

      // In debug mode, Flutter will assert if you attempt to access the size of an
      // object that shouldn't have size. We can skip elements that have no size for
      // whatever reason.
      if (renderObject is RenderBox && !renderObject.hasSize) continue;

      final elementSize = e.size;
      if (elementSize != null) {
        // Need to copy this value because the size class
        // returned by the element is not serializable over the isolate
        size = Size(elementSize.width, elementSize.height);
      }
      _captureElement(
        e,
        capturedSemantics,
        pointerSnapshots,
        _defaultTreeCapturePrivacy,
      );
    }

    // Process anything that needs additional processing
    final nodes = <CaptureNode>[];
    for (var s in capturedSemantics) {
      if (s is AdditionalProcessingElement) {
        s = await s.process();
      }
      nodes.addAll(s.nodes);
    }

    _captureInProgress = false;

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

    if (context.viewId case final viewId?) {
      DatadogSessionReplayPlatform.instance.setHasReplay(viewId, true);
    }
  }

  // Certain elements will cause everything under the element to be invisible, such
  // as Visibility or FadeTransition. Ignore these trees.
  bool _shouldIgnoreTree(Element e) {
    if (e.widget case final Visibility visibility) {
      if (!visibility.visible) return true;
    }
    if (e.widget case final SliverVisibility visilbity) {
      if (!visilbity.visible) return true;
    }
    if (e.widget case final FadeTransition transition) {
      if (transition.opacity.value <= 0.0) return true;
    }

    return false;
  }

  void _captureElement(
    Element topElement,
    List<CaptureNodeSemantics> capturedSemantics,
    List<PointerSnapshot> pointerSnapshots,
    TreeCapturePrivacy capturePrivacy,
  ) {
    void visit(Element e, TreeCapturePrivacy capturePrivacy, int depth) {
      if (e.widget case final PointerRecorder snapshotWidget) {
        if (snapshotWidget.snapshotRecorder.takeSnapshot()
            case final snapshot?) {
          pointerSnapshots.add(snapshot);
        }
      }

      if (_shouldIgnoreTree(e)) return;

      final renderObject = e.renderObject;
      if (renderObject == null) return;

      // TODO(RUM-10473): debugNeedsLayout is also set during scrolling and does not throw from
      // the recorder, so we'll need to look for a different flag to prevent the throw
      // during hot reload.
      // During hot reload, the recorder can try to capture items that still need
      // layout, which will throw. Prevent this.
      // if (kDebugMode && renderObject.debugNeedsLayout) {
      //   return;
      // }

      final transformMatrix = renderObject.getTransformTo(
        topElement.renderObject,
      );
      final untransformedPaintBounds = renderObject.paintBounds;

      final paintBounds = MatrixUtils.transformRect(
        transformMatrix,
        renderObject.paintBounds,
      );
      // Don't capture things that take up no space.
      if (paintBounds.width == 0 && paintBounds.height == 0) return;

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

      capturedSemantics.add(elementSemantics);

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
    TreeCapturePrivacy capturePrivacy,
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

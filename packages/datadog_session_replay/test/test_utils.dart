// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Because `Color` is defined in `dart:ui`, it can't be imported into the test library
// when running integration tests on Web. When / if we support SR on web, we'll need to look
// into a way to have the Color class work in the test test package.
import 'dart:math';
import 'dart:ui';

Random _random = Random();

Color randomColor({bool withRandomAlpha = false}) {
  int randomColorComponent() {
    return _random.nextInt(255);
  }

  return Color.fromARGB(
    withRandomAlpha ? randomColorComponent() : 255,
    randomColorComponent(),
    randomColorComponent(),
    randomColorComponent(),
  );
}

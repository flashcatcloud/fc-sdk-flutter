// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';

final specDependencyPattern = RegExp(
  r"\s+s\.dependency\s+'(?<dependency>Datadog.+)', '.+",
);

class PinPodVersion extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    // Other packages can keep looser version constraints
    if (args.packageName == 'datadog_flutter_plugin') {
      if (!await _pinPodspecVersion(args, logger)) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _pinPodspecVersion(CommandArguments args, Logger logger) async {
    final podspecLocation = 'ios/${args.packageName}.podspec';

    final file = File(
      path.join(
        args.gitDir.path,
        'packages/${args.packageName}',
        podspecLocation,
      ),
    );

    if (!file.existsSync()) {
      logger.warning(
        '⚠️ Could not find file $file. This is expected for non-core packages',
      );
      return true;
    }

    logger.info('ℹ️ Setting the iOS Pod Dependency to ${args.iOSRelease}');
    await transformFile(file, logger, args.dryRun, (element) {
      final match = specDependencyPattern.firstMatch(element);
      if (match != null) {
        element =
            "  s.dependency '${match.namedGroup('dependency')}', '${args.iOSRelease}'";
      }
      return element;
    });

    return true;
  }
}

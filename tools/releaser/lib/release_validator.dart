// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';
import 'github_cmd_wrapper.dart';
import 'helpers.dart';
import 'process_helper.dart';

final versionHeadingRegEx = RegExp(r'\s*#');
final changeItemRegEx = RegExp(r'\s*\*');

class ValidateReleaseCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final gitRoot = args.gitDir.path;
    logger.finest(' -- Monorepo root is $gitRoot');
    final packagePath = path.join(gitRoot, 'packages', args.packageName);
    logger.finest(' -- Package root is $packagePath');

    if (!args.dryRun && !args.skipGitChecks) {
      if (!await _validateBranchState(args.gitDir, logger)) {
        return false;
      }
    }

    // From here on out, we can validate multiple rules before returning.
    bool isValid = true;

    isValid &= _validateVersionNumber(args.version, logger);

    if (isValid) {
      if (hasNativeDependency(args.packageName)) {
        if (!await _validateiOSRelease(packagePath, args, logger)) {
          return false;
        }
        if (!await _validateAndroidRelease(packagePath, args, logger)) {
          return false;
        }
      }
    }

    return isValid;
  }

  bool _validateVersionNumber(String versionNumber, Logger logger) {
    try {
      final _ = Version.parse(versionNumber);
      return true;
    } on FormatException {
      logger.shout(
          '❌ Version $versionNumber does not parse properly as a semantic version');
    }
    return false;
  }

  Future<bool> _validateBranchState(GitDir gitDir, Logger logger) async {
    // Don't allow unstaged changes
    if (!await gitDir.isWorkingTreeClean()) {
      logger.shout(
          '❌ Working tree is not clean. Please stage or revert your changes before attempting to release.');
      return false;
    }

    // Only allow release from develop or a release/* branch
    final currentBranch = await gitDir.currentBranch();
    if (!(currentBranch.branchName == 'develop' ||
        currentBranch.branchName.startsWith('release'))) {
      logger.shout(
          '❌ We really should only release from `develop` or another `release` branch.');
      return false;
    }

    return true;
  }

  Future<bool> _validateiOSRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    args.iOSRelease = await _validateReleaseVersion(
        args, 'DataDog/dd-sdk-ios', 'iOS', args.iOSRelease, logger);
    return args.iOSRelease != null;
  }

  Future<bool> _validateAndroidRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    args.androidRelease = await _validateReleaseVersion(
        args, 'DataDog/dd-sdk-android', 'Android', args.androidRelease, logger);

    return args.androidRelease != null;
  }

  Future<String?> _validateReleaseVersion(
    CommandArguments args,
    String repoName,
    String platform,
    String? release,
    Logger logger,
  ) async {
    // If we didn't specify a version get the current latest release from github.
    // If we did specify a release, check that it actually exists.
    final gh = GithubCommandWrapper(args.gitDir.path);
    if (release == null) {
      logger.fine('🌎 Fetching latest $platform release from github... ');
      final latestRelease = await gh.getLatestRelease(logger, repoName);
      logger.fine('ℹ️ Latest $platform release is ${latestRelease.name}');
      release = latestRelease.tagName;
    } else {
      final ghRelease = await gh.getReleaseByTagName(logger, repoName, release);
      if (ghRelease == null) {
        logger.shout(
            '❌ Could not find target $platform release $release. Please check the tag name');
        return null;
      }
    }

    logger.info('ℹ️ Releasing with $platform version $release.');

    return release;
  }
}

class ValidatePublishDryRun extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    logger.info(
        'ℹ️ Running `flutter pub publish --dry-run` in ${args.packageRoot}');
    final exitCode = await runProcess(
      'flutter',
      ['pub', 'publish', '--dry-run'],
      workingDirectory: args.packageRoot,
      stdout: (line) => logger.fine(line),
      stderr: (line) => logger.shout(line),
    );
    if (exitCode != 0) {
      logger.info('❌ Publish exited with code $exitCode.');
      logger.info('Fix the above errors and try again.');
      return false;
    } else {
      logger.info('✅ Publish dry-run went fine.');
    }

    return true;
  }
}

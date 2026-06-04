// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'precompute_response.g.dart';

@immutable
@JsonSerializable(createToJson: false)
final class PrecomputeResponse {
  final PrecomputeData data;

  const PrecomputeResponse({required this.data});

  factory PrecomputeResponse.fromJson(Map<String, Object?> json) =>
      _$PrecomputeResponseFromJson(json);
}

@immutable
@JsonSerializable(createToJson: false)
final class PrecomputeData {
  final PrecomputeAttributes attributes;

  const PrecomputeData({required this.attributes});

  factory PrecomputeData.fromJson(Map<String, Object?> json) =>
      _$PrecomputeDataFromJson(json);
}

@immutable
@JsonSerializable(createToJson: false)
final class PrecomputeAttributes {
  final DateTime? createdAt;
  final String? environment;
  final Map<String, Object?> flags;

  const PrecomputeAttributes({
    this.createdAt,
    this.environment,
    required this.flags,
  });

  factory PrecomputeAttributes.fromJson(Map<String, Object?> json) =>
      _$PrecomputeAttributesFromJson(json);
}

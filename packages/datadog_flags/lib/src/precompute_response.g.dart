// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'precompute_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrecomputeResponse _$PrecomputeResponseFromJson(Map<String, dynamic> json) =>
    PrecomputeResponse(
      data: PrecomputeData.fromJson(json['data'] as Map<String, dynamic>),
    );

PrecomputeData _$PrecomputeDataFromJson(Map<String, dynamic> json) =>
    PrecomputeData(
      attributes: PrecomputeAttributes.fromJson(
          json['attributes'] as Map<String, dynamic>),
    );

PrecomputeAttributes _$PrecomputeAttributesFromJson(
        Map<String, dynamic> json) =>
    PrecomputeAttributes(
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      environment: json['environment'] as String?,
      flags: json['flags'] as Map<String, dynamic>,
    );

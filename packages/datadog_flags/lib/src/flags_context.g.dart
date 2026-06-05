// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flags_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlagsEvaluationContext _$FlagsEvaluationContextFromJson(
        Map<String, dynamic> json) =>
    FlagsEvaluationContext(
      targetingKey: json['targetingKey'] as String?,
      attributes: json['attributes'] == null
          ? const {}
          : _attributesFromJson(json['attributes']),
    );

Map<String, dynamic> _$FlagsEvaluationContextToJson(
        FlagsEvaluationContext instance) =>
    <String, dynamic>{
      if (instance.targetingKey case final value?) 'targetingKey': value,
      'attributes': sanitizeJsonValue(instance.attributes),
    };

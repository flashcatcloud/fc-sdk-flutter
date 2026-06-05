// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'precompute_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PrecomputeRequestToJson(PrecomputeRequest instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestDataToJson(
        PrecomputeRequestData instance) =>
    <String, dynamic>{
      'type': instance.type,
      'attributes': instance.attributes.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestAttributesToJson(
        PrecomputeRequestAttributes instance) =>
    <String, dynamic>{
      'env': instance.env.toJson(),
      'subject': instance.subject.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestEnvToJson(
        PrecomputeRequestEnv instance) =>
    <String, dynamic>{
      'dd_env': instance.ddEnv,
    };

Map<String, dynamic> _$PrecomputeRequestSubjectToJson(
        PrecomputeRequestSubject instance) =>
    <String, dynamic>{
      if (instance.targetingKey case final value?) 'targeting_key': value,
      'targeting_attributes': sanitizeJsonValue(instance.targetingAttributes),
    };

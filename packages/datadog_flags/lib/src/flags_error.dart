// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

enum FlagEvaluationError {
  providerNotReady('PROVIDER_NOT_READY'),
  flagNotFound('FLAG_NOT_FOUND'),
  typeMismatch('TYPE_MISMATCH');

  final String code;

  const FlagEvaluationError(this.code);
}

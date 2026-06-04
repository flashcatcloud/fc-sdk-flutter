// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

export 'src/datadog_context.dart';
export 'src/flags_configuration.dart';
export 'src/flags_context.dart';
export 'src/flags_error.dart';
export 'src/flags_site.dart';

import 'src/flags_context.dart';

typedef FlagsEvaluationContext = DatadogFlagsEvaluationContext;

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'src/flags_client.dart';

export 'src/datadog_context.dart' show DatadogFlagsContext, DatadogFlagsSite;
export 'src/datadog_flags.dart' show DatadogFlags;
export 'src/flags_client.dart' show DatadogFlagsClient;
export 'src/flags_configuration.dart' show DatadogFlagsConfiguration;
export 'src/flags_context.dart' show FlagsEvaluationContext;
export 'src/flags_details.dart' show FlagDetails;
export 'src/flags_error.dart' show FlagEvaluationError;

typedef FlagsClient = DatadogFlagsClient;

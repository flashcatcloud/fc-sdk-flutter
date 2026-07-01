// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogCore
import DatadogInternal

public extension TrackingConsent {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "TrackingConsent.granted": return .granted
        case "TrackingConsent.notGranted": return .notGranted
        case "TrackingConsent.pending": return .pending
        default: return .pending
        }
    }
}

public extension Datadog.Configuration.BatchSize {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "BatchSize.small": return .small
        case "BatchSize.medium": return .medium
        case "BatchSize.large": return .large
        default: return .medium
        }
    }
}

public extension Datadog.Configuration.UploadFrequency {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "UploadFrequency.frequent": return .frequent
        case "UploadFrequency.average": return .average
        case "UploadFrequency.rare": return .rare
        default: return .average
        }
    }
}

public extension Datadog.Configuration.BatchProcessingLevel {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "BatchProcessingLevel.low": return .low
        case "BatchProcessingLevel.medium": return .medium
        case "BatchProcessingLevel.high": return .high
        default: return .medium
        }
    }
}

public extension FlashcatSite {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "FlashcatSite.cn": return .cn
        case "FlashcatSite.staging": return .staging
        default: return .cn
        }
    }
}

extension CoreLoggerLevel {
    static func parseFromFlutter(_ value: String) -> Self {
        switch value {
        case "CoreLoggerLevel.debug": return .debug
        case "CoreLoggerLevel.warn": return .warn
        case "CoreLoggerLevel.error": return .error
        case "CoreLoggerLevel.critical": return .critical
        default: return .debug
        }
    }
}

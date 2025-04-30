// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

internal struct RequestBuilder: FeatureRequestBuilder {
    private static let newlineByte = "\n".data(using: .utf8)! // swiftlint:disable:this force_unwrapping

    /// Custom URL for uploading data to.
    let customUploadURL: URL?
    /// Sends telemetry through sdk core.
    let telemetry: Telemetry
    /// Builds multipart form for request's body.
    var multipartBuilder: MultipartFormDataBuilder = MultipartFormData()

    func request(for events: [Event], with context: DatadogContext, execution: DatadogInternal.ExecutionContext) throws -> URLRequest {
        let source = context.source

        // If we can't decode `events: [Data]` there is no way to recover, so we throw an
        // error to let the core delete the batch:
        do {
            let decoder = JSONDecoder()
            let wrappers: [RecordWrapper] = try events.compactMap {
                try decoder.decode(RecordWrapper.self, from: $0.data)
            }
            let segments = try wrappers.map { try $0.extractEnrichedRecord() }
                .map { try SegmentJSON($0, source: source) }
                .merge()

            return try createRequest(segments: segments, context: context)
        } catch let error {
            print("Error \(error)")
            throw error
        }
    }

    private func createRequest(segments: [SegmentJSON], context: DatadogContext) throws -> URLRequest {
        var multipart = multipartBuilder

        let builder = URLRequestBuilder(
            url: url(with: context),
            queryItems: [],
            headers: [
                .contentTypeHeader(contentType: .multipartFormData(boundary: multipart.boundary)),
                .userAgentHeader(appName: context.applicationName, appVersion: context.version, device: context.device),
                .ddAPIKeyHeader(clientToken: context.clientToken),
                .ddEVPOriginHeader(source: context.source),
                .ddEVPOriginVersionHeader(sdkVersion: context.sdkVersion),
                .ddRequestIDHeader()
            ],
            telemetry: telemetry
        )

        let jsonEncoder = JSONEncoder()

        let metadata = try segments.enumerated().map { index, segment in
            let json = segment.toJSONObject()
            // Session Replay BE accepts compressed segment data followed by newline character (before compression):
            let data = try JSONSerialization.data(withJSONObject: json) + RequestBuilder.newlineByte
            let compressedData = try SRCompression.compress(data: data)
            // Compressed segment is sent within multipart form data - with some of segment (metadata)
            // attributes listed as form fields:
            multipart.addFormData(
                name: "segment",
                filename: "file\(index)",
                data: compressedData,
                mimeType: "application/octet-stream"
            )
            return Metadata(
                application: .init(id: segment.applicationID),
                end: segment.end,
                hasFullSnapshot: segment.hasFullSnapshot,
                indexInView: segment.indexInView,
                recordsCount: segment.recordsCount,
                session: .init(id: segment.sessionID),
                source: segment.source,
                start: segment.start,
                view: .init(id: segment.viewID),
                rawSegmentSize: data.count,
                compressedSegmentSize: compressedData.count
            )
        }

        let encodedMetadata = try jsonEncoder.encode(metadata)
        multipart.addFormData(
            name: "event",
            filename: "blob",
            data: encodedMetadata,
            mimeType: "application/json"
        )

        // Data is already compressed, so request building request w/o compression:
        return builder.uploadRequest(with: multipart.build(), compress: false)
    }

    private func url(with context: DatadogContext) -> URL {
        customUploadURL ?? context.site.endpoint.appendingPathComponent("api/v2/replay")
    }
}

internal struct Metadata: Codable {
    let application: Application
    let end: Int64
    let hasFullSnapshot: Bool?
    let indexInView: Int64?
    let recordsCount: Int64
    let session: Session
    let source: String
    let start: Int64
    let view: View
    let rawSegmentSize: Int
    let compressedSegmentSize: Int

    enum CodingKeys: String, CodingKey {
        case application = "application"
        case end = "end"
        case hasFullSnapshot = "has_full_snapshot"
        case indexInView = "index_in_view"
        case recordsCount = "records_count"
        case session = "session"
        case source = "source"
        case start = "start"
        case view = "view"
        case rawSegmentSize = "raw_segment_size"
        case compressedSegmentSize = "compressed_segment_size"
    }

    public struct Application: Codable {
        /// UUID of the application
        public let id: String

        enum CodingKeys: String, CodingKey {
            case id = "id"
        }
    }

    /// Session properties
    public struct Session: Codable {
        /// UUID of the session
        public let id: String

        enum CodingKeys: String, CodingKey {
            case id = "id"
        }
    }

    public struct View: Codable {
        /// UUID of the view
        public let id: String

        enum CodingKeys: String, CodingKey {
            case id = "id"
        }
    }
}

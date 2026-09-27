import Foundation

/// A message received from a Cast device, with its JSON payload pre-parsed.
public struct InboundMessage: Sendable, Hashable {
    /// The raw protocol message.
    public let raw: CastMessage
    /// The parsed JSON payload, or `nil` for binary or non-JSON payloads.
    public let json: JSONValue?

    public init(_ raw: CastMessage) {
        self.raw = raw
        if let string = raw.stringPayload, let data = string.data(using: .utf8) {
            json = try? JSONDecoder().decode(JSONValue.self, from: data)
        } else {
            json = nil
        }
    }

    public var namespace: CastNamespace { CastNamespace(raw.namespace) }
    public var sourceID: String { raw.sourceID }
    public var destinationID: String { raw.destinationID }

    /// The `type` field of the JSON payload, e.g. `RECEIVER_STATUS`.
    public var type: String? { json?["type"]?.stringValue }

    /// The `requestId` the message responds to; `0` or `nil` for unsolicited messages.
    public var requestID: Int? { json?["requestId"]?.intValue }

    /// Decodes the payload as `T`.
    public func decode<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        guard let string = raw.stringPayload, let data = string.data(using: .utf8) else {
            throw CastError.unexpectedResponse("Message has no string payload")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

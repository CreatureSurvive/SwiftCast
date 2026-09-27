/// A string-backed enumeration that tolerates values added in future
/// versions of the Cast protocol by preserving them as `unknown`.
public protocol OpenStringEnum: Codable, Sendable, Hashable, RawRepresentable where RawValue == String {
    static var knownCases: [Self] { get }
    static func unknown(_ rawValue: String) -> Self
}

extension OpenStringEnum {
    public init(rawValue: String) {
        self = Self.resolve(rawValue)
    }

    public init(from decoder: any Decoder) throws {
        self = Self.resolve(try decoder.singleValueContainer().decode(String.self))
    }

    private static func resolve(_ rawValue: String) -> Self {
        knownCases.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

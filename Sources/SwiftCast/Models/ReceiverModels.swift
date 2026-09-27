import Foundation

/// Well-known Cast receiver application identifiers.
public struct CastAppID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Google's Default Media Receiver — plays audio, video and images
    /// supported by the device without a custom receiver app.
    public static let defaultMediaReceiver: CastAppID = "CC1AD845"
    /// The Backdrop / idle-screen application.
    public static let backdrop: CastAppID = "E8C28D3C"
    /// YouTube.
    public static let youTube: CastAppID = "233637DE"
    /// Jellyfin's stable custom receiver.
    public static let jellyfin: CastAppID = "F007D354"
    /// Jellyfin's unstable (development) custom receiver.
    public static let jellyfinUnstable: CastAppID = "6F511C87"
}

/// The volume of a Cast device or stream.
public struct CastVolume: Codable, Sendable, Hashable {
    public enum ControlType: String, Codable, Sendable, Hashable {
        /// The device volume can be set to any level.
        case attenuation
        /// The device volume can only be changed in fixed steps.
        case master
        /// The volume cannot be changed.
        case fixed
    }

    /// Level between 0.0 and 1.0.
    public var level: Double?
    public var muted: Bool?
    public var controlType: ControlType?
    /// The size of a single volume step, if provided.
    public var stepInterval: Double?

    public init(level: Double? = nil, muted: Bool? = nil, controlType: ControlType? = nil, stepInterval: Double? = nil) {
        self.level = level
        self.muted = muted
        self.controlType = controlType
        self.stepInterval = stepInterval
    }
}

/// A running application on the receiver.
public struct CastApplication: Codable, Sendable, Hashable, Identifiable {
    public struct Namespace: Codable, Sendable, Hashable {
        public var name: String
    }

    public var appId: CastAppID
    public var displayName: String?
    public var sessionId: String
    /// The virtual-connection destination for talking to this app.
    public var transportId: String
    public var statusText: String?
    public var namespaces: [Namespace]?
    public var isIdleScreen: Bool?
    public var launchedFromCloud: Bool?
    public var iconUrl: String?
    public var universalAppId: String?

    public var id: String { sessionId }

    /// Whether the application advertises support for a namespace.
    public func supports(_ namespace: CastNamespace) -> Bool {
        namespaces?.contains { $0.name == namespace.rawValue } ?? false
    }
}

/// The status of the Cast device's platform receiver.
public struct ReceiverStatus: Codable, Sendable, Hashable {
    public var applications: [CastApplication]?
    public var volume: CastVolume?
    public var isActiveInput: Bool?
    public var isStandBy: Bool?

    public init(applications: [CastApplication]? = nil, volume: CastVolume? = nil, isActiveInput: Bool? = nil, isStandBy: Bool? = nil) {
        self.applications = applications
        self.volume = volume
        self.isActiveInput = isActiveInput
        self.isStandBy = isStandBy
    }

    /// The first non-idle-screen application, if any.
    public var foregroundApplication: CastApplication? {
        applications?.first { $0.isIdleScreen != true }
    }

    /// Returns the running application with the given identifier.
    public func application(_ appID: CastAppID) -> CastApplication? {
        applications?.first { $0.appId == appID }
    }
}

/// App availability as reported by `GET_APP_AVAILABILITY`.
public enum CastAppAvailability: String, Codable, Sendable, Hashable {
    case available = "APP_AVAILABLE"
    case unavailable = "APP_UNAVAILABLE"
}

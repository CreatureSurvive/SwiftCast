/// Well-known Cast V2 message namespaces.
public struct CastNamespace: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    /// Virtual connection management (`CONNECT` / `CLOSE`).
    public static let connection: CastNamespace = "urn:x-cast:com.google.cast.tp.connection"
    /// Keep-alive (`PING` / `PONG`).
    public static let heartbeat: CastNamespace = "urn:x-cast:com.google.cast.tp.heartbeat"
    /// Device authentication (binary payloads).
    public static let deviceAuth: CastNamespace = "urn:x-cast:com.google.cast.tp.deviceauth"
    /// Receiver platform control: app launch/stop, volume, status.
    public static let receiver: CastNamespace = "urn:x-cast:com.google.cast.receiver"
    /// Media playback control for media-capable receiver apps.
    public static let media: CastNamespace = "urn:x-cast:com.google.cast.media"
    /// Multizone (speaker groups) status.
    public static let multizone: CastNamespace = "urn:x-cast:com.google.cast.multizone"
}

/// Well-known virtual-connection endpoints.
public enum CastEndpoint {
    /// The platform receiver on every Cast device.
    public static let platformReceiver = "receiver-0"
    /// Destination used by receivers for broadcast (unsolicited) messages.
    public static let broadcast = "*"
}

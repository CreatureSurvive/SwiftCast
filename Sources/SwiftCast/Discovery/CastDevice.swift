import Foundation
import Network

/// A Cast device discovered on the local network (or specified manually).
public struct CastDevice: Sendable, Hashable, Identifiable, CustomStringConvertible {
    /// Device capabilities advertised in the `ca` TXT record.
    public struct Capabilities: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let videoOut = Capabilities(rawValue: 1 << 0)
        public static let videoIn = Capabilities(rawValue: 1 << 1)
        public static let audioOut = Capabilities(rawValue: 1 << 2)
        public static let audioIn = Capabilities(rawValue: 1 << 3)
        public static let developerMode = Capabilities(rawValue: 1 << 4)
        public static let multizoneGroup = Capabilities(rawValue: 1 << 5)
    }

    /// Stable device identifier (the `id` TXT record, or the service name).
    public let id: String
    /// User-visible device name, e.g. "Living Room TV".
    public let name: String
    /// Hardware model, e.g. "Chromecast Ultra".
    public let modelName: String?
    public let capabilities: Capabilities
    /// Text describing what the device is currently doing (e.g. the app name).
    public let statusText: String?
    /// How to connect to the device.
    public let endpoint: NWEndpoint
    /// All TXT record entries advertised by the device.
    public let txtRecord: [String: String]

    public init(
        id: String,
        name: String,
        modelName: String? = nil,
        capabilities: Capabilities = [.videoOut, .audioOut],
        statusText: String? = nil,
        endpoint: NWEndpoint,
        txtRecord: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.capabilities = capabilities
        self.statusText = statusText
        self.endpoint = endpoint
        self.txtRecord = txtRecord
    }

    /// A device at a known address.
    public init(host: String, port: UInt16 = 8009, name: String? = nil) {
        self.init(
            id: "\(host):\(port)",
            name: name ?? host,
            endpoint: .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 8009)
        )
    }

    /// Builds a device from a Bonjour service and its TXT record.
    init(serviceEndpoint: NWEndpoint, txt: [String: String]) {
        var serviceName = ""
        if case .service(let name, _, _, _) = serviceEndpoint { serviceName = name }
        self.init(
            id: txt["id"].flatMap { $0.isEmpty ? nil : $0 } ?? serviceName,
            name: txt["fn"].flatMap { $0.isEmpty ? nil : $0 } ?? serviceName,
            modelName: txt["md"].flatMap { $0.isEmpty ? nil : $0 },
            capabilities: txt["ca"].flatMap(Int.init).map(Capabilities.init(rawValue:)) ?? [],
            statusText: txt["rs"].flatMap { $0.isEmpty ? nil : $0 },
            endpoint: serviceEndpoint,
            txtRecord: txt
        )
    }

    /// Whether the device is a speaker group rather than a single device.
    public var isGroup: Bool { capabilities.contains(.multizoneGroup) }

    /// Whether the device can display video.
    public var supportsVideo: Bool { capabilities.contains(.videoOut) }

    public var description: String {
        "\(name)\(modelName.map { " (\($0))" } ?? "")"
    }
}

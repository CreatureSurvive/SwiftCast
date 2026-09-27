import Foundation
import Network
import Observation

/// Discovers Cast devices on the local network using Bonjour (`_googlecast._tcp`).
///
/// On iOS, tvOS and visionOS your app's Info.plist must include
/// `NSLocalNetworkUsageDescription` and list `_googlecast._tcp` under
/// `NSBonjourServices`.
public enum CastDiscovery {
    /// The Bonjour service type advertised by Cast devices.
    public static let serviceType = "_googlecast._tcp"

    /// Browser status reported through ``events()``.
    public enum Event: Sendable {
        /// The complete, current set of devices, sorted by name.
        case devices([CastDevice])
        /// The browser is blocked, typically because Local Network access was
        /// denied. Browsing resumes automatically if access is granted.
        case waiting(String)
        /// The browser failed and stopped.
        case failed(String)
    }

    /// Browses for devices. Each call starts an independent browser that
    /// stops when the consumer stops iterating.
    public static func events(domain: String? = nil) -> AsyncStream<Event> {
        AsyncStream { continuation in
            let parameters = NWParameters()
            parameters.includePeerToPeer = false
            let browser = NWBrowser(
                for: .bonjourWithTXTRecord(type: serviceType, domain: domain),
                using: parameters
            )
            browser.stateUpdateHandler = { state in
                switch state {
                case .waiting(let error):
                    continuation.yield(.waiting(error.localizedDescription))
                case .failed(let error):
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                default:
                    break
                }
            }
            browser.browseResultsChangedHandler = { results, _ in
                continuation.yield(.devices(devices(from: results)))
            }
            continuation.onTermination = { _ in browser.cancel() }
            browser.start(queue: DispatchQueue(label: "SwiftCast.CastDiscovery"))
        }
    }

    /// Streams the current set of devices whenever it changes.
    public static func devices(domain: String? = nil) -> AsyncStream<[CastDevice]> {
        let events = events(domain: domain)
        return AsyncStream { continuation in
            let task = Task {
                for await event in events {
                    if case .devices(let devices) = event { continuation.yield(devices) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Browses for `duration` and returns every device found.
    public static func scan(for duration: Duration = .seconds(3)) async -> [CastDevice] {
        await withTaskGroup(of: [CastDevice]?.self) { group in
            group.addTask {
                var latest: [CastDevice] = []
                for await devices in devices() {
                    latest = devices
                    if Task.isCancelled { break }
                }
                return latest
            }
            group.addTask {
                try? await Task.sleep(for: duration)
                return nil
            }
            // The timer finishes first; cancelling ends the browse loop.
            _ = await group.next()
            group.cancelAll()
            var result: [CastDevice] = []
            while let next = await group.next() {
                if let next { result = next }
            }
            return result
        }
    }

    static func devices(from results: Set<NWBrowser.Result>) -> [CastDevice] {
        var byID: [String: CastDevice] = [:]
        for result in results {
            var txt: [String: String] = [:]
            if case .bonjour(let record) = result.metadata {
                for (key, entry) in record {
                    if case .string(let value) = entry { txt[key] = value } else { txt[key] = "" }
                }
            }
            let device = CastDevice(serviceEndpoint: result.endpoint, txt: txt)
            // The same device can be reported once per network interface.
            if byID[device.id] == nil { byID[device.id] = device }
        }
        return byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// An observable Cast device browser for SwiftUI.
///
/// ```swift
/// @State private var browser = CastDeviceBrowser()
///
/// List(browser.devices) { Text($0.name) }
///     .task { await browser.run() }
/// ```
@MainActor
@Observable
public final class CastDeviceBrowser {
    /// Devices currently visible on the network.
    public private(set) var devices: [CastDevice] = []
    /// A message describing why browsing is blocked or failed, if it is.
    public private(set) var problem: String?
    /// Whether the browser is running.
    public private(set) var isBrowsing = false

    public init() {}

    /// Browses until the calling task is cancelled (e.g. from `.task {}`).
    public func run() async {
        isBrowsing = true
        defer { isBrowsing = false }
        for await event in CastDiscovery.events() {
            switch event {
            case .devices(let found):
                devices = found
                problem = nil
            case .waiting(let message):
                problem = message
            case .failed(let message):
                problem = message
            }
        }
    }
}

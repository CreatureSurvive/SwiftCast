import Foundation

/// Controls the platform receiver of a Cast device: launching and stopping
/// applications, device volume and status.
public struct ReceiverController: Sendable {
    let client: CastClient

    private var destination: String { CastEndpoint.platformReceiver }

    /// Fetches the current receiver status.
    @discardableResult
    public func getStatus() async throws -> ReceiverStatus {
        let response = try await client.request(Request(type: "GET_STATUS"), namespace: .receiver, to: destination)
        return try decodeStatus(response)
    }

    /// Launches an application and returns it once it is running.
    ///
    /// If the application is already running it is relaunched by the
    /// receiver; use ``CastClient/launchMediaApp(_:)`` to join instead.
    public func launch(_ appID: CastAppID, timeout: Duration = .seconds(30)) async throws -> CastApplication {
        // Subscribe before sending so a status broadcast that races the
        // response is not missed.
        let updates = await client.receiverStatusUpdates()
        let response = try await client.request(LaunchRequest(appId: appID), namespace: .receiver, to: destination, timeout: timeout)
        if let app = try decodeStatus(response).application(appID) {
            return app
        }
        // Some receivers answer before the app has finished launching.
        return try await withThrowingTaskGroup(of: CastApplication.self) { group in
            group.addTask {
                for await status in updates {
                    if let app = status.application(appID) { return app }
                }
                throw CastError.notConnected
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CastError.launchFailed(reason: "Timed out waiting for application to start")
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    /// Stops a running application session.
    @discardableResult
    public func stop(sessionID: String) async throws -> ReceiverStatus {
        let response = try await client.request(StopRequest(sessionId: sessionID), namespace: .receiver, to: destination)
        return try decodeStatus(response)
    }

    /// Stops the given application if it is running.
    public func stop(_ application: CastApplication) async throws {
        try await stop(sessionID: application.sessionId)
    }

    /// Sets the device volume level (0.0–1.0).
    @discardableResult
    public func setVolume(_ level: Double) async throws -> ReceiverStatus {
        let clamped = min(max(level, 0), 1)
        let response = try await client.request(VolumeRequest(volume: CastVolume(level: clamped)), namespace: .receiver, to: destination)
        return try decodeStatus(response)
    }

    /// Mutes or unmutes the device.
    @discardableResult
    public func setMuted(_ muted: Bool) async throws -> ReceiverStatus {
        let response = try await client.request(VolumeRequest(volume: CastVolume(muted: muted)), namespace: .receiver, to: destination)
        return try decodeStatus(response)
    }

    /// Queries whether the device can run the given applications.
    public func availability(of appIDs: [CastAppID]) async throws -> [CastAppID: CastAppAvailability] {
        let response = try await client.request(AvailabilityRequest(appId: appIDs), namespace: .receiver, to: destination)
        guard let object = response.json?["availability"]?.objectValue else {
            throw CastError.unexpectedResponse("Missing availability")
        }
        var result: [CastAppID: CastAppAvailability] = [:]
        for (key, value) in object {
            if let raw = value.stringValue, let availability = CastAppAvailability(rawValue: raw) {
                result[CastAppID(key)] = availability
            }
        }
        return result
    }

    private func decodeStatus(_ message: InboundMessage) throws -> ReceiverStatus {
        guard message.type == "RECEIVER_STATUS", let json = message.json?["status"] else {
            throw CastError.unexpectedResponse(message.type ?? "untyped message")
        }
        let status = try json.decode(ReceiverStatus.self)
        return status
    }

    private struct Request: Encodable, Sendable { let type: String }
    private struct LaunchRequest: Encodable, Sendable { let type = "LAUNCH"; let appId: CastAppID }
    private struct StopRequest: Encodable, Sendable { let type = "STOP"; let sessionId: String }
    private struct VolumeRequest: Encodable, Sendable { let type = "SET_VOLUME"; let volume: CastVolume }
    private struct AvailabilityRequest: Encodable, Sendable { let type = "GET_APP_AVAILABILITY"; let appId: [CastAppID] }
}

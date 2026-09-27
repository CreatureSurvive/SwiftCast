import Foundation
import Testing
@testable import SwiftCast

@Suite("CastSession", .timeLimit(.minutes(1)))
@MainActor
struct SessionTests {
    let device = CastDevice(host: "192.0.2.1", name: "Test TV")

    @Test func connectLoadAndControl() async throws {
        let mock = MockReceiver()
        Fixtures.installDefaultReceiver(on: mock)
        let session = CastSession { _ in CastClient { mock } }

        try await session.connect(to: device)
        #expect(session.isConnected)
        #expect(session.volume == 0.5)
        #expect(session.mediaController == nil)

        try await session.load(MediaInformation(url: URL(string: "https://example.com/v.mp4")!, contentType: "video/mp4"))
        #expect(session.mediaStatus?.mediaSessionId == 1)
        #expect(session.duration == 596.5)

        try await session.pause()
        #expect(session.mediaStatus?.playerState == .paused)
        #expect(session.estimatedTime() == 42)
        try await session.togglePlayPause()
        #expect(session.isPlaying)

        await session.disconnect()
        #expect(session.connectionState == .disconnected)
        #expect(session.mediaStatus == nil)
    }

    @Test func joinsRunningApplicationOnConnect() async throws {
        let mock = MockReceiver()
        Fixtures.installDefaultReceiver(on: mock, appRunning: true)
        let session = CastSession { _ in CastClient { mock } }
        try await session.connect(to: device)
        #expect(session.mediaController != nil)
        #expect(mock.sentMessages(ofType: "LAUNCH").isEmpty)
    }

    @Test func reconnectsAfterConnectionLoss() async throws {
        let mocks = [MockReceiver(), MockReceiver()]
        mocks.forEach { Fixtures.installDefaultReceiver(on: $0, appRunning: true) }
        let index = Counter()
        let session = CastSession { _ in
            let mock = mocks[min(index.increment(), mocks.count) - 1]
            return CastClient { mock }
        }
        try await session.connect(to: device)
        #expect(session.isConnected)

        mocks[0].drop(with: CastError.connectionFailed("wifi blip"))
        try await eventually { await MainActor.run { if case .reconnecting = session.connectionState { true } else { false } } }
        try await eventually { await MainActor.run { session.isConnected && session.mediaController != nil } }
        #expect(mocks[1].sentMessages(ofType: "CONNECT").count >= 2) // platform + app
    }

    @Test func failsAfterExhaustingReconnects() async throws {
        let first = MockReceiver()
        Fixtures.installDefaultReceiver(on: first)
        let index = Counter()
        let session = CastSession { _ in
            if index.increment() == 1 { return CastClient { first } }
            let failing = MockReceiver()
            failing.failOpen(with: .connectionFailed("unreachable"))
            return CastClient { failing }
        }
        session.maximumReconnectAttempts = 2
        try await session.connect(to: device)
        first.drop(with: CastError.connectionFailed("gone"))
        try await eventually(timeout: .seconds(10)) {
            await MainActor.run { if case .failed = session.connectionState { true } else { false } }
        }
        #expect(session.connectionState == .failed(device, .connectionFailed("gone")))
    }

    @Test func clearsMediaWhenAppStopsRemotely() async throws {
        let mock = MockReceiver()
        Fixtures.installDefaultReceiver(on: mock, appRunning: true)
        let session = CastSession { _ in CastClient { mock } }
        try await session.connect(to: device)
        try await session.load(MediaInformation(url: URL(string: "https://example.com/v.mp4")!, contentType: "video/mp4"))
        mock.push(Fixtures.receiverStatus(apps: []), namespace: .receiver, to: "*")
        try await eventually { await MainActor.run { session.mediaController == nil && session.mediaStatus == nil } }
        #expect(session.isConnected)
    }
}

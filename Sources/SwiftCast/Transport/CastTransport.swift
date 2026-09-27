import Foundation

/// A bidirectional byte stream to a Cast device.
///
/// SwiftCast ships ``NetworkTransport`` (TLS over `Network.framework`).
/// Custom transports are useful for testing or tunnelling.
public protocol CastTransport: AnyObject, Sendable {
    /// Establishes the connection. Throws if the connection cannot be made.
    func open() async throws

    /// Writes bytes to the connection.
    func send(_ data: Data) async throws

    /// Bytes received from the device. The stream finishes when the
    /// connection closes and throws if the connection fails.
    ///
    /// Implementations must return the same stream on every access; it is
    /// consumed by a single reader.
    var inbound: AsyncThrowingStream<Data, any Error> { get }

    /// Closes the connection and finishes ``inbound``.
    func close()
}

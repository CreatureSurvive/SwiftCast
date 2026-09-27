import Foundation

/// Cast V2 framing: every message is prefixed with a 4-byte big-endian length.
enum FrameCodec {
    /// Largest frame accepted from a receiver. The Cast protocol caps
    /// messages at 64 KiB; we allow some headroom for non-conforming devices.
    static let maximumFrameLength = 1 << 20

    static func frame(_ message: CastMessage) -> Data {
        let body = message.serialized()
        var out = Data(capacity: body.count + 4)
        let length = UInt32(body.count).bigEndian
        withUnsafeBytes(of: length) { out.append(contentsOf: $0) }
        out.append(body)
        return out
    }
}

/// Incrementally reassembles length-prefixed frames from an arbitrary
/// sequence of byte chunks.
struct FrameDecoder {
    private var buffer = Data()

    /// Appends received bytes and returns every complete message now available.
    mutating func append(_ chunk: Data) throws -> [CastMessage] {
        buffer.append(chunk)
        var messages: [CastMessage] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            let length = buffer[start..<start + 4].reduce(0) { $0 << 8 | Int($1) }
            guard length <= FrameCodec.maximumFrameLength else {
                throw CastError.malformedMessage("Frame length \(length) exceeds limit")
            }
            guard buffer.count >= 4 + length else { break }
            let body = buffer[(start + 4)..<(start + 4 + length)]
            messages.append(try CastMessage(serializedData: Data(body)))
            buffer.removeSubrange(start..<(start + 4 + length))
        }
        // Re-base to keep indices small and avoid unbounded slice growth.
        if buffer.isEmpty { buffer = Data() }
        return messages
    }

    var bufferedByteCount: Int { buffer.count }
}

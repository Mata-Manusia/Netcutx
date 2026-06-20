import Foundation
import NetcutxBPF_C

public enum BPFError: LocalizedError {
    case openFailed(String)
    case sendFailed(String)
    case recvFailed(String)
    case notOpen

    public var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "BPF open failed: \(msg)"
        case .sendFailed(let msg): return "BPF send failed: \(msg)"
        case .recvFailed(let msg): return "BPF recv failed: \(msg)"
        case .notOpen: return "BPF device not open"
        }
    }
}

public struct BPFPacket {
    public let data: Data
    public let rawLength: Int

    public init(data: Data, rawLength: Int) {
        self.data = data
        self.rawLength = rawLength
    }
}

public final class NetcutxBPF {
    private var ctx: OpaquePointer?

    public var isOpen: Bool { ctx != nil }

    public init(interface: String) throws {
        guard let c = interface.withCString({ netcutx_bpf_open($0) }) else {
            let err = String(cString: netcutx_bpf_error(nil))
            throw BPFError.openFailed(err)
        }
        ctx = c
    }

    deinit {
        close()
    }

    public func send(frame: Data) throws {
        guard let ctx else { throw BPFError.notOpen }
        let count = frame.count
        let result = frame.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> ssize_t in
            guard let base = ptr.baseAddress else { return -1 }
            return netcutx_bpf_send(ctx, base.assumingMemoryBound(to: UInt8.self), count)
        }
        if result == -1 {
            throw BPFError.sendFailed(String(cString: netcutx_bpf_error(ctx)))
        }
    }

    public func receive(timeout: TimeInterval) throws -> BPFPacket? {
        guard let ctx else { throw BPFError.notOpen }
        let timeoutMs = Int(timeout * 1000)
        var buf = [UInt8](repeating: 0, count: 65535)
        let n = buf.withUnsafeMutableBufferPointer { ptr in
            netcutx_bpf_recv(ctx, ptr.baseAddress, ptr.count, Int32(timeoutMs))
        }
        if n == -1 {
            throw BPFError.recvFailed(String(cString: netcutx_bpf_error(ctx)))
        }
        if n == 0 { return nil }
        return BPFPacket(data: Data(bytes: buf, count: Int(n)), rawLength: Int(n))
    }

    public func close() {
        guard let ctx else { return }
        netcutx_bpf_close(ctx)
        self.ctx = nil
    }
}

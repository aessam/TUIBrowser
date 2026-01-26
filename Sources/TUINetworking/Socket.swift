// TUINetworking - BSD Socket Wrapper
// Low-level socket operations for TCP connections

import Foundation
import Darwin

/// Socket address family
public enum SocketFamily: Int32, Sendable {
    case inet = 2    // AF_INET
    case inet6 = 30  // AF_INET6

    public init(fromRaw value: Int32) {
        switch value {
        case AF_INET:
            self = .inet
        case AF_INET6:
            self = .inet6
        default:
            self = .inet
        }
    }
}

/// Socket type
public enum SocketType: Int32, Sendable {
    case stream = 1  // SOCK_STREAM (TCP)
    case dgram = 2   // SOCK_DGRAM (UDP)
}

/// BSD socket wrapper for TCP connections
public final class Socket: @unchecked Sendable {
    /// The underlying file descriptor
    public private(set) var fileDescriptor: Int32

    /// Whether the socket has been closed
    public private(set) var isClosed: Bool = false

    private let lock = NSLock()

    /// Create a socket from an existing file descriptor
    /// - Parameter fileDescriptor: The file descriptor to wrap
    public init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    deinit {
        close()
    }

    /// Create a new socket
    /// - Parameters:
    ///   - family: The address family (.inet or .inet6)
    ///   - type: The socket type (.stream for TCP)
    /// - Returns: A new Socket instance
    /// - Throws: NetworkError.socketCreationFailed if socket creation fails
    public static func create(family: SocketFamily = .inet, type: SocketType = .stream) throws -> Socket {
        let fd = Darwin.socket(family.rawValue, type.rawValue, 0)
        guard fd >= 0 else {
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.socketCreationFailed("Failed to create socket: \(errorMessage)")
        }
        return Socket(fileDescriptor: fd)
    }

    /// Connect to a remote address
    /// - Parameter addressInfo: The address info from DNS resolution
    /// - Throws: NetworkError.connectionFailed if connection fails
    public func connect(to addressInfo: AddressInfo) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else {
            throw NetworkError.connectionFailed("Socket is closed")
        }

        let result = addressInfo.addressData.withUnsafeBytes { buffer -> Int32 in
            guard let pointer = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                return -1
            }
            return Darwin.connect(fileDescriptor, pointer, addressInfo.addressLength)
        }

        guard result == 0 else {
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.connectionFailed("Failed to connect: \(errorMessage)")
        }
    }

    /// Set socket timeout for send and receive operations
    /// - Parameter seconds: Timeout in seconds
    /// - Throws: NetworkError if setting timeout fails
    public func setTimeout(seconds: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else {
            throw NetworkError.connectionFailed("Socket is closed")
        }

        var timeout = timeval(tv_sec: seconds, tv_usec: 0)

        // Set receive timeout
        var result = setsockopt(fileDescriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard result == 0 else {
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.connectionFailed("Failed to set receive timeout: \(errorMessage)")
        }

        // Set send timeout
        result = setsockopt(fileDescriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard result == 0 else {
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.connectionFailed("Failed to set send timeout: \(errorMessage)")
        }
    }

    /// Send data through the socket
    /// - Parameter data: The data to send
    /// - Returns: Number of bytes sent
    /// - Throws: NetworkError.sendFailed if send fails
    @discardableResult
    public func send(_ data: Data) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else {
            throw NetworkError.sendFailed("Socket is closed")
        }

        let bytesSent = data.withUnsafeBytes { buffer -> Int in
            guard let pointer = buffer.baseAddress else { return -1 }
            return Darwin.send(fileDescriptor, pointer, data.count, 0)
        }

        guard bytesSent >= 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw NetworkError.timeout
            }
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.sendFailed("Failed to send data: \(errorMessage)")
        }

        return bytesSent
    }

    /// Send a string through the socket
    /// - Parameter string: The string to send (will be encoded as UTF-8)
    /// - Returns: Number of bytes sent
    /// - Throws: NetworkError.sendFailed if send fails
    @discardableResult
    public func send(_ string: String) throws -> Int {
        guard let data = string.data(using: .utf8) else {
            throw NetworkError.sendFailed("Failed to encode string as UTF-8")
        }
        return try send(data)
    }

    /// Receive data from the socket
    /// - Parameter maxBytes: Maximum number of bytes to receive
    /// - Returns: The received data
    /// - Throws: NetworkError.receiveFailed if receive fails
    public func receive(maxBytes: Int = 4096) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else {
            throw NetworkError.receiveFailed("Socket is closed")
        }

        var buffer = [UInt8](repeating: 0, count: maxBytes)
        let bytesReceived = Darwin.recv(fileDescriptor, &buffer, maxBytes, 0)

        if bytesReceived < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw NetworkError.timeout
            }
            let errorMessage = String(cString: strerror(errno))
            throw NetworkError.receiveFailed("Failed to receive data: \(errorMessage)")
        }

        if bytesReceived == 0 {
            throw NetworkError.connectionClosed
        }

        return Data(buffer[0..<bytesReceived])
    }

    /// Close the socket
    public func close() {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else { return }

        Darwin.close(fileDescriptor)
        isClosed = true
    }
}

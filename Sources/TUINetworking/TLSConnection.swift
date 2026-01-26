// TUINetworking - TLS Connection
// HTTPS support using macOS SecureTransport framework

import Foundation
import Security

/// TLS/SSL connection wrapper using SecureTransport
public final class TLSConnection: @unchecked Sendable {
    /// The underlying socket
    private let socket: Socket

    /// The hostname for SNI and certificate verification
    private let hostname: String

    /// The SSL context
    private var sslContext: SSLContext?

    /// Whether the TLS handshake has completed
    public private(set) var isConnected: Bool = false

    private let lock = NSLock()

    /// Create a new TLS connection
    /// - Parameters:
    ///   - socket: The underlying connected socket
    ///   - hostname: The hostname for SNI
    public init(socket: Socket, hostname: String) {
        self.socket = socket
        self.hostname = hostname
    }

    deinit {
        close()
    }

    /// Perform the TLS handshake
    /// - Throws: NetworkError.tlsHandshakeFailed if handshake fails
    public func handshake() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isConnected else { return }

        // Create SSL context
        guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
            throw NetworkError.tlsHandshakeFailed("Failed to create SSL context")
        }
        sslContext = context

        // Set up callbacks for reading/writing through our socket
        var status = SSLSetIOFuncs(context, tlsReadCallback, tlsWriteCallback)
        guard status == errSecSuccess else {
            throw NetworkError.tlsHandshakeFailed("Failed to set IO functions: \(status)")
        }

        // Store socket pointer for callbacks
        let socketPointer = Unmanaged.passUnretained(socket).toOpaque()
        status = SSLSetConnection(context, socketPointer)
        guard status == errSecSuccess else {
            throw NetworkError.tlsHandshakeFailed("Failed to set connection: \(status)")
        }

        // Set hostname for SNI
        status = SSLSetPeerDomainName(context, hostname, hostname.utf8.count)
        guard status == errSecSuccess else {
            throw NetworkError.tlsHandshakeFailed("Failed to set peer domain name: \(status)")
        }

        // Perform handshake
        repeat {
            status = SSLHandshake(context)
        } while status == errSSLWouldBlock

        guard status == errSecSuccess else {
            let errorMessage = securityErrorMessage(status)
            throw NetworkError.tlsHandshakeFailed("TLS handshake failed: \(errorMessage)")
        }

        isConnected = true
    }

    /// Send data through the TLS connection
    /// - Parameter data: The data to send
    /// - Returns: Number of bytes sent
    /// - Throws: NetworkError.sendFailed if send fails
    @discardableResult
    public func send(_ data: Data) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        guard isConnected, let context = sslContext else {
            throw NetworkError.sendFailed("TLS connection not established")
        }

        var processed = 0
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let pointer = buffer.baseAddress else { return errSecParam }
            return SSLWrite(context, pointer, data.count, &processed)
        }

        guard status == errSecSuccess || status == errSSLWouldBlock else {
            let errorMessage = securityErrorMessage(status)
            throw NetworkError.sendFailed("TLS send failed: \(errorMessage)")
        }

        return processed
    }

    /// Send a string through the TLS connection
    /// - Parameter string: The string to send (UTF-8 encoded)
    /// - Returns: Number of bytes sent
    /// - Throws: NetworkError.sendFailed if send fails
    @discardableResult
    public func send(_ string: String) throws -> Int {
        guard let data = string.data(using: .utf8) else {
            throw NetworkError.sendFailed("Failed to encode string as UTF-8")
        }
        return try send(data)
    }

    /// Receive data from the TLS connection
    /// - Parameter maxBytes: Maximum number of bytes to receive
    /// - Returns: The received data
    /// - Throws: NetworkError.receiveFailed if receive fails
    public func receive(maxBytes: Int = 4096) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard isConnected, let context = sslContext else {
            throw NetworkError.receiveFailed("TLS connection not established")
        }

        var buffer = [UInt8](repeating: 0, count: maxBytes)
        var processed = 0

        let status = SSLRead(context, &buffer, maxBytes, &processed)

        if status == errSSLClosedGraceful || status == errSSLClosedAbort {
            throw NetworkError.connectionClosed
        }

        guard status == errSecSuccess || status == errSSLWouldBlock else {
            let errorMessage = securityErrorMessage(status)
            throw NetworkError.receiveFailed("TLS receive failed: \(errorMessage)")
        }

        if processed == 0 {
            throw NetworkError.connectionClosed
        }

        return Data(buffer[0..<processed])
    }

    /// Close the TLS connection
    public func close() {
        lock.lock()
        defer { lock.unlock() }

        if let context = sslContext {
            SSLClose(context)
            sslContext = nil
        }
        isConnected = false
    }

    // MARK: - Private Helpers

    private func securityErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSSLProtocol:
            return "SSL protocol error"
        case errSSLNegotiation:
            return "SSL negotiation failed"
        case errSSLFatalAlert:
            return "SSL fatal alert"
        case errSSLWouldBlock:
            return "SSL would block"
        case errSSLSessionNotFound:
            return "SSL session not found"
        case errSSLClosedGraceful:
            return "SSL connection closed gracefully"
        case errSSLClosedAbort:
            return "SSL connection closed abruptly"
        case errSSLXCertChainInvalid:
            return "SSL certificate chain invalid"
        case errSSLBadCert:
            return "SSL bad certificate"
        case errSSLCrypto:
            return "SSL crypto error"
        case errSSLInternal:
            return "SSL internal error"
        case errSSLCertExpired:
            return "SSL certificate expired"
        case errSSLCertNotYetValid:
            return "SSL certificate not yet valid"
        case errSSLUnknownRootCert:
            return "SSL unknown root certificate"
        case errSSLNoRootCert:
            return "SSL no root certificate"
        case errSSLHostNameMismatch:
            return "SSL hostname mismatch"
        case errSSLPeerHandshakeFail:
            return "SSL peer handshake failed"
        case errSSLConnectionRefused:
            return "SSL connection refused"
        case errSSLDecryptionFail:
            return "SSL decryption failed"
        case errSSLRecordOverflow:
            return "SSL record overflow"
        default:
            return "Error code: \(status)"
        }
    }
}

// MARK: - SecureTransport Callbacks

/// Callback for SecureTransport to read data
private func tlsReadCallback(
    connection: SSLConnectionRef,
    data: UnsafeMutableRawPointer,
    dataLength: UnsafeMutablePointer<Int>
) -> OSStatus {
    let socket = Unmanaged<Socket>.fromOpaque(connection).takeUnretainedValue()

    do {
        let received = try socket.receive(maxBytes: dataLength.pointee)
        received.copyBytes(to: data.assumingMemoryBound(to: UInt8.self), count: received.count)
        dataLength.pointee = received.count
        return errSecSuccess
    } catch NetworkError.timeout {
        dataLength.pointee = 0
        return errSSLWouldBlock
    } catch NetworkError.connectionClosed {
        dataLength.pointee = 0
        return errSSLClosedGraceful
    } catch {
        dataLength.pointee = 0
        return errSSLInternal
    }
}

/// Callback for SecureTransport to write data
private func tlsWriteCallback(
    connection: SSLConnectionRef,
    data: UnsafeRawPointer,
    dataLength: UnsafeMutablePointer<Int>
) -> OSStatus {
    let socket = Unmanaged<Socket>.fromOpaque(connection).takeUnretainedValue()

    do {
        let dataToSend = Data(bytes: data, count: dataLength.pointee)
        let sent = try socket.send(dataToSend)
        dataLength.pointee = sent
        return errSecSuccess
    } catch NetworkError.timeout {
        dataLength.pointee = 0
        return errSSLWouldBlock
    } catch {
        dataLength.pointee = 0
        return errSSLInternal
    }
}

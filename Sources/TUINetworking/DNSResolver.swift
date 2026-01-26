// TUINetworking - DNS Resolution
// Uses getaddrinfo for hostname resolution

import Foundation
import Darwin

/// Information about a resolved address
public struct AddressInfo: Sendable {
    /// Address family (AF_INET or AF_INET6)
    public let family: Int32
    /// Socket type (SOCK_STREAM or SOCK_DGRAM)
    public let socketType: Int32
    /// Protocol (usually IPPROTO_TCP)
    public let socketProtocol: Int32
    /// Raw address data for use with connect()
    public let addressData: Data
    /// Length of address data
    public let addressLength: socklen_t

    public init(family: Int32, socketType: Int32, socketProtocol: Int32, addressData: Data, addressLength: socklen_t) {
        self.family = family
        self.socketType = socketType
        self.socketProtocol = socketProtocol
        self.addressData = addressData
        self.addressLength = addressLength
    }
}

/// DNS resolver using system getaddrinfo
public struct DNSResolver: Sendable {

    /// Resolve a hostname to a list of IP address strings
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: Array of IP address strings
    /// - Throws: NetworkError.dnsResolutionFailed if resolution fails
    public static func resolve(hostname: String) throws -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_CANONNAME

        var result: UnsafeMutablePointer<addrinfo>?

        let status = getaddrinfo(hostname, nil, &hints, &result)
        guard status == 0 else {
            let errorMessage = String(cString: gai_strerror(status))
            throw NetworkError.dnsResolutionFailed("Failed to resolve \(hostname): \(errorMessage)")
        }

        defer { freeaddrinfo(result) }

        var addresses: [String] = []
        var current = result

        while let info = current {
            if let addressString = getAddressString(from: info) {
                if !addresses.contains(addressString) {
                    addresses.append(addressString)
                }
            }
            current = info.pointee.ai_next
        }

        guard !addresses.isEmpty else {
            throw NetworkError.dnsResolutionFailed("No addresses found for \(hostname)")
        }

        return addresses
    }

    /// Resolve hostname and return the first address with its family
    /// - Parameters:
    ///   - hostname: The hostname to resolve
    ///   - preferIPv4: If true, prefer IPv4 addresses over IPv6
    /// - Returns: Tuple of (address string, address family)
    /// - Throws: NetworkError.dnsResolutionFailed if resolution fails
    public static func resolveFirst(hostname: String, preferIPv4: Bool = true) throws -> (address: String, family: Int32) {
        var hints = addrinfo()
        hints.ai_family = preferIPv4 ? AF_INET : AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?

        let status = getaddrinfo(hostname, nil, &hints, &result)
        guard status == 0 else {
            let errorMessage = String(cString: gai_strerror(status))
            throw NetworkError.dnsResolutionFailed("Failed to resolve \(hostname): \(errorMessage)")
        }

        defer { freeaddrinfo(result) }

        // If preferring IPv4, try to find one first
        if preferIPv4 {
            var current = result
            while let info = current {
                if info.pointee.ai_family == AF_INET {
                    if let addressString = getAddressString(from: info) {
                        return (addressString, AF_INET)
                    }
                }
                current = info.pointee.ai_next
            }
        }

        // Fall back to first available
        if let info = result {
            if let addressString = getAddressString(from: info) {
                return (addressString, info.pointee.ai_family)
            }
        }

        throw NetworkError.dnsResolutionFailed("No addresses found for \(hostname)")
    }

    /// Get full address info suitable for socket connection
    /// - Parameters:
    ///   - hostname: The hostname to resolve
    ///   - port: The port number
    /// - Returns: AddressInfo struct with all connection details
    /// - Throws: NetworkError.dnsResolutionFailed if resolution fails
    public static func getAddressInfo(hostname: String, port: Int) throws -> AddressInfo {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?

        let portString = String(port)
        let status = getaddrinfo(hostname, portString, &hints, &result)
        guard status == 0 else {
            let errorMessage = String(cString: gai_strerror(status))
            throw NetworkError.dnsResolutionFailed("Failed to resolve \(hostname): \(errorMessage)")
        }

        defer { freeaddrinfo(result) }

        guard let info = result else {
            throw NetworkError.dnsResolutionFailed("No addresses found for \(hostname)")
        }

        let addressData = Data(bytes: info.pointee.ai_addr, count: Int(info.pointee.ai_addrlen))

        return AddressInfo(
            family: info.pointee.ai_family,
            socketType: info.pointee.ai_socktype,
            socketProtocol: info.pointee.ai_protocol,
            addressData: addressData,
            addressLength: info.pointee.ai_addrlen
        )
    }

    // MARK: - Private Helpers

    private static func getAddressString(from info: UnsafeMutablePointer<addrinfo>) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        let result = getnameinfo(
            info.pointee.ai_addr,
            info.pointee.ai_addrlen,
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        guard result == 0 else { return nil }
        return String(cString: hostname)
    }
}

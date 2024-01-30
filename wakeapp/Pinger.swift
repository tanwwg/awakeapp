//
//  Pinger.swift
//  wakeapp
//
//  Created by Tan Thor Jen on 30/1/24.
//

import Foundation
import Darwin

public class SocketInfo {
    public weak var pinger: Pinger?
    public let identifier: UInt16
    
    public init(pinger: Pinger, identifier: UInt16) {
        self.pinger = pinger
        self.identifier = identifier
    }
}

/// Format of IPv4 header
public struct IPHeader {
    public var versionAndHeaderLength: UInt8
    public var differentiatedServices: UInt8
    public var totalLength: UInt16
    public var identification: UInt16
    public var flagsAndFragmentOffset: UInt16
    public var timeToLive: UInt8
    public var `protocol`: UInt8
    public var headerChecksum: UInt16
    public var sourceAddress: (UInt8, UInt8, UInt8, UInt8)
    public var destinationAddress: (UInt8, UInt8, UInt8, UInt8)
}

private struct ICMPHeader {
    /// Type of message
    var type: UInt8
    /// Type sub code
    var code: UInt8
    /// One's complement checksum of struct
    var checksum: UInt16
    /// Identifier
    var identifier: UInt16
    /// Sequence number
    var sequenceNumber: UInt16
    /// UUID payload
    var payload: uuid_t
}

/// ICMP echo types
public enum ICMPType: UInt8 {
    case EchoReply = 0
    case EchoRequest = 8
}

/// Creates the appropriate sockaddr_in and returns as data
func ipv4ToData(ipv4: String) -> Data {
    var socketAddress = sockaddr_in()
    socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    socketAddress.sin_family = UInt8(AF_INET)
    socketAddress.sin_port = 0
    socketAddress.sin_addr.s_addr = inet_addr(ipv4.cString(using: .utf8))
    let data = Data(bytes: &socketAddress, count: MemoryLayout<sockaddr_in>.size)
    return data
}

@Observable public class PingHost: Identifiable {
    public var id: String { name }
    
    /// A random UUID fingerprint sent as the payload.
    let fingerprint = UUID()
    var name: String
    var sequenceIndex = 0
    var destination: Data
    var lastPing: Date?
    var isAlive = false

    init(name: String, ipv4: String) {
        self.name = name
        self.destination = ipv4ToData(ipv4: ipv4)
    }
    
    func updateAlive(date: Date) {
        guard let last = lastPing else { return }
        isAlive = date.timeIntervalSince(last) < 4.0
    }
}


@Observable public class Pinger {
    
    private let identifier = UInt16.random(in: 0..<UInt16.max)
    private var socket: CFSocket?
    private var socketSource: CFRunLoopSource?
    private var unmanagedSocketInfo: Unmanaged<SocketInfo>?
    
    var killswitch = false
    var hosts: [PingHost] = []
    
    func startPinging() throws {
        try createSocket()
        self.tryPingAndRequeue()
    }
    
    func tryPingAndRequeue() {
        let now = Date.now
        for h in hosts {
            h.updateAlive(date: now)            
            try? self.sendPing(host: h)
        }
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            self.tryPingAndRequeue()
        }
    }
    
    private func createSocket() throws {
        // Create a socket context...
        let info = SocketInfo(pinger: self, identifier: identifier)
        unmanagedSocketInfo = Unmanaged.passRetained(info)
        var context = CFSocketContext(version: 0, info: unmanagedSocketInfo!.toOpaque(), retain: nil, release: nil, copyDescription: nil)

        // ...and a socket...
        socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_DGRAM, IPPROTO_ICMP, CFSocketCallBackType.dataCallBack.rawValue, { socket, type, address, data, info in
            // Socket callback closure
            guard let socket = socket, let info = info, let data = data else { return }
            let socketInfo = Unmanaged<SocketInfo>.fromOpaque(info).takeUnretainedValue()
            let ping = socketInfo.pinger
            if (type as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
                let cfdata = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue()
                ping?.socket(socket: socket, didReadData: cfdata as Data)
            }
        }, &context)
        
        // Disable SIGPIPE, see issue #15 on GitHub.
        let handle = CFSocketGetNative(socket)
        var value: Int32 = 1
        let err = setsockopt(handle, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout.size(ofValue: value)))
        guard err == 0 else {
            throw PingError.socketOptionsSetError(err: err)
        }
        
        // Set TTL
//        if var ttl = configuration.timeToLive {
//            let err = setsockopt(handle, IPPROTO_IP, IP_TTL, &ttl, socklen_t(MemoryLayout.size(ofValue: ttl)))
//            guard err == 0 else {
//                throw PingError.socketOptionsSetError(err: err)
//            }
//        }
        
        // ...and add it to the main run loop.
        socketSource = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), socketSource, .commonModes)
    }
    
    func sendPing(host: PingHost) throws {
        let icmpPackage = try self.createICMPPackage(identifier: UInt16(self.identifier), sequenceNumber: UInt16(host.sequenceIndex), fingerprint: host.fingerprint)
        host.sequenceIndex += 1
        if host.sequenceIndex >= UInt16.max { host.sequenceIndex = 0 }
        
        guard let socket = self.socket else { return }
        let socketError = CFSocketSendData(socket, host.destination as CFData, icmpPackage as CFData, 0)
        guard socketError == CFSocketError.success else {
            throw PingError.socketError(error: socketError)
        }
    }
    
    private func createICMPPackage(identifier: UInt16, sequenceNumber: UInt16, fingerprint: UUID) throws -> Data {
        var header = ICMPHeader(type: ICMPType.EchoRequest.rawValue,
                                code: 0,
                                checksum: 0,
                                identifier: CFSwapInt16HostToBig(identifier),
                                sequenceNumber: CFSwapInt16HostToBig(sequenceNumber),
                                payload: fingerprint.uuid)
                
        let payloadSize = MemoryLayout<uuid_t>.size
        let delta = payloadSize - MemoryLayout<uuid_t>.size
        var additional = [UInt8]()
        if delta > 0 {
            additional = (0..<delta).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        }

        let checksum = try computeChecksum(header: header)
        header.checksum = checksum
        
        let package = Data(bytes: &header, count: MemoryLayout<ICMPHeader>.size) + Data(additional)
        return package
    }
    
    private func socket(socket: CFSocket, didReadData data: Data?) {
        if killswitch { return }
        
//        print("received something?!")
        
        guard let data = data else { return }
        guard let host = try? validateResponse(from: data) else { return }
        host.lastPing = Date.now
//
//        var validationError: PingError? = nil
//        
//        do {
//            let validation = try validateResponse(from: data)
//            if !validation { return }
//        } catch let error as PingError {
//            validationError = error
//        } catch {
//            print("Unhandled error thrown: \(error)")
//        }
        
//        print("ping received \(host.name)")
//        var ipHeader: IPHeader? = nil
//        if validationError == nil {
//            ipHeader = data.withUnsafeBytes({ $0.load(as: IPHeader.self) })
//        }
//        informObserver(of: response)
        
//        incrementSequenceIndex()
    }
    
    private func computeChecksum(header: ICMPHeader) throws -> UInt16 {
        let typecode = Data([header.type, header.code]).withUnsafeBytes { $0.load(as: UInt16.self) }
        var sum = UInt64(typecode) + UInt64(header.identifier) + UInt64(header.sequenceNumber)
        let payload = convert(payload: header.payload)
        
        guard payload.count % 2 == 0 else { throw PingError.unexpectedPayloadLength }
        
        var i = 0
        while i < payload.count {
            guard payload.indices.contains(i + 1) else { throw PingError.unexpectedPayloadLength }
            // Convert two 8 byte ints to one 16 byte int
            sum += Data([payload[i], payload[i + 1]]).withUnsafeBytes { UInt64($0.load(as: UInt16.self)) }
            i += 2
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xffff) + (sum >> 16)
        }

        guard sum < UInt16.max else { throw PingError.checksumOutOfBounds }
        
        return ~UInt16(sum)
    }
        
    private func icmpHeaderOffset(of packet: Data) -> Int? {
        if packet.count >= MemoryLayout<IPHeader>.size + MemoryLayout<ICMPHeader>.size {
            let ipHeader = packet.withUnsafeBytes({ $0.load(as: IPHeader.self) })
            if ipHeader.versionAndHeaderLength & 0xF0 == 0x40 && ipHeader.protocol == IPPROTO_ICMP {
                let headerLength = Int(ipHeader.versionAndHeaderLength) & 0x0F * MemoryLayout<UInt32>.size
                if packet.count >= headerLength + MemoryLayout<ICMPHeader>.size {
                    return headerLength
                }
            }
        }
        return nil
    }
    
    private func convert(payload: uuid_t) -> [UInt8] {
        let p = payload
        return [p.0, p.1, p.2, p.3, p.4, p.5, p.6, p.7, p.8, p.9, p.10, p.11, p.12, p.13, p.14, p.15].map { UInt8($0) }
    }
    
    private func validateResponse(from data: Data) throws -> PingHost? {
        guard data.count >= MemoryLayout<ICMPHeader>.size + MemoryLayout<IPHeader>.size else {
            throw PingError.invalidLength(received: data.count)
        }
                
        guard let headerOffset = icmpHeaderOffset(of: data) else { throw PingError.invalidHeaderOffset }
//        let payloadSize = data.count - headerOffset - MemoryLayout<ICMPHeader>.size
        let icmpHeader = data.withUnsafeBytes({ $0.load(fromByteOffset: headerOffset, as: ICMPHeader.self) })
//        let payload = data.subdata(in: (data.count - payloadSize)..<data.count)
        
        let checksum = try computeChecksum(header: icmpHeader)
        
        guard icmpHeader.checksum == checksum else {
            throw PingError.checksumMismatch(received: icmpHeader.checksum, calculated: checksum)
        }
        guard icmpHeader.type == ICMPType.EchoReply.rawValue else {
            throw PingError.invalidType(received: icmpHeader.type)
        }
        guard icmpHeader.code == 0 else {
            throw PingError.invalidCode(received: icmpHeader.code)
        }
        guard CFSwapInt16BigToHost(icmpHeader.identifier) == identifier else {
            throw PingError.identifierMismatch(received: icmpHeader.identifier, expected: identifier)
        }
        
        let uuid = UUID(uuid: icmpHeader.payload)
        return hosts.first(where: { h in h.fingerprint == uuid })
    }
}

public enum PingError: Error, Equatable {
    
    case socketError(error: CFSocketError)
    
    // Response errors
    
    /// The response took longer to arrive than `configuration.timeoutInterval`.
    case responseTimeout
    
    // Response validation errors
    
    /// The response length was too short.
    case invalidLength(received: Int)
    /// The received checksum doesn't match the calculated one.
    case checksumMismatch(received: UInt16, calculated: UInt16)
    /// Response `type` was invalid.
    case invalidType(received: ICMPType.RawValue)
    /// Response `code` was invalid.
    case invalidCode(received: UInt8)
    /// Response `identifier` doesn't match what was sent.
    case identifierMismatch(received: UInt16, expected: UInt16)
    /// Response `sequenceNumber` doesn't match.
    case invalidSequenceIndex(received: UInt16, expected: UInt16)
    
    // Host resolve errors
    /// Unknown error occured within host lookup.
    case unknownHostError
    /// Address lookup failed.
    case addressLookupError
    /// Host was not found.
    case hostNotFound
    /// Address data could not be converted to `sockaddr`.
    case addressMemoryError

    // Request errors
    /// An error occured while sending the request.
    case requestError
    /// The request send timed out. Note that this is not "the" timeout,
    /// that would be `responseTimeout`. This timeout means that
    /// the ping request wasn't even sent within the timeout interval.
    case requestTimeout
    
    // Internal errors
    /// Checksum is out-of-bounds for `UInt16` in `computeCheckSum`. This shouldn't occur, but if it does, this error ensures that the app won't crash.
    case checksumOutOfBounds
    /// Unexpected payload length.
    case unexpectedPayloadLength
    /// Unspecified package creation error.
    case packageCreationFailed
    /// For some reason, the socket is `nil`. This shouldn't ever happen, but just in case...
    case socketNil
    /// The ICMP header offset couldn't be calculated.
    case invalidHeaderOffset
    /// Failed to change socket options, in particular SIGPIPE.
    case socketOptionsSetError(err: Int32)
}

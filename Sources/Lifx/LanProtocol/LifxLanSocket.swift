import Combine
import Foundation
import Network

fileprivate func stringFromHost(_ host: NWEndpoint.Host) -> String? {
    switch host {
    case .name(let hostStr, _):
        return hostStr
    case .ipv4(let ip):
        return ip.rawValue.map({ "\($0)" }).joined(separator: ".")
    case .ipv6(let ip):
        return ip.rawValue.map({ "\($0)" }).joined(separator: ":")
    default:
        return nil
    }
}

fileprivate func peerForConnection(_ connection: NWConnection) -> (host: String, port: UInt16)? {
    guard case .hostPort(let host, let port) = connection.endpoint, let hostName = stringFromHost(host) else {
        print("Connection does not use a hostname endpoint")
        return nil
    }
    return (hostName, port.rawValue)
}

fileprivate let DefaultPort = NWEndpoint.Port(rawValue: LifxLanClient.defaultUDPPort)!

fileprivate struct PacketId: Hashable {
    var source: UInt32
    var sequence: UInt8
}

fileprivate struct ActionId: Hashable {
    var target: MacAddr
    var type: MessageType
}

enum LifxLanSocketError: LocalizedError {
    case responseTimeout
    case portInUse
    
    var errorDescription: String? {
        switch self {
        case .responseTimeout:
            return "The device did not respond."
        case .portInUse:
            return "Failed to bind UDP socket."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .portInUse:
            return "Make sure no other LIFX applications are running on this device."
        default:
            return nil
        }
    }
}

class LifxLanSocket {
    
    private let messageHandler = PassthroughSubject<InboundPacket, Error>()
    private let responseTimeout: TimeInterval
    private let retries: UInt
    private let queue: DispatchQueue
    private let networkParams: NWParameters
    private let broadcaster: NWConnection
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private var completionQueue: [PacketId: CompletionHandler] = [:]
    private var retryQueue: [ActionId: PacketId] = [:]
    private var listening = false
    
    var messagePublisher: AnyPublisher<InboundPacket, Error> {
        return messageHandler.eraseToAnyPublisher()
    }
    
    init(responseTimeout: TimeInterval = 1.0, retries: UInt = 2) throws {
        self.responseTimeout = responseTimeout
        self.retries = retries
        
        queue = DispatchQueue(label: "LIFX LAN Socket")
        
        networkParams = NWParameters.udp
        networkParams.allowLocalEndpointReuse = true
        
        // Create a broadcaster for sending discovery messages to the local LAN
        let broadcasterParams = NWParameters.udp
        broadcasterParams.allowLocalEndpointReuse = true
        broadcasterParams.requiredLocalEndpoint = .hostPort(host: .ipv4(.any), port: DefaultPort)
        broadcaster = NWConnection(
            host: .ipv4(.broadcast),
            port: DefaultPort,
            using: broadcasterParams
        )
        broadcaster.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("Broadcaster error: \(error)")
            case .cancelled:
                print("Broadcaster has died")
            default:
                break
            }
        }
        
        // Create a listener for receiving unsolicited messages from devices
        listener = try NWListener(using: networkParams, on: DefaultPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.addConnection(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                print("Listener error: \(error)")
                if error == .posix(.EADDRINUSE) {
                    self?.messageHandler.send(completion: .failure(LifxLanSocketError.portInUse))
                } else {
                    self?.messageHandler.send(completion: .failure(error))
                }
            case .cancelled:
                self?.messageHandler.send(completion: .finished)
            default:
                break
            }
        }
    }
    
    func startListening() {
        if !listening {
            listener.start(queue: queue)
            broadcaster.start(queue: queue)
            listening = true
        }
    }
    
    func broadcast(_ message: ProtocolMessage, completion: CompletionHandler?=nil) {
        startListening()
        var message = message
        message.tagged = (message.target == .any)
        broadcaster.send(content: message.binaryData, completion: .contentProcessed({ err in
            if let err = err {
                print("Socket broadcast failure: \(err)")
                completion?(err)
            } else {
                completion?(nil)
            }
        }))
    }
    
    func send(_ message: ProtocolMessage, to device: LifxDevice, completion: CompletionHandler?=nil) {
        var packet = OutboundPacket(message: message, toHost: device.ipAddress, toPort: device.port)
        packet.message.target = device.macAddress
        send(packet, completion: completion)
    }
    
    func send(_ packet: OutboundPacket, completion: CompletionHandler?=nil) {
        startListening()
        var message = packet.message
        message.tagged = (message.target == .any)
        queue.async {
            let connection = self.connection(for: packet.toHost, port: packet.toPort)
            self.sendWithRetry(message, on: connection, completion: completion)
        }
    }
    
    func send(messages: [ProtocolMessage], to device: LifxDevice) {
        startListening()
        let connection = self.connection(for: device.ipAddress, port: device.port)
        queue.async {
            connection.batch {
                for var message in messages {
                    message.target = device.macAddress
                    self.sendWithRetry(message, on: connection, completion: nil)
                }
            }
        }
    }
    
    
    //MARK: Private
    
    private func connection(for hostName: String, port: UInt16) -> NWConnection {
        let match = connections.first {
            if let peer = peerForConnection($0), peer.host == hostName, peer.port == port {
                return true
            }
            return false
        }
        if let match = match {
            return match
        }
        print("Constructing new connection to \(hostName):\(port)")
        let connection = NWConnection(
            host: .name(hostName, nil),
            port: NWEndpoint.Port(rawValue: port)!,
            using: networkParams
        )
        addConnection(connection)
        return connection
    }
    
    private func addConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.parameters.allowLocalEndpointReuse = true
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                print("Socket error: \(error)")
            case .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive(from: connection)
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll(where: {$0 === connection})
    }
    
    private func sendWithRetry(_ message: ProtocolMessage, on connection: NWConnection, completion: CompletionHandler?, attempt: Int = 1) {
        let packetId = PacketId(source: message.source, sequence: message.sequence)
        let actionId = ActionId(target: message.target, type: message.type)
        retryQueue[actionId] = packetId
        
        send(message, on: connection) { err in
            if let err = err {
                // Retry unless the max attempts has been reached, or the packet has been superseded by another of the same type
                if self.retryQueue[actionId] != packetId {
                    completion?(err)
                } else if attempt > self.retries {
                    self.retryQueue.removeValue(forKey: actionId)
                    completion?(err)
                } else {
                    self.sendWithRetry(message, on: connection, completion: completion, attempt: attempt+1)
                }
            } else {
                // Success
                if self.retryQueue[actionId] == packetId {
                    self.retryQueue.removeValue(forKey: actionId)
                }
                completion?(nil)
            }
        }
    }
    
    private func send(_ message: ProtocolMessage, on connection: NWConnection, completion: CompletionHandler?) {
        let packetId = PacketId(source: message.source, sequence: message.sequence)
        let ackExpected = (message.ackRequired && message.source != 0)
        if ackExpected, let completion = completion {
            self.completionQueue[packetId] = completion
        }
        connection.send(content: message.binaryData, completion: .contentProcessed({ err in
            if let err = err {
                print("Socket send failure: \(err)")
                self.completionQueue.removeValue(forKey: packetId)
                completion?(err)
            } else if !ackExpected {
                completion?(nil)
            } else {
                self.queue.asyncAfter(deadline: .now() + self.responseTimeout) {
                    if let completion = self.completionQueue.removeValue(forKey: packetId) {
                        completion(LifxLanSocketError.responseTimeout)
                    }
                }
            }
        }))
    }
    
    private func receive(from connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, _, _, error) in
            if let error = error {
                print("Socket receive error: \(error)")
            } else if let data = data {
                if let message = try? ProtocolMessage(binaryData: data), let peer = peerForConnection(connection) {
                    if message.type == .acknowledgement, message.source != 0 {
                        let packetId = PacketId(source: message.source, sequence: message.sequence)
                        if let completion = self?.completionQueue.removeValue(forKey: packetId) {
                            completion(nil)
                        }
                    } else {
                        self?.messageHandler.send(InboundPacket(message: message, fromHost: peer.host, fromPort: peer.port))
                    }
                } else {
                    print("Received an invalid packet")
                }
                self?.receive(from: connection)
            }
        }
    }
}

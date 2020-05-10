import Foundation

private let HEADER_LENGTH = 36
private let PROTOCOL_NUM = UInt16(1024)

public struct ProtocolMessage: BinaryDecodable, BinaryEncodable {
    
    public var tagged: Bool
    public var source: UInt32
    public var target: MacAddr
    public var resRequired: Bool
    public var ackRequired: Bool
    public var sequence: UInt8
    public var type: MessageType
    public var payload: Data
    
    public init(
        type: MessageType,
        tagged: Bool = false,
        source: UInt32 = 0,
        target: MacAddr = .any,
        ackRequired: Bool = false,
        resRequired: Bool = false,
        sequence: UInt8 = 0,
        payload: Data = Data())
    {
        self.tagged = tagged
        self.source = source
        self.target = target
        self.resRequired = resRequired
        self.ackRequired = ackRequired
        self.sequence = sequence
        self.type = type
        self.payload = payload
    }
    
    init(binaryData: Data) throws {
        let header = try ProtocolHeader(binaryData: binaryData.prefix(HEADER_LENGTH))
        guard header.size == binaryData.count else {
            throw BinaryPacketError.invalidPacket(description: "Size header doesn't match packet length")
        }
        guard header.protocolNumber == PROTOCOL_NUM else {
            throw BinaryPacketError.invalidPacket(description: "Unsupported protocol number")
        }
        guard let type = MessageType(rawValue: header.type) else {
            throw BinaryPacketError.invalidPacket(description: "Unsupported packet type (\(header.type))")
        }
        self.type = type
        tagged = header.tagged
        source = header.source
        target = header.target
        resRequired = header.resRequired
        ackRequired = header.ackRequired
        sequence = header.sequence
        payload = binaryData.suffix(from: HEADER_LENGTH)
    }
    
    var binaryData: Data {
        var header = ProtocolHeader()
        header.size = UInt16(HEADER_LENGTH + self.payload.count)
        header.protocolNumber = PROTOCOL_NUM
        header.addressable = true
        header.tagged = tagged
        header.origin = 0
        header.source = source
        header.target = target
        header.resRequired = resRequired
        header.ackRequired = ackRequired
        header.sequence = sequence
        header.type = type.rawValue
        
        var data = header.binaryData
        data.append(contentsOf: payload)
        return data
    }
}

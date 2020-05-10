import Foundation

struct StateGroupPayload: BinaryDecodable {
    
    public var group: [UInt8]
    public var label: String
    public var updatedAt: Date
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        group = try packet.read(length: 16)
        label = try packet.decodeCString(fieldLength: 32)
        updatedAt = dateFromTimestamp(try packet.decode())
    }
    
}

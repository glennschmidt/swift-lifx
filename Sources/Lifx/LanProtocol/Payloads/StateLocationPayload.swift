import Foundation

struct StateLocationPayload: BinaryDecodable {
    
    public var location: [UInt8]
    public var label: String
    public var updatedAt: Date
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        location = try packet.read(length: 16)
        label = try packet.decodeCString(fieldLength: 32)
        updatedAt = dateFromTimestamp(try packet.decode())
    }
    
}

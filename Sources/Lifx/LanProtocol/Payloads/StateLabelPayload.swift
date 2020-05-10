import Foundation

struct StateLabelPayload: BinaryDecodable {
    
    public var label: String
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        label = try packet.decodeCString(fieldLength: 32)
    }
    
}

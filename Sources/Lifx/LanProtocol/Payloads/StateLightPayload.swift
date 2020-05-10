import Foundation

struct StateLightPayload: BinaryDecodable {
    
    public var color: HSBK
    public var powerOn: Bool
    public var label: String
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        color = try HSBK(binaryData: Data(try packet.read(length: HSBK.DataLength)))
        try packet.skip(length: 2)
        powerOn = (try packet.decode(type: UInt16.self)) > 0
        label = try packet.decodeCString(fieldLength: 32)
        try packet.skip(length: 8)
    }
    
}

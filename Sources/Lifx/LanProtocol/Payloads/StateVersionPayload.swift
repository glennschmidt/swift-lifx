import Foundation

struct StateVersionPayload: BinaryDecodable {
    
    public var vendor: UInt32
    public var product: UInt32
    public var version: UInt32
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        vendor = try packet.decode()
        product = try packet.decode()
        version = try packet.decode()
    }
    
}

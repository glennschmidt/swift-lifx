import Foundation

struct StateWiFiInfoPayload: BinaryDecodable {
    
    public var signal: Float32
    public var tx: UInt32
    public var rx: UInt32
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        signal = try packet.decode()
        tx = try packet.decode()
        rx = try packet.decode()
        try packet.skip(length: 2)
    }
    
}

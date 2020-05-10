import Foundation

struct StatePowerPayload: BinaryDecodable {
    
    public var powerOn: Bool
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        powerOn = (try packet.decode(type: UInt16.self)) > 0
    }
    
}

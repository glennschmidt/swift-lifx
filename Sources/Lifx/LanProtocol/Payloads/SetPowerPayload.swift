import Foundation

struct SetPowerPayload: BinaryEncodable {
    
    public var powerOn: Bool
    public var duration: TimeInterval
    
    
    var binaryData: Data {
        let packet = BinaryPacket()
        packet.encode(UInt16(powerOn ? 65535 : 0))
        packet.encode(durationFromTimeInterval(duration))
        return packet.data
    }
}

import Foundation

struct SetColorPayload: BinaryEncodable {
    
    public var color: HSBK
    public var duration: TimeInterval
    
    
    var binaryData: Data {
        let packet = BinaryPacket()
        packet.write(0)
        packet.data.append(color.binaryData)
        packet.encode(durationFromTimeInterval(duration))
        return packet.data
    }
}

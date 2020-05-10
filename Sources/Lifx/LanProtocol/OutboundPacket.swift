import Foundation

struct OutboundPacket {
    var message: ProtocolMessage
    var toHost: String
    var toPort: UInt16
}

import Foundation

struct InboundPacket {
    var message: ProtocolMessage
    var fromHost: String
    var fromPort: UInt16
}

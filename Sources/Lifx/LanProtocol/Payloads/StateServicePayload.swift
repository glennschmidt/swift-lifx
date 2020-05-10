import Foundation

enum ServiceType {
    case udp
    case other(identifier: UInt8)
    
    var identifier: UInt8 {
        switch self {
        case .udp:
            return 1
        case .other(let identifier):
            return identifier
        }
    }
    
    init(identifier: UInt8) {
        if identifier == 1 {
            self = .udp
        } else {
            self = .other(identifier: identifier)
        }
    }
}

struct StateServicePayload: BinaryDecodable {
    
    public var service: ServiceType
    public var port: UInt32
    
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        service = ServiceType(identifier: try packet.decode())
        port = try packet.decode()
    }
    
}

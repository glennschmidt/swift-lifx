import Foundation

struct ProtocolHeader: BinaryDecodable, BinaryEncodable {
    
    var size: UInt16
    var protocolNumber: UInt16
    var addressable: Bool
    var tagged: Bool
    var origin: UInt8
    var source: UInt32
    var target: MacAddr
    var resRequired: Bool
    var ackRequired: Bool
    var sequence: UInt8
    var type: UInt16
    
    init() {
        size = 0
        protocolNumber = 0
        addressable = false
        tagged = false
        origin = 0
        source = 0
        target = .any
        resRequired = false
        ackRequired = false
        sequence = 0
        type = 0
    }
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        size = try packet.decode()
        
        var bitfield = try packet.read(length: 2)
        protocolNumber = Binary.decode([bitfield[0], bitfield[1] & 0b00001111], byteOrder: packet.byteOrder)
        addressable = (bitfield[1] & 0b00010000 != 0)
        tagged      = (bitfield[1] & 0b00100000 != 0)
        origin      = (bitfield[1] & 0b11000000) >> 6
        
        source = try packet.decode()
        
        let targetBytes = try packet.read(length: 8)
        target = try MacAddr(data: Data(targetBytes[..<6]))
        
        try packet.skip(length: 6)
        bitfield = try packet.read(length: 1)
        resRequired = (bitfield[0] & 0b00000001 != 0)
        ackRequired = (bitfield[0] & 0b00000010 != 0)
        
        sequence = try packet.decode()
        try packet.skip(length: 8)
        type = try packet.decode()
        try packet.skip(length: 2)
    }
    
    var binaryData: Data {
        let packet = BinaryPacket()
        packet.encode(size)
        
        var bitfield = Binary.encode(protocolNumber, byteOrder: packet.byteOrder)
        bitfield[1] &= 0b00001111
        bitfield[1] |= Byte(addressable ? 1 : 0) << 4
        bitfield[1] |= Byte(tagged ? 1 : 0) << 5
        bitfield[1] |= (origin & 0b00000011) << 6
        packet.write(bitfield)
        
        packet.encode(source)
        packet.write(target.bytes)
        
        packet.write(repeating: 0, count: 8)
        bitfield = [0]
        bitfield[0] |= Byte(resRequired ? 1 : 0)
        bitfield[0] |= Byte(ackRequired ? 1 : 0) << 1
        packet.write(bitfield)
        
        packet.encode(sequence)
        packet.write(repeating: 0, count: 8)
        packet.encode(type)
        packet.write(repeating: 0, count: 2)
        
        return packet.data
    }
    
}

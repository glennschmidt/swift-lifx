import XCTest
@testable import Lifx

final class LifxKitTests: XCTestCase {
    func testByteOrder() {
        let number: UInt16 = 0x0102
        
        var encoded = Binary.encode(number, byteOrder: .littleEndian)
        XCTAssertEqual(encoded.count, 2)
        XCTAssertEqual(encoded[0], 2)
        XCTAssertEqual(encoded[1], 1)
        XCTAssertEqual(Binary.decode(encoded, toType: UInt16.self, byteOrder: .littleEndian), number)
        
        encoded = Binary.encode(number, byteOrder: .bigEndian)
        XCTAssertEqual(encoded.count, 2)
        XCTAssertEqual(encoded[0], 1)
        XCTAssertEqual(encoded[1], 2)
        XCTAssertEqual(Binary.decode(encoded, toType: UInt16.self, byteOrder: .bigEndian), number)
    }
    
    func testBinaryPacket() {
        let packet = BinaryPacket()
        packet.write(0x01)
        packet.write([0x02, 0x03])
        
        let number: UInt16 = 0x0405
        packet.encode(number)
        packet.write(repeating: 0x06, count: 3)
        
        XCTAssertEqual(packet.data.count, 8)
        XCTAssertEqual(packet.data[0], 0x01)
        XCTAssertEqual(packet.data[1], 0x02)
        XCTAssertEqual(packet.data[2], 0x03)
        XCTAssertEqual(packet.data[3], 0x05)
        XCTAssertEqual(packet.data[4], 0x04)
        XCTAssertEqual(packet.data[5], 0x06)
        XCTAssertEqual(packet.data[6], 0x06)
        XCTAssertEqual(packet.data[7], 0x06)
        
        let bytes = try! packet.read(length: 2)
        XCTAssertEqual(bytes.count, 2)
        XCTAssertEqual(bytes[0], 0x01)
        XCTAssertEqual(bytes[1], 0x02)
        XCTAssertEqual(try packet.decode(type: UInt8.self), 0x03)
        XCTAssertEqual(try packet.decode(type: UInt16.self), 0x0405)
        XCTAssertNoThrow(try packet.skip(length: 3))
        XCTAssertThrowsError(try packet.read(length: 1))
    }
    
    func testProtocolHeader() {
        var header = ProtocolHeader()
        header.size = 36
        header.protocolNumber = 1024
        header.addressable = true
        header.tagged = true
        header.type = MessageType.setColor.rawValue
        let data = header.binaryData
        
        XCTAssertEqual(data.count, 36)
        XCTAssertEqual(data[0], 36)
        XCTAssertEqual(data[1], 0)
        XCTAssertEqual(data[2], 0)
        XCTAssertEqual(data[3], 0x34)
        XCTAssertEqual(data[32], 0x66)
        
        header = try! ProtocolHeader(binaryData: data)
        XCTAssertEqual(header.size, 36)
        XCTAssertEqual(header.protocolNumber, 1024)
        XCTAssertEqual(header.addressable, true)
        XCTAssertEqual(header.tagged, true)
        XCTAssertEqual(header.origin, 0)
        XCTAssertEqual(header.source, 0)
        XCTAssertEqual(header.resRequired, false)
        XCTAssertEqual(header.ackRequired, false)
        XCTAssertEqual(header.sequence, 0)
        XCTAssertEqual(header.type, MessageType.setColor.rawValue)
    }
    
    func testProtocolMessage() {
        let sourceId = arc4random()
        let targetMac = MacAddr(bytes: (1, 2, 3, 4, 5, 6))
        let color = HSBK(hue: 21845, saturation: 65535, brightness: 65535, kelvin: 3500)
        var message = ProtocolMessage(
            type: .setColor,
            source: sourceId,
            target: targetMac,
            resRequired: true,
            payload: SetColorPayload(color: color, duration: 1024/1000).binaryData
        )
        let data = message.binaryData
        XCTAssertEqual(data.count, 49)
        XCTAssertEqual(data[0], 49)
        XCTAssertEqual(data[3], 0x14)
        XCTAssertEqual(data[32], 0x66)
        XCTAssertEqual(data[37], 0x55)
        XCTAssertEqual(data[38], 0x55)
        XCTAssertEqual(data[39], 0xFF)
        XCTAssertEqual(data[40], 0xFF)
        XCTAssertEqual(data[41], 0xFF)
        XCTAssertEqual(data[42], 0xFF)
        XCTAssertEqual(data[43], 0xAC)
        XCTAssertEqual(data[44], 0x0D)
        XCTAssertEqual(data[45], 0)
        XCTAssertEqual(data[46], 0x04)
        XCTAssertEqual(data[47], 0)
        XCTAssertEqual(data[48], 0)
        
        message = try! ProtocolMessage(binaryData: data)
        XCTAssertEqual(message.type, .setColor)
        XCTAssertEqual(message.source, sourceId)
        XCTAssertEqual(message.target.bytes[0], 1)
        XCTAssertEqual(message.target.bytes[1], 2)
    }

    static var allTests = [
        ("testByteOrder", testByteOrder),
        ("testBinaryPacket", testBinaryPacket),
        ("testProtocolHeader", testProtocolHeader),
        ("testProtocolMessage", testProtocolMessage),
    ]
}

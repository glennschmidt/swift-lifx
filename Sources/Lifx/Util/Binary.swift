import Foundation

typealias Byte = UInt8

enum ByteOrder {
    case bigEndian
    case littleEndian
    
    static let native: ByteOrder = (Int(CFByteOrderGetCurrent()) == Int(CFByteOrderLittleEndian.rawValue)) ? .littleEndian : .bigEndian
    static let network: ByteOrder = .bigEndian
}

class Binary {
    class func decode<T: Any>(_ valueByteArray: [Byte], byteOrder: ByteOrder = .native) -> T {
        return Binary.decode(valueByteArray, toType: T.self, byteOrder: byteOrder)
    }
    
    class func decode<T: Any>(_ valueByteArray: [Byte], toType type: T.Type, byteOrder: ByteOrder = .native) -> T {
        assert(!(T.self is AnyClass), "Unsupported type")
        let bytes = (byteOrder == ByteOrder.native) ? valueByteArray : valueByteArray.reversed()
        return bytes.withUnsafeBufferPointer {
            return $0.baseAddress!.withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
            }
        }
    }
    
    class func encode<T: Any>( _ value: T, byteOrder: ByteOrder = .native) -> [Byte] {
        assert(!(T.self is AnyClass), "Unsupported type")
        
        var value = value // inout works only for var not let types
        let valueByteArray = withUnsafePointer(to: &value) {
            Array(UnsafeBufferPointer(start: $0.withMemoryRebound(to: Byte.self, capacity: 1){$0}, count: MemoryLayout<T>.size))
        }
        return (byteOrder == ByteOrder.native) ? valueByteArray : valueByteArray.reversed()
    }
}

enum BinaryPacketError: Error {
    case endOfPacket
    case invalidPacket(description: String)
    case invalidStringEncoding
}

class BinaryPacket {
    var data: Data
    let byteOrder: ByteOrder
    var decodingOffset: Int
    
    init(data: Data = Data(), byteOrder: ByteOrder = .littleEndian) {
        self.data = data
        self.byteOrder = byteOrder
        self.decodingOffset = data.startIndex
    }
    
    func decode<T: Any>() throws -> T {
        return try decode(type: T.self)
    }
    
    func decode<T: Any>(type: T.Type) throws -> T {
        let length = MemoryLayout<T>.size
        return Binary.decode(try read(length: length), toType: T.self, byteOrder: byteOrder)
    }
    
    func decodeCString(fieldLength: Int, encoding: String.Encoding = .utf8) throws -> String {
        let bytes = try read(length: fieldLength)
        guard let strLength = bytes.firstIndex(of: 0) else {
            throw BinaryPacketError.invalidStringEncoding
        }
        guard let str = String(bytes: bytes[..<strLength], encoding: encoding) else {
            throw BinaryPacketError.invalidStringEncoding
        }
        return str
    }
    
    func read(length: Int) throws -> [Byte] {
        if decodingOffset+length > data.endIndex {
            throw BinaryPacketError.endOfPacket
        }
        let bytes = data.subdata(in: decodingOffset..<decodingOffset+length).map { $0 }
        decodingOffset += length
        return bytes
    }
    
    func skip(length: Int) throws {
        _ = try read(length: length)
    }
    
    func encode<T: Any>( _ value: T) {
        data.append(contentsOf: Binary.encode(value, byteOrder: byteOrder))
    }
    
    func write(_ bytes: [Byte]) {
        data.append(contentsOf: bytes)
    }
    
    func write(_ byte: Byte) {
        data.append(byte)
    }
    
    func write(repeating byte: Byte, count: Int) {
        data.append(contentsOf: Array(repeating: byte, count: count))
    }
}

protocol BinaryEncodable {
    var binaryData: Data { get }
}

protocol BinaryDecodable {
    init(binaryData: Data) throws
}

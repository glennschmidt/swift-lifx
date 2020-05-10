import Foundation

struct LengthError: LocalizedError {
    var errorDescription: String? = "A MAC address must be 6 bytes"
}

public struct MacAddr: Equatable, Hashable {
    let bytes: [UInt8]
    
    public init(_ bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        self.bytes = [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5]
    }
    
    public init(_ data: Data) throws {
        if data.count != 6 {
            throw LengthError()
        }
        bytes = data.map { $0 }
    }
    
    public init(_ string: String) throws {
        bytes = string.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        if bytes.count != 6 {
            throw LengthError()
        }
    }
    
    public var data: Data {
        return Data(bytes)
    }
    
    public var string: String {
        return bytes.map { String(format: "%02hhX", $0) }.joined(separator: ":")
    }
    
    public static let any = MacAddr((0, 0, 0, 0, 0, 0))
}

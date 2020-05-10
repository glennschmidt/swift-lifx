import Combine
import Foundation

public class LifxDevice: CustomDebugStringConvertible, Identifiable, ObservableObject {

    public let macAddress: MacAddr
    public var ipAddress: String
    public var port: UInt16
    
    @Published public var label: String?
    
    @Published public var color: HSBK?
    @Published public var powerOn: Bool?
    
    @Published public var vendor: UInt32?
    @Published public var product: UInt32?
    @Published public var version: UInt32?
    
    @Published public var location: String?
    @Published public var group: String?
    
    @Published public var wifiSignal: SignalStrength?
    
    @Published public var lastContact: Date?
    
    public init(macAddress: MacAddr, ipAddress: String, port: UInt16) {
        self.macAddress = macAddress
        self.ipAddress = ipAddress
        self.port = port
    }
    
    public var debugDescription: String {
        return self.macAddress.string
    }
    
}

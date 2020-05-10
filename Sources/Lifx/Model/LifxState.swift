import Combine
import Foundation

public class LifxState: ObservableObject {
    
    @Published public internal(set) var devices: [LifxDevice] = []
    
    public init(devices: [LifxDevice]=[]) {
        self.devices = devices
    }
    
}

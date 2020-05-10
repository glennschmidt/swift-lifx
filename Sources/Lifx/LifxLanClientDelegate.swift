import Foundation

public protocol LifxLanClientDelegate: AnyObject {
    /// Called when a new device is added to the device list.
    func lifxClient(_ client: LifxLanClient, didAdd device: LifxDevice)
    
    /// Called when a device is removed from the device list.
    func lifxClient(_ client: LifxLanClient, didRemove device: LifxDevice)
    
    /// Called when one or more device properties have been updated due to new state being received over the network.
    func lifxClient(_ client: LifxLanClient, didUpdate device: LifxDevice)
    
    /// Called whenever a packet is received from a device (proving that it's online).
    func lifxClient(_ client: LifxLanClient, didContact device: LifxDevice)
    
    /// Called if the client has encountered a serious networking problem, such as a port binding failure. The client will not be able to
    /// communicate with any devices and should be destroyed.
    func lifxClient(_ client: LifxLanClient, fatalError error: Error)
}

//MARK: - Default implementations

public extension LifxLanClientDelegate {
    func lifxClient(_ client: LifxLanClient, didAdd device: LifxDevice) {}
    func lifxClient(_ client: LifxLanClient, didRemove device: LifxDevice) {}
    func lifxClient(_ client: LifxLanClient, didUpdate device: LifxDevice) {}
    func lifxClient(_ client: LifxLanClient, didContact device: LifxDevice) {}
    func lifxClient(_ client: LifxLanClient, fatalError error: Error) {}
}

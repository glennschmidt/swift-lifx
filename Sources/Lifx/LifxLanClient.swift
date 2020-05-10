import Combine
import Foundation

/**
 Implements a client for the LIFX LAN protocol, for low-latency communication with LIFX devices on a local network.
 
 You should interact with the LifxLanClient from a single thread. All callbacks will be executed on the main thread.
 */
public class LifxLanClient {
    
    public static let defaultUDPPort = UInt16(56700)
    
    public weak var delegate: LifxLanClientDelegate?
    
    /// An observable object containing the current network state, including the device list.
    public let state = LifxState()

    private let socket: LifxLanSocket
    private var socketSubscription: AnyCancellable?
    private var deviceSubscriptions = Dictionary<MacAddr, Set<AnyCancellable>>()
    private let sourceId = arc4random()
    private var sequence: UInt8 = 0
    private var remoteUpdateInProgress = false
    private var refreshTimer: Timer?
    
    public init() throws {
        socket = try LifxLanSocket()
        socketSubscription = socket.messagePublisher.receive(on: DispatchQueue.main).sink(
            receiveCompletion: { [weak self] result in
                if case .failure(let error) = result, let _self = self  {
                    _self.stopRefreshing()
                    _self.delegate?.lifxClient(_self, fatalError: error)
                }
            },
            receiveValue: { [weak self] packet in
                self?.didReceivePacket(packet)
            }
        )
    }
    
    /// Broadcast a discovery message on the network. Any new devices that respond will be added to the device list.
    public func discover() {
        print("Discovery broadcast")
        socket.broadcast(message(type: .getService, ackRequired: false))
    }
    
    /// Send a discovery message to a specific IP address. If a device responds, it will be added to the device list.
    public func discover(host: String, port: UInt16 = LifxLanClient.defaultUDPPort) {
        print("Discovery unicast: \(host):\(port)")
        let packet = OutboundPacket(message: message(type: .getService), toHost: host, toPort: port)
        socket.send(packet)
    }
    
    /// Manually add a device to the device list.
    ///
    /// This could be used to restore network state that was previously persisted to disk, avoiding the overhead of discovery.
    ///
    /// - Parameter device: The device object to add. Once added, this object will benefit from live bidirectional state updates.
    public func add(device: LifxDevice) {
        DispatchQueue.main.async {
            self.didDiscover(device: device)
        }
    }
    
    /// Remove a device from the device list.
    ///
    /// - Note: If the device still exists on the local network, it may be re-discovered automatically.
    /// - Parameter device: The device to remove. If it isn't present in the device list, no action occurs.
    public func remove(device: LifxDevice) {
        DispatchQueue.main.async {
            if let index = self.state.devices.firstIndex(where: { $0.macAddress == device.macAddress }) {
                let device = self.state.devices[index]
                self.deviceSubscriptions[device.macAddress]?.forEach { $0.cancel() }
                self.deviceSubscriptions.removeValue(forKey: device.macAddress)
                self.state.devices.remove(at: index)
                self.delegate?.lifxClient(self, didRemoveDevice: device)
            }
        }
    }
    
    /// Contact devices to request the latest status.
    ///
    /// - Parameter device: The device to refresh. If `nil`, all devices in the device list will be refreshed.
    public func refresh(device: LifxDevice? = nil) {
        var devicesToRefresh = state.devices
        if let device = device {
            devicesToRefresh = [device]
        } else {
            print("Refreshing \(devicesToRefresh.count) devices")
        }
        for device in devicesToRefresh {
            socket.send(messages: [
                message(type: .getLabel, ackRequired: false),
                message(type: .getLight, ackRequired: false),
                message(type: .getVersion, ackRequired: false),
                message(type: .getLocation, ackRequired: false),
                message(type: .getGroup, ackRequired: false),
                message(type: .getWiFiInfo, ackRequired: false),
            ], to: device)
        }
    }
    
    /// Enable periodic polling for device status.
    ///
    /// This schedules a repeating task that will periodically:
    ///  - request the latest status from each device in the device list
    ///  - search for new devices on the network
    ///
    /// - Parameter interval: The time between refreshes, in seconds.
    public func startRefreshing(interval: TimeInterval = 3) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
            self.refresh()
            self.discover()
        })
        self.refresh()
        self.discover()
    }
    
    /// Disable periodic polling for device status, if it was enabled.
    public func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Switch a device on or off.
    ///
    /// - Parameter duration: Fade time in seconds
    /// - Parameter completion: Callback which will signal success or failure. Success means a positive acknowledgement was
    ///  received from the device.
    public func setPower(_ on: Bool, for device: LifxDevice, duration: TimeInterval = 0, completion: CompletionHandler?=nil) {
        socket.send(
            message(
                type: .setPower,
                payload: SetPowerPayload(powerOn: on, duration: duration)
            ),
            to: device,
            completion: completion
        )
    }
    
    /// Switch a device on or off.
    ///
    /// - Parameter duration: Fade time in seconds
    public func setPower(_ on: Bool, for device: LifxDevice, duration: TimeInterval = 0) -> AnyPublisher<Void, Error> {
        return completionPublisher {
            self.setPower(on, for: device, duration: duration, completion: $0)
        }
    }
    
    /// Set a light's color and brightness level.
    ///
    /// - Parameter duration: Fade time in seconds
    /// - Parameter completion: Callback which will signal success or failure. Success means a positive acknowledgement was
    ///  received from the device.
    public func setColor(_ color: HSBK, for device: LifxDevice, duration: TimeInterval = 0, completion: CompletionHandler?=nil) {
        socket.send(
            message(
                type: .setColor,
                payload: SetColorPayload(color: color, duration: duration)
            ),
            to: device,
            completion: completion
        )
    }
    
    /// Set a light's color and brightness level.
    ///
    /// - Parameter duration: Fade time in seconds
    public func setColor(_ color: HSBK, for device: LifxDevice, duration: TimeInterval = 0) -> AnyPublisher<Void, Error> {
        return completionPublisher {
            self.setColor(color, for: device, duration: duration, completion: $0)
        }
    }
    
    
    //MARK: Private
    
    private func device(withMac addr: MacAddr) -> LifxDevice? {
        return state.devices.first(where: { $0.macAddress == addr })
    }
    
    private func message(
        type: MessageType,
        ackRequired: Bool = true,
        resRequired: Bool = false,
        payload: BinaryEncodable? = nil
    ) -> ProtocolMessage {
        let message = ProtocolMessage(
            type: type,
            source: sourceId,
            ackRequired: ackRequired,
            resRequired: resRequired,
            sequence: sequence,
            payload: payload?.binaryData ?? Data()
        )
        sequence = (sequence == UInt8.max) ? 0 : sequence+1
        return message
    }
    
    private func didDiscover(device: LifxDevice) {
        if self.device(withMac: device.macAddress) != nil {
            //This device has already been discovered.
            return
        }
        state.devices.append(device)
        print("Discovered \(device)")
        
        //Respond if the user changes the device model's properties
        var subscriptions = Set<AnyCancellable>()
        device.$powerOn.sink { [weak self] isOn in
            if let isOn = isOn, self?.remoteUpdateInProgress == false {
                self?.setPower(isOn, for: device, completion: nil)
            }
        }.store(in: &subscriptions)
        device.$color.sink { [weak self] color in
            if let color = color, self?.remoteUpdateInProgress == false {
                self?.setColor(color, for: device, completion: nil)
            }
        }.store(in: &subscriptions)
        deviceSubscriptions[device.macAddress] = subscriptions
        
        delegate?.lifxClient(self, didAddDevice: device)
        refresh(device: device)
    }
    
    private func didReceivePacket(_ packet: InboundPacket) {
        let message = packet.message
        if message.type == .stateService {
            do {
                let payload = try StateServicePayload(binaryData: message.payload)
                switch payload.service {
                case .udp:
                    let port = UInt16(payload.port)
                    if let device = device(withMac: message.target) {
                        device.ipAddress = packet.fromHost
                        device.port = port
                    } else {
                        let device = LifxDevice(macAddress: message.target, ipAddress: packet.fromHost, port: port)
                        device.lastContact = Date()
                        didDiscover(device: device)
                    }
                case .other(let identifier):
                    print("Received advertisement for unsupported service \(identifier)")
                }
            } catch {
                print("Received invalid stateService payload: \(error)")
            }
        }
        
        guard let device = device(withMac: message.target) else {
            return
        }
        device.lastContact = Date()
        delegate?.lifxClient(self, didContactDevice: device)
        
        remoteUpdateInProgress = true
        switch message.type {
        case .stateLabel:
            if let str = String(bytes: message.payload, encoding: .utf8), device.label != str {
                print("Device \(device) label is now \(str)")
                device.label = str
                delegate?.lifxClient(self, didUpdateDevice: device)
            }
        case .stateLight:
            do {
                let payload = try StateLightPayload(binaryData: message.payload)
                if device.updateState(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid stateLight payload: \(error)")
            }
        case .statePower:
            do {
                let payload = try StatePowerPayload(binaryData: message.payload)
                if device.updatePower(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid statePower payload: \(error)")
            }
        case .stateVersion:
            do {
                let payload = try StateVersionPayload(binaryData: message.payload)
                if device.updateVersion(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid stateVersion payload: \(error)")
            }
        case .stateLocation:
            do {
                let payload = try StateLocationPayload(binaryData: message.payload)
                if device.updateLocation(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid stateLocation payload: \(error)")
            }
        case .stateGroup:
            do {
                let payload = try StateGroupPayload(binaryData: message.payload)
                if device.updateGroup(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid stateGroup payload: \(error)")
            }
        case .stateWiFiInfo:
            do {
                let payload = try StateWiFiInfoPayload(binaryData: message.payload)
                if device.updateWiFiInfo(payload) {
                    delegate?.lifxClient(self, didUpdateDevice: device)
                }
            } catch {
                print("Received invalid stateWiFiInfo payload: \(error)")
            }
        case .stateService, .acknowledgement, .echoResponse:
            break
        default:
            print("Received \(message.type) packet from \(packet.fromHost)")
        }
        remoteUpdateInProgress = false
    }
}

//MARK: - Delegate protocol

public protocol LifxLanClientDelegate: AnyObject {
    /// Called when a new device is added to the device list.
    func lifxClient(_ client: LifxLanClient, didAddDevice device: LifxDevice)
    
    /// Called when a device is removed from the device list.
    func lifxClient(_ client: LifxLanClient, didRemoveDevice device: LifxDevice)
    
    /// Called when one or more device properties have been updated due to new state being received over the network.
    func lifxClient(_ client: LifxLanClient, didUpdateDevice device: LifxDevice)
    
    /// Called whenever a packet is received from a device (proving that it's online).
    func lifxClient(_ client: LifxLanClient, didContactDevice device: LifxDevice)
    
    /// Called if the client has encountered a serious networking problem, such as a port binding failure. The client will not be able to
    /// communicate with any devices and should be destroyed.
    func lifxClient(_ client: LifxLanClient, fatalError error: Error)
}

//MARK: - State payload importing

extension LifxDevice {
    func updateState(_ payload: StateLightPayload) -> Bool {
        if color == nil || payload.color != color! || payload.powerOn != powerOn {
            color = payload.color
            powerOn = payload.powerOn
            return true
        }
        return false
    }
    
    func updatePower(_ payload: StatePowerPayload) -> Bool {
        if payload.powerOn != powerOn {
            powerOn = payload.powerOn
            return true
        }
        return false
    }
    
    func updateVersion(_ payload: StateVersionPayload) -> Bool {
        if payload.vendor != vendor || payload.product != product || payload.version != version {
            vendor = payload.vendor
            product = payload.product
            version = payload.version
            return true
        }
        return false
    }
    
    func updateLocation(_ payload: StateLocationPayload) -> Bool {
        if payload.label != location {
            location = payload.label
            return true
        }
        return false
    }
    
    func updateGroup(_ payload: StateGroupPayload) -> Bool {
        if payload.label != group {
            group = payload.label
            return true
        }
        return false
    }
    
    func updateWiFiInfo(_ payload: StateWiFiInfoPayload) -> Bool {
        let signal = SignalStrength.fromFloat(payload.signal)
        if signal != wifiSignal {
            wifiSignal = signal
            return true
        }
        return false
    }
}

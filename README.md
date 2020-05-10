# swift-lifx

A modern Swift library for controlling [LIFX smart lights](https://www.lifx.com).

Currently in alpha and supports parts of the LAN protocol, but not the LIFX Cloud yet.

## Installation

Use Swift Package Manager to add this repository to your Xcode project.

## Usage

### Basic usage

```swift
import Lifx

let client = try! LifxLanClient()

func example() {
    
    //To control a device with a known address
    let device = LifxDevice(macAddress: MacAddr("D0:73:D5:15:00:00"), ipAddress: "10.0.0.44")

    //Turn the light on
    client.setPower(true, for: device)

    //Set the color to red
    client.setColor(.red, for: device)
    
    //Set a custom color and brightness level
    client.setColor(HSBK(hue: 240/360, saturation: 1.0, brightness: 0.75), for: device)

    //Set the color to white with a specific color temperature
    client.setColor(HSBK(brightness: 1.0, colorTemperature: .coolDaylight), for: device)

}
```

### Discovery example

```swift
import Lifx

class Example: LifxLanClientDelegate {
    let client: LifxLanClient
    
    init() throws {
        client = try LifxLanClient()
        client.delegate = self
        client.startRefreshing()
    }
    
    func lifxClient(_ client: LifxLanClient, didAdd device: LifxDevice) {
        print("Discovered device \(device)")
    }
    
    func lifxClient(_ client: LifxLanClient, didUpdate device: LifxDevice) {
        if let label = device.label, let location = device.location {
            print("Device \(device) is named \(label) and located at \(location)")
        }
    }
}
```

### SwiftUI example

The library can provide its discovery state as an `ObservableObject`, and supports two-way dynamic state updates.
If you modify a property on a `LifxDevice` object, it will affect the real light, and vice versa.

```swift
import Lifx
import SwiftUI

struct ExampleView: View {
    @EnvironmentObject var lifx: LifxState
    
    var body: some View {
        List(lifx.devices) { device in
            PowerSwitch(device: device)
        }
    }
}

struct PowerSwitch: View {
    @ObservedObject var device: LifxDevice
    
    var isOn: Binding<Bool> {
        Binding(get: {
            return self.device.powerOn == true
        }, set: {
            self.device.powerOn = $0
        })
    }
    
    var body: some View {
        Toggle(isOn: isOn) {
            Text(device.label ?? device.ipAddress)
        }
            .toggleStyle(SwitchToggleStyle())
            .disabled(device.powerOn == nil)
    }
}
```

You would instantiate the above view hierarchy like this (eg. in your AppDelegate):

```swift
let client = try! LifxLanClient()

let view = ExampleView()
    .environmentObject(client.state)

client.startRefreshing()
```

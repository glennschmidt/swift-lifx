import Foundation

/**
  Represents color (hue and saturation), brightness and color temperature of light.
 */
public struct HSBK: Equatable, Hashable {

    ///Hue wheel position between 0 and 65535 (which maps to 0° - 360°).
    public var hue: UInt16
    ///Saturation level between 0 and 65535.
    public var saturation: UInt16
    ///Intensity level between 0 and 65535.
    public var brightness: UInt16
    ///Color temperature value in degrees Kelvin. Valid range is 2500 (warm) to 9000 (cool). Relevant when saturation is low.
    public var kelvin: UInt16
    
    public init(hue: UInt16=0, saturation: UInt16=0, brightness: UInt16=0, kelvin: UInt16=2500) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.kelvin = kelvin
    }
    
    public init(hue hueFraction: Float, saturation saturationFraction: Float, brightness brightnessFraction: Float, colorTemperature: ColorTemperature = .neutral) {
        self.init()
        self.hueFraction = hueFraction
        self.saturationFraction = saturationFraction
        self.brightnessFraction = brightnessFraction
        self.colorTemperature = colorTemperature
    }
    
    ///A value between 0 and 1 (which maps to 0° - 360°)
    public var hueFraction: Float {
        get {
            return Float(self.hue) / 65535
        }
        set {
            let val = max(min(newValue, 1), 0)
            self.hue = UInt16(val * 65535)
        }
    }
    
    ///A value between 0 and 1
    public var saturationFraction: Float {
        get {
            return Float(self.saturation) / 65535
        }
        set {
            let val = max(min(newValue, 1), 0)
            self.saturation = UInt16(val * 65535)
        }
    }
    
    ///A value between 0 and 1
    public var brightnessFraction: Float {
        get {
            return Float(self.brightness) / 65535
        }
        set {
            let val = max(min(newValue, 1), 0)
            self.brightness = UInt16(val * 65535)
        }
    }
    
    ///The color temperature mapped to one of a set of standard levels
    public var colorTemperature: ColorTemperature {
        get {
            return ColorTemperature.closestValue(kelvin: kelvin)
        }
        set {
            kelvin = newValue.rawValue
        }
    }
    
    public var debugDescription: String {
        return "(\(hue), \(saturation), \(brightness), \(kelvin))"
    }
    
    public var description: String {
        let h = String(format: "%.0f", hueFraction * 360)
        let s = String(format: "%.0f", saturationFraction * 100)
        let b = String(format: "%.0f", brightnessFraction * 100)
        return "\(h)°, \(s)%, \(b)%, \(kelvin)°K"
    }
    
}

//MARK: - Convenience constants

extension HSBK {
    public static let white = HSBK(hue: 0.0, saturation: 0.0, brightness: 1.0)
    public static let red = HSBK(hue: 0.0, saturation: 1.0, brightness: 1.0)
    public static let green = HSBK(hue: (120.0/360.0), saturation: 1.0, brightness: 1.0)
    public static let blue = HSBK(hue: (240.0/360.0), saturation: 1.0, brightness: 1.0)
}

//MARK: - Binary

extension HSBK: BinaryDecodable, BinaryEncodable {
    static let DataLength = 8
    
    init(binaryData: Data) throws {
        let packet = BinaryPacket(data: binaryData)
        hue = try packet.decode()
        saturation = try packet.decode()
        brightness = try packet.decode()
        kelvin = try packet.decode()
    }
    
    var binaryData: Data {
        let packet = BinaryPacket()
        packet.encode(hue)
        packet.encode(saturation)
        packet.encode(brightness)
        packet.encode(kelvin)
        return packet.data
    }
}

#if canImport(UIKit)

//MARK: - UIKit support

import UIKit
extension UIColor {
    var rgb: (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }
    
    var hsb: (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }
}
extension HSBK {
    ///The RGB color the light is configured with, ignoring intensity and color temperature.
    public var baseColor: UIColor {
        get {
            return UIColor(hue: CGFloat(hueFraction), saturation: CGFloat(saturationFraction), brightness: 1.0, alpha: 1.0)
        }
        set {
            let color = newValue.hsb
            hueFraction = Float(color.h)
            saturationFraction = Float(color.s)
            brightnessFraction = Float(color.b)
        }
    }
    
    ///An approximation of the light color for use in screen displays, taking intensity and color temperature into account.
    public var simulatedColor: UIColor {
        let baseColor = self.baseColor.rgb
        let whiteColor = colorFromTemperature(kelvin: kelvin)
        let a = CGFloat(saturationFraction)
        return UIColor(
            red: baseColor.r * (a + (CGFloat(whiteColor.r) * (1.0 - a))),
            green: baseColor.g * (a + (CGFloat(whiteColor.g) * (1.0 - a))),
            blue: baseColor.b * (a + (CGFloat(whiteColor.b) * (1.0 - a))),
            alpha: 1.0
        )
    }
}

#elseif canImport(AppKit)

//MARK: - AppKit support

import AppKit
extension HSBK {
    ///The RGB color the light is configured with, ignoring intensity and color temperature.
    public var baseColor: NSColor {
        get {
            return NSColor(calibratedHue: CGFloat(hueFraction), saturation: CGFloat(saturationFraction), brightness: 1.0, alpha: 1.0)
        }
        set {
            hueFraction = Float(newValue.hueComponent)
            saturationFraction = Float(newValue.saturationComponent)
            brightnessFraction = Float(newValue.brightnessComponent)
        }
    }
    
    ///An approximation of the light color for use in screen displays, taking intensity and color temperature into account.
    public var simulatedColor: NSColor {
        let whiteColor = colorFromTemperature(kelvin: kelvin)
        let a = CGFloat(saturationFraction)
        return NSColor(
            calibratedRed: baseColor.redComponent * (a + (CGFloat(whiteColor.r) * (1.0 - a))),
            green: baseColor.greenComponent * (a + (CGFloat(whiteColor.g) * (1.0 - a))),
            blue: baseColor.blueComponent * (a + (CGFloat(whiteColor.b) * (1.0 - a))),
            alpha: 1.0
        )
    }
}

#endif

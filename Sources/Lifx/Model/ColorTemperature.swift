import Foundation

public enum ColorTemperature: UInt16, CustomStringConvertible {
    case ultraWarm = 2500
    case incandescent = 2750
    case warm = 3000
    case neutralWarm = 3200
    case neutral = 3500
    case cool = 4000
    case coolDaylight = 4500
    case softDaylight = 5000
    case daylight = 5500
    case noonDaylight = 6000
    case brightDaylight = 6500
    case cloudyDaylight = 7000
    case blueDaylight = 7500
    case blueOvercast = 8000
    case blueWater = 8500
    case blueIce = 9000
    
    public var description: String {
        switch self {
        case .ultraWarm:
            return "Ultra Warm"
        case .incandescent:
            return "Incandescent"
        case .warm:
            return "Warm"
        case .neutralWarm:
            return "Neutral Warm"
        case .neutral:
            return "Neutral"
        case .cool:
            return "Cool"
        case .coolDaylight:
            return "Cool Daylight"
        case .softDaylight:
            return "Soft Daylight"
        case .daylight:
            return "Daylight"
        case .noonDaylight:
            return "Noon Daylight"
        case .brightDaylight:
            return "Bright Daylight"
        case .cloudyDaylight:
            return "Cloudy Daylight"
        case .blueDaylight:
            return "Blue Daylight"
        case .blueOvercast:
            return "Blue Overcast"
        case .blueWater:
            return "Blue Water"
        case .blueIce:
            return "Blue Ice"
        }
    }
    
    public static var allValues: [ColorTemperature] {
        return [.ultraWarm, .incandescent, .warm, .neutralWarm, .neutral,
                .cool, .coolDaylight, .softDaylight, .daylight, .noonDaylight,
                .brightDaylight, .cloudyDaylight, .blueDaylight, .blueOvercast,
                .blueWater, .blueIce]
    }
    
    public static func closestValue(kelvin: UInt16) -> ColorTemperature {
        let options = allValues
        if kelvin < options.first!.rawValue {
            return options.first!
        }
        for i in 1..<options.count {
            if kelvin < options[i].rawValue {
                let range = options[i].rawValue - options[i-1].rawValue
                if kelvin < (options[i-1].rawValue + (range / 2)) {
                    return options[i-1]
                } else {
                    return options[i]
                }
            }
        }
        return options.last!
    }
}

func colorFromTemperature(kelvin: UInt16) -> (r: Float, g: Float, b: Float) {
    //See https://community.lifx.com/t/factoring-kelvin-into-hsbk-to-rgb-conversion/4425/4
    var r: Float, g: Float, b: Float
    if kelvin < 6600 {
        r = 255;
        g = (100.0 * log(Float(kelvin)) - 620.0)
        b = (200.0 * log(Float(kelvin)) - 1500.0)
    } else {
        r = (480.0 * pow(Float(kelvin) - 6000.0, -0.1))
        g = (400.0 * pow(Float(kelvin) - 6000.0, -0.07))
        b = 255
    }
    r = min(max(r, 0), 255)
    g = min(max(g, 0), 255)
    b = min(max(b, 0), 255)
    return (r/255, g/255, b/255)
}

#if canImport(UIKit)

import UIKit
extension ColorTemperature {
    public static func color(kelvin: UInt16) -> UIColor {
        let components = colorFromTemperature(kelvin: kelvin)
        return UIColor(red: CGFloat(components.r), green: CGFloat(components.g), blue: CGFloat(components.b), alpha: 1.0)
    }
}

#elseif canImport(AppKit)

import AppKit
extension ColorTemperature {
    public static func color(kelvin: UInt16) -> NSColor {
        let components = colorFromTemperature(kelvin: kelvin)
        return NSColor(calibratedRed: CGFloat(components.r), green: CGFloat(components.g), blue: CGFloat(components.b), alpha: 1.0)
    }
}

#endif

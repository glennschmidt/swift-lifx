import Foundation

public enum SignalStrength: Int {
    case noSignal = 0
    case veryPoor
    case poor
    case good
    case excellent
    
    static func fromFloat(_ val: Float) -> SignalStrength {
        let val = floor(10 * log10(val) + 0.5)
        if val < 0 || val == 200 {
            // The value is RSSI
            if val == 200 {
                return .noSignal
            } else if val <= -80 {
                return .veryPoor
            } else if val <= -70 {
                return .poor
            } else if val <= -60 {
                return .good
            } else {
                return .excellent
            }
        } else {
            // The value is SNR
            if val == 4 || val == 5 {
                return .veryPoor
            } else if val >= 7 && val <= 11 {
                return .poor
            } else if val >= 12 && val <= 16 {
                return .good
            } else if val > 16 {
                return .excellent
            } else {
                return .noSignal
            }
        }
    }
}

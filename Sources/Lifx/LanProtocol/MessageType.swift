public enum MessageType: UInt16 {
    // Device messages
    // https://lan.developer.lifx.com/docs/device-messages
    
    case getService = 2
    case stateService = 3
    
    case getHostInfo = 12
    case stateHostInfo = 13
    
    case getHostFirmware = 14
    case stateHostFirmware = 15
    
    case getWiFiInfo = 16
    case stateWiFiInfo = 17
    
    case getWiFiFirmware = 18
    case stateWiFiFirmware = 19
    
    case getPower = 20
    case setPower = 21
    case statePower = 22
    
    case getLabel = 23
    case setLabel = 24
    case stateLabel = 25
    
    case getVersion = 32
    case stateVersion = 33
    
    case getInfo = 34
    case stateInfo = 35
    
    case acknowledgement = 45
    
    case getLocation = 48
    case setLocation = 49
    case stateLocation = 50
    
    case getGroup = 51
    case setGroup = 52
    case stateGroup = 53
    
    case echoRequest = 58
    case echoResponse = 59
    
    // Light Messages
    // https://lan.developer.lifx.com/docs/light-messages
    
    case getLight = 101
    case setColor = 102
    case setWaveform = 103
    case setWaveformOptional = 119
    case stateLight = 107
    
    case getLightPower = 116
    case setLightPower = 117
    case stateLightPower = 118
    
    case getInfrared = 120
    case stateInfrarer = 121
    case setInfrared = 122
    
    // MultiZone Messages
    // https://lan.developer.lifx.com/docs/multizone-messages
    
    case setColorZones = 501
    case getColorZones = 502
    case stateZone = 503
    case stateMultiZone = 506
    
    case getMultiZoneEffect = 507
    case setMultiZoneEffect = 508
    case stateMultiZoneEffect = 509
    
    case setExtendedColorZones = 510
    case getExtendedColorZones = 511
    case stateExtendedColorZones = 512
    
    // Tile Messages
    // https://lan.developer.lifx.com/docs/tile-messages
    
    case getDeviceChain = 701
    case stateDeviceChain = 702
    case setUserPosition = 703
    case getTileState64 = 707
    case stateTileState64 = 711
    case setTileState64 = 715
    
    case getTileEffect = 718
    case setTileEffect = 719
    case stateTileEffect = 720
}

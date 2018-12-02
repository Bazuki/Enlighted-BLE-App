//
//  EnlightedBLEConstants.swift
//  Enlighted BLE App
//
//  Created by Bryce Suzuki on 10/21/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

    // credit to http://ashishkakkad.com/2015/12/use-of-constant-define-in-swift-language-ios/
class EnlightedBLEProtocol
{
    // MARK: - Uart Protocol
    
    // MARK: Getters
    static let ENL_BLE_GET_LIMITS = "!GL"
    static let ENL_BLE_GET_BRIGHTNESS = "!GG"
    static let ENL_BLE_GET_BATTERY_LEVEL = "!GB"
    static let ENL_BLE_GET_NAME = "!GN"
    static let ENL_BLE_GET_MODE = "!GM"
    static let ENL_BLE_GET_THUMBNAIL = "!GT"
    
    // MARK: Setters
    static let ENL_BLE_SET_MODE = "!SM"
    static let ENL_BLE_SET_COLOR = "!SC"
    static let ENL_BLE_SET_BRIGHTNESS = "!SG"
    static let ENL_BLE_SET_BITMAP = "!SB"
    static let ENL_BLE_SET_STANDBY = "!SS"
}

class Constants
{
        // the time (in seconds) the device scans before analyzing what it found (and then scanning again)
    static let SCAN_DURATION = 0.5;
    
        // the time (in seconds) before the device decides to scrap and re-send a row of thumbnail pixels
    static let THUMBNAIL_ROW_TIMEOUT_TIME = 0.5;
    
    // the brightness setting (0-255) that the hardware goes into while in standby mode
    static let STANDBY_BRIGHTNESS = 50;
    
        // whether or not to use the "Standby" mode, since it's still being worked out and we don't want a non-functional app in the meantime
    static let USE_STANDBY_MODE = false;
    
        // relatedly, but independently to the above, whether to dim the brightness to STANDBY_BRIGHTNESS when loading modes.
    static let USE_STANDBY_BRIGHTNESS = true;
}

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
    
        // the time (in seconds) after which, if no Enlighted BLE devices are found, a "demo mode" device pops up
    static let SCAN_TIMEOUT_TIME = 2;
    
        // the filepath in the default app data to take to find the demo device's data (as of 1.0.5, we use an asset instead)
    //static let DEMO_DEVICE_PATH = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("baseDevice");
    
        // the name of the demo device
    static let DEMO_DEVICE_NAME = "Software Demo";
    
        // the time (in seconds) between scans of the battery level on the settings screen (as of 1.0.2, no longer used)
    //static let BATTERY_SCAN_INTERVAL = 0.33;
    
        // the time (in seconds) before the device decides to scrap and re-send a row of thumbnail pixels
            // The watchdog timer on the hardware is set to 0.3 seconds, but going too low causes it to time out far too often.
            // 0.2 seconds was a good middle ground to avoid both issues.
    static let THUMBNAIL_ROW_TIMEOUT_TIME = 0.2;
    
        // the default brightness to set the hardware to if it's at STANDBY_BRIGHTNESS
    static let DEFAULT_BRIGHTNESS = 127;
    
        // the brightness setting (0-255) that the hardware goes into while in standby mode
    static let STANDBY_BRIGHTNESS = 50;
    
        // whether or not to use the "Standby" mode, since it's still being worked out and we don't want a non-functional app in the meantime
    static let USE_STANDBY_MODE = true;
    
        // relatedly, but independently to the above, whether to dim the brightness to STANDBY_BRIGHTNESS when loading modes.
    static let USE_STANDBY_BRIGHTNESS = true;
    
//        // the text to show while loading modes
//    static let LOADING_MODES_TEXT = "Reading modes from hardware – ";
//
//        // the text to show while loading bitmaps/thumbnails
//    static let LOADING_BITMAPS_TEXT = "Reading bitmaps from hardware – ";
    
        // the number of packets that must be received before a mode is fully retrieved from hardware (1 for GetMode, 2 for GetName)
    static let BLE_PACKETS_PER_MODE = 3;
    
        // the number of packets that must be received before a bitmap/thumbnail is fully retrieved from hardware (4 per row, 20 rows)
    static let BLE_PACKETS_PER_BITMAP = 80;
    
}

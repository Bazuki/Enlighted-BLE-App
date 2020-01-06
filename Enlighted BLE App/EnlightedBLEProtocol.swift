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
    
        // getting the current mode index, and the number of modes/bitmaps
    static let ENL_BLE_GET_LIMITS = "!GL"
        // getting the current brightness of the hardware
    static let ENL_BLE_GET_BRIGHTNESS = "!GG"
        // getting the current battery level of the hardware
    static let ENL_BLE_GET_BATTERY_LEVEL = "!GB"
        // getting the version of the hardware
    static let ENL_BLE_GET_VERSION = "!GV"
        // getting the name of a specific mode
    static let ENL_BLE_GET_NAME = "!GN"
        // getting the type and values of a specific mode
    static let ENL_BLE_GET_MODE = "!GM"
        // getting a thumbnail for a bitmap, in multiple messages
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
    static let SCAN_DURATION = 0.85;
    
        // the time (in seconds) after which, if no Enlighted BLE devices are found, a "demo mode" device pops up
    static let SCAN_TIMEOUT_TIME = 2;
    
        // the filepath in the default app data to take to find the demo device's data (as of 1.0.5, we use an asset instead)
    //static let DEMO_DEVICE_PATH = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("baseDevice");
    
        // the name of the demo device
    static let DEMO_DEVICE_NAME = "Software Demo";
    
        // the time (in seconds) between scans of the battery level on the settings screen (as of 1.0.2, no longer used)
    //static let BATTERY_SCAN_INTERVAL = 0.33;
    
        // the time (in seconds) before the app decides to scrap and re-send a row of thumbnail pixels
    static let THUMBNAIL_ROW_TIMEOUT_TIME = 1.75;
    
        // the time (in seconds) before the app stops looking for a version response (as the nRF8001 does not provide one)
    static let VERSION_TIMEOUT_TIME = 0.2;
    
        // the default brightness to set the hardware to if it's at STANDBY_BRIGHTNESS
    static let DEFAULT_BRIGHTNESS = 127;
    
        // the brightness setting (0-255) that the hardware goes into while in standby mode
    static let STANDBY_BRIGHTNESS = 0;
    
        // whether or not to use the "Standby" mode
    static let USE_STANDBY_MODE = true;
    
        // relatedly, but independently to the above, whether to dim the brightness to STANDBY_BRIGHTNESS when loading modes.
    static let USE_STANDBY_BRIGHTNESS = true;
    
        // the number of packets that must be received before a mode is fully retrieved from hardware (1 for GetMode, 2 for GetName)
    static let BLE_PACKETS_PER_MODE = 3;
    
        // the number of packets that must be received before a bitmap/thumbnail is fully retrieved from hardware (4 per row, 20 rows)
    static let BLE_PACKETS_PER_BITMAP = 80;
    
        // states of the CB Central Manager
    // state table: https://docs.google.com/spreadsheets/d/1qkCTjl4jrx4dsB80Km5FRnuynXSmYpfE8jxph5dApZU/edit?usp=sharing
    // state machine diagram: https://www.lucidchart.com/documents/edit/9a907e3a-a3c4-4a81-a160-65591bbccd76/2?referringApp=google+drive&beaconFlowId=16967e152d3cf772
    enum CBCM_STATE
    {
        case UNCONNECTED_SCANNING_FOR_PRIMARY
        case READING_FROM_HARDWARE
        case NOT_SCANNING_FOR_MIMICS
        case CONNECTED_SCANNING_FOR_PRIMARY
        case SCANNING_FOR_MIMICS_TO_DISPLAY
        case SCANNING_FOR_MIMICS_TO_CONNECT
    }
    
        // the different potential hardware versions
    enum HARDWARE_VERSION
    {
        case UNKNOWN
        case DEMO
        case NRF8001
        case NRF51822
    }
    
        // a dictionary of functions that will test if a packet is "complete" according to varying standards
    static let PACKET_REQUIREMENTS =
    [
            // Get Battery Level should receive 3 bytes: [‘B’], [unsigned byte BattADCMSB], [unsigned byte BattADCLSB]
        EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL: {(data: [UInt8]) -> Bool in
            return data.count == 3;
        },
            // Get Limits should receive 4 bytes: [‘L’], [unsigned byte CurrentModeNumber], [unsigned byte LastModeNumber], [unsigned byte LastBitmapNumber]
        EnlightedBLEProtocol.ENL_BLE_GET_LIMITS: {(data: [UInt8]) -> Bool in
            return data.count == 4;
        },
            // Get Mode should receive 8 bytes: [‘M’], [unsigned byte ColorMode], [unsigned byte Red1], [unsigned byte Green1], [unsigned byte Blue1], [unsigned byte Red2], [unsigned byte Green2], [unsigned byte Blue2]
        EnlightedBLEProtocol.ENL_BLE_GET_MODE: {(data: [UInt8]) -> Bool in
            return data.count == 8;
        },
            // Get Name should receive a variable number of bytes, but the first and last bytes should always be ["]
        EnlightedBLEProtocol.ENL_BLE_GET_NAME: {(data: [UInt8]) -> Bool in
            let dataString = String(bytes: data, encoding: .ascii);
            return dataString?.prefix(1) == "\"" && dataString?.suffix(1) == "\"";
        },
            // Get Thumbnail should receive a 60-byte row (20 pixels, each with an R, G, and B-value byte).
        EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL: {(data: [UInt8]) -> Bool in
            return data.count == 60;
        },
            // Get Brightness should receive 2 bytes: [‘G’], [unsigned byte Brightness]
        EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS: {(data: [UInt8]) -> Bool in
            return data.count == 2;
        },
            // Get Version should receive 2 bytes: [‘V’], [ASCII Version]
        EnlightedBLEProtocol.ENL_BLE_GET_VERSION: {(data: [UInt8]) -> Bool in
            return data.count == 2;
        },
            // The Success response is a single byte: [1]
        "Success": {(data: [UInt8]) -> Bool in
            return data.count == 1;
        },
            // The Failure response is a single byte: [0]
        "Failure": {(data: [UInt8]) -> Bool in
            return data.count == 1;
        },
        
    ]
    
        // the messages this app sends
    struct MESSAGES
    {
        static let DISCOVERED_PRIMARY_CHARACTERISTICS = "discoveredPrimaryCharacteristics";
        static let DISCOVERED_MIMIC_CHARACTERISTICS = "discoveredMimicCharacteristics";
        static let DISCOVERED_NEW_PERIPHERALS = "discoveredNewPeripherals";
        
        static let RESEND_THUMBNAIL_ROW = "resendThumbnailRow";
        
        static let UPDATE_CBCENTRAL_STATE = "updateCBCentralState";
        static let START_SCAN = "startScan";
        
        static let RECEIVED_LIMITS_VALUE = "receivedLimitsValue";
        static let RECEIVED_BRIGHTNESS_VALUE = "receivedBrightnessValue";
        static let RECEIVED_BATTERY_VALUE = "receivedBatteryValue";
        static let RECEIVED_MODE_VALUE = "receivedModeValue";
        
        static let PARSED_COMPLETE_PACKET = "parsedCompletePacket";
        
        static let SAVE_DEVICE_CACHE = "saveDeviceCache";
        
        static let CHANGED_MODE_VALUE = "changedModeValue";
    }
}

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
        // because of packet size concerns, the set color command was shortened to !C
    static let ENL_BLE_SET_COLOR_NRF51822 = "!C"
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
    
        // the time (in seconds) the app waits before requesting new data from the nRF8001 after receiving it.
    static let NRF8001_DELAY_TIME = 0.021;
    
        // the time (in seconds) before the app decides to scrap and re-send a row of thumbnail pixels, per-device
    static let BLE_MESSAGE_TIMEOUT_TIME_NRF8001 = 0.25;
    
    static let BLE_MESSAGE_TIMEOUT_TIME_NRF51822 = 0.50;
    
        // if we have to retry a single tx packet more than this many times, we should alert the user to move closer
    static let NUM_ALLOWED_RETRIES_PER_PACKET = 5
    
        // the time (in seconds) before the app stops looking for a version response (as the nRF8001 does not provide one)
    static let VERSION_TIMEOUT_TIME = 0.35;
    
        // the default brightness to set the hardware to if it's at STANDBY_BRIGHTNESS
    static let DEFAULT_BRIGHTNESS = 127;
    
        // the brightness setting (0-255) that the hardware goes into while in standby mode
    static let STANDBY_BRIGHTNESS = 0;
    
        // whether or not to use the "Standby" mode
    static let USE_STANDBY_MODE = true;
    
        // relatedly, but independently to the above, whether to dim the brightness to STANDBY_BRIGHTNESS when loading modes.
    static let USE_STANDBY_BRIGHTNESS = true;
    
        // whether or not to prompt an email error report
    static let SEND_EMAIL_ERROR_REPORTS = true;
    
        // the email address to send error reports to
    static let ERROR_REPORT_EMAIL_RECIPIENTS = ["janet@enlighted.com"];
    
        // the number of packets that must be received before a mode is fully retrieved from hardware (1 for GetMode, 2 for GetName), used to help calculate progress bar
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
    
//        // MARK: error codes
//    enum ERROR: Int
//    {
//        typealias RawValue = Int
//
//            // Error codes starting with "1" relate to connecting to peripherals over BLE and discovering their services and characteristics
//        case FAILED_TO_CONNECT_TO_PERIPHERAL = 101
//        case FAILED_TO_DISCOVER_SERVICES = 102
//        case FAILED_TO_DISCOVER_CHARACTERISTICS = 103
//        case FAILED_TO_DISCOVER_CHARACTERISTIC_DESCRIPTORS = 104
//        case DISCONNECTED_FROM_PRIMARY_PERIPHERAL_UNEXPECTEDLY = 105
//        case DISCONNECTED_FROM_MIMIC_PERIPHERAL_UNEXPECTEDLY = 106
//        case FAILED_TO_UPDATE_CHARACTERISTIC_NOTIFICATION_STATE = 107
//        case FAILED_TO_READ_RSSI = 108
//
//            // Error codes starting with "2" relate to receiving/parsing the rx values we get from the hardware
//        case UNEXPECTED_PACKET_TYPE = 201
//        case UNABLE_TO_PARSE_PACKET = 202
//        case TIMEOUT_BEFORE_RECEIVING_COMPLETE_MESSAGE = 203
//        case CALLBACK_ERROR_FROM_DID_UPDATE_VALUE_FOR_RX = 204
//        case RECEIVED_EMPTY_RX_CHARACTERISTIC_VALUE = 205
//
//            // Error codes starting with "3" relate to sending tx messages
//        case FAILED_TO_SEND_PACKET = 301
//        case BAD_RESPONSE_TO_WRITE_WITH_RESPONSE = 302
//
//            // Error codes starting with "4" are app-related-only.
//        case FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_CONNECTION_TABLE = 401
//        case FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MODE_TABLE = 402
//        case FAILED_TO_DEQUEUE_COLLECTION_CELLS_FOR_BITMAP_PICKER = 403
//        case FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MIMIC_TABLE = 404
//        case NO_DEVICE_FOR_DEQUEUED_CONNECTION_TABLE_CELL = 405
//    }
    
        // MARK: Errors
            // Error codes starting with "1" relate to connecting to peripherals over BLE and discovering their services and characteristics
        // callback from CoreBluetooth when the Central Manager fails to connect to a selected peripheral
    static let FAILED_TO_CONNECT_TO_PERIPHERAL = ENL_ERROR("FAILED_TO_CONNECT_TO_PERIPHERAL", 101);
        // callback from CoreBluetooth when the Central Manager fails to discover a connected peripheral's services
    static let FAILED_TO_DISCOVER_SERVICES = ENL_ERROR("FAILED_TO_DISCOVER_SERVICES", 102, promptPopup: true);
        // callback from CoreBluetooth when the Central Manager fails to discover a connected peripheral's services' characteristics
    static let FAILED_TO_DISCOVER_CHARACTERISTICS = ENL_ERROR("FAILED_TO_DISCOVER_CHARACTERISTICS", 103, promptPopup: true);
        // callback from CoreBluetooth when the Central Manager fails to discover a connected peripheral's descriptors
    static let FAILED_TO_DISCOVER_CHARACTERISTIC_DESCRIPTORS = ENL_ERROR("FAILED_TO_DISCOVER_CHARACTERISTIC_DESCRIPTORS", 104, promptPopup: true);
        // callback from CoreBluetooth when we are unexpectedly disconnected from our "primary" peripheral, prompting the "disconnected" popup
    static let DISCONNECTED_FROM_PRIMARY_PERIPHERAL_UNEXPECTEDLY = ENL_ERROR("DISCONNECTED_FROM_PRIMARY_PERIPHERAL_UNEXPECTEDLY", 105);
        // callback from CoreBluetooth when we are unexpectedly disconnected from one of our mimic peripherals.  The peripheral is then removed from the list of connected mimic peripherals.
    static let DISCONNECTED_FROM_MIMIC_PERIPHERAL_UNEXPECTEDLY = ENL_ERROR("DISCONNECTED_FROM_MIMIC_PERIPHERAL_UNEXPECTEDLY", 106);
        // callback from CoreBluetooth when updating a characteristic's notification state (usually, the rx characteristic to the "Notify" state) fails
    static let FAILED_TO_UPDATE_CHARACTERISTIC_NOTIFICATION_STATE = ENL_ERROR("FAILED_TO_UPDATE_CHARACTERISTIC_NOTIFICATION_STATE", 107, promptPopup: true);
        // callback from CoreBluetooth when reading the RSSI of a connected peripheral fails (generally only done on the "Choose Device" screen, for the currently connected peripheral)
    static let FAILED_TO_READ_RSSI = ENL_ERROR("FAILED_TO_READ_RSSI", 108);
    
            // Error codes starting with "2" relate to receiving/parsing the rx values we get from the hardware
        // Thrown when the complete message we receive is not the same type as the one we expect given our most recent message.  This message is ignored, and new requests are sent if necessary.
    static let UNEXPECTED_PACKET_TYPE = ENL_ERROR("UNEXPECTED_PACKET_TYPE", 201, promptPopup: true);
        // Thrown if a received packet is unidentifiable, based on the BLE protocols.
    static let UNABLE_TO_PARSE_PACKET = ENL_ERROR("UNABLE_TO_PARSE_PACKET", 202, promptPopup: true);
        // Thrown if the BLE timeout timer fires before a completed message is received.  This triggers requestNextData() to re-request that data, if necessary.
    static let TIMEOUT_BEFORE_RECEIVING_COMPLETE_MESSAGE = ENL_ERROR("TIMEOUT_BEFORE_RECEIVING_COMPLETE_MESSAGE", 203);
        // callback from CoreBluetooth if an error occured in reading the value of the rx characteristic.
    static let CALLBACK_ERROR_FROM_DID_UPDATE_VALUE_FOR_RX = ENL_ERROR("CALLBACK_ERROR_FROM_DID_UPDATE_VALUE_FOR_RX", 204);
        // Thrown if the received value from the rx characteristic is empty.
    static let RECEIVED_EMPTY_RX_CHARACTERISTIC_VALUE = ENL_ERROR("RECEIVED_EMPTY_RX_CHARACTERISTIC_VALUE", 205, promptPopup: true);
    
            // Error codes starting with "3" relate to sending tx messages
        // Thrown when the app attempts to send a packet over the tx characteristic while we are still waiting for a response from a different characteristic.
    static let COULD_NOT_TX_BLE_BECAUSE_WAITING_FOR_RESPONSE = ENL_ERROR("COULD_NOT_TX_BLE_BECAUSE_WAITING_FOR_RESPONSE", 301);
        // callback from CoreBluetooth if an error occurs from a BLECharacteristicWriteType.withResponse message. Should never occur, as we use BLECharacteristicWriteType.withoutResponse.
    static let BAD_RESPONSE_TO_WRITE_WITH_RESPONSE = ENL_ERROR("BAD_RESPONSE_TO_WRITE_WITH_RESPONSE", 302, promptPopup: true);
        // Thrown when the app somehow attempts to send data on a characteristic it has not discovered
    static let ATTEMPTED_TO_SEND_PACKET_WITHOUT_DISCOVERING_CHARACTERISTIC = ENL_ERROR("ATTEMPTED_TO_SEND_PACKET_WITHOUT_DISCOVERING_CHARACTERISTIC", 303, promptPopup: true);
        // Thrown when a message sent over the tx characteristic is met with a failure response from the firmware ("0").
    static let RECEIVED_FAILURE_RESPONSE = ENL_ERROR("RECEIVED_FAILURE_RESPONSE", 304);
        // Caused when the app attempts to send a tx request that's already been sent Constants.NUM_ALLOWED_RETRIES_PER_PACKET times right before.
    static let REQUESTED_DATA_WITH_NO_RESPONSE_TOO_MANY_TIMES = ENL_ERROR("REQUESTED_DATA_WITH_NO_RESPONSE_TOO_MANY_TIMES", 305);
    
            // Error codes starting with "4" are app-related-only.
        // callback from TableViewDelegate when an error occurs dequeueing a reusable cell
    static let FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_CONNECTION_TABLE = ENL_ERROR("FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_CONNECTION_TABLE", 401, promptPopup: true);
        // callback from TableViewDelegate when an error occurs dequeueing a reusable cell
    static let FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MODE_TABLE = ENL_ERROR("FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MODE_TABLE", 402, promptPopup: true);
        // callback from CollectionViewDelegate when an error occurs dequeueing a reusable cell
    static let FAILED_TO_DEQUEUE_COLLECTION_CELLS_FOR_BITMAP_PICKER = ENL_ERROR("FAILED_TO_DEQUEUE_COLLECTION_CELLS_FOR_BITMAP_PICKER", 403, promptPopup: true);
        // callback from TableViewDelegate when an error occurs dequeueing a reusable cell
    static let FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MIMIC_TABLE = ENL_ERROR("FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MIMIC_TABLE", 404, promptPopup: true);
        // Thrown when a connection table view cell is set to be initialized, but there is no device to fill it.
    static let NO_DEVICE_FOR_DEQUEUED_CONNECTION_TABLE_CELL = ENL_ERROR("NO_DEVICE_FOR_DEQUEUED_CONNECTION_TABLE_CELL", 405, promptPopup: true);
        // Thrown when saving the cache fails.
    static let FAILED_TO_SAVE_DEVICES_IN_CACHE = ENL_ERROR("FAILED_TO_SAVE_DEVICES_IN_CACHE", 406, promptPopup: true);
        // Thrown when saving profiler .csv files fails.  Should only have a chance of occuring if the app is run with the profiling flag enabled.
    static let FAILED_TO_SAVE_PROFILER_CSV_FILES = ENL_ERROR("FAILED_TO_SAVE_PROFILER_CSV_FILES", 407, promptPopup: true);
        // Thrown when the "pixels to thumbnail UIImage" function is passed a "width" argument of 0.
    static let ATTEMPTED_TO_CREATE_THUMBNAIL_WITH_ZERO_WIDTH = ENL_ERROR("ATTEMPTED_TO_CREATE_THUMBNAIL_WITH_ZERO_WIDTH", 408, promptPopup: true);
        // Thrown when the number of pixels passed to the "pixels to thumbnail UIImage" function is not evenly divisible by the width argument.
    static let BITMAP_PIXELS_ARE_NOT_EVENLY_DIVISIBLE_BY_WIDTH = ENL_ERROR("BITMAP_PIXELS_ARE_NOT_EVENLY_DIVISIBLE_BY_WIDTH", 409, promptPopup: true);
        // Thrown when an error occurs initializing the dataprovider to convert the pixels to a CGImage.
    static let UNABLE_TO_CREATE_DATAPROVIDER_FOR_THUMBNAIL = ENL_ERROR("UNABLE_TO_CREATE_DATAPROVIDER_FOR_THUMBNAIL", 410, promptPopup: true);
        // Thrown when an error occurs converting pixels into a CGImage.
    static let UNABLE_TO_CREATE_THUMBNAIL_CGIMAGE_FROM_BITMAP_PIXELS = ENL_ERROR("UNABLE_TO_CREATE_THUMBNAIL_CGIMAGE_FROM_BITMAP_PIXELS", 411, promptPopup: true);
        // Thrown when a mode is set to use a thumbnail index greater than the number of thumbnails the app has stored;  For example, a mode that uses bitmap "32" when the max number of bitmaps is "20".
    static let CURRENT_MODE_THUMBNAIL_INDEX_EXCEEDS_STORED_THUMBNAILS = ENL_ERROR("CURRENT_MODE_THUMBNAIL_INDEX_EXCEEDS_STORED_THUMBNAILS", 412, promptPopup: true);
        // Thrown when there are fewer bitmaps stored than the max number of bitmaps found by the "Get Limits" request
    static let NOT_ENOUGH_STORED_BITMAPS_FOUND = ENL_ERROR("NOT_ENOUGH_STORED_BITMAPS_FOUND", 413, promptPopup: true);
    
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
            return dataString?.prefix(1) == "\"" && dataString?.suffix(1) == "\"" && data.count > 2;
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
        static let RESTART_BLE_RX_TIMEOUT_TIMER = "restartBLERxTimeoutTimer";
        static let STOP_BLE_RX_TIMEOUT_TIMER = "stopBLERxTimeoutTimer";
        
        static let UPDATE_CBCENTRAL_STATE = "updateCBCentralState";
        static let START_SCAN = "startScan";
        
        static let RECEIVED_LIMITS_VALUE = "receivedLimitsValue";
        static let RECEIVED_BRIGHTNESS_VALUE = "receivedBrightnessValue";
        static let RECEIVED_BATTERY_VALUE = "receivedBatteryValue";
        static let RECEIVED_MODE_VALUE = "receivedModeValue";
        
        static let PARSED_COMPLETE_PACKET = "parsedCompletePacket";
        
        static let SAVE_DEVICE_CACHE = "saveDeviceCache";
        
        static let CHANGED_MODE_VALUE = "changedModeValue";
        static let CHANGED_FIRST_COLOR = "changedFirstColor";
        
        static let SEND_ERROR_LOG_EMAIL = "sendErrorLogEmail";
    }
    
}

class ENL_ERROR
{
    var errorCode: Int
    var name: String
        // whether or not this error prompts a user alert, and allows them to send it to us over email
    var promptPopup: Bool;
    init(_ name: String, _ errorCode: Int, promptPopup: Bool = false)
    {
        self.errorCode = errorCode;
        self.name = name;
        self.promptPopup = promptPopup;
    }
}

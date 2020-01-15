//
//  ENLBLEDevice.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import CoreBluetooth;
import os.log;

class Device: NSObject, NSCoding
{
    
    
    // MARK: - Properties
    
        // data persistance/caching from https://developer.apple.com/library/archive/referencelibrary/GettingStarted/DevelopiOSAppsSwift/PersistData.html
    
        // key for keeping track of the cache's key Strings
    struct PropertyKey
    {
        static let modes = "modes";
        static let thumbnails = "thumbnails";
        static let name = "name";
        static let nickname = "nickname";
        static let NSUUID = "nsuuid";
        static let mimicList = "mimiclist";
        static let mimicListNames = "mimicListNames";
    }
    
    // MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("devices")
    
    // MARK: Profiling
    
        // toggle to enable/disable profiling (maybe should be in constants folder?)
    static let profiling = false;
    
    static var currentlyProfiling = false;
    
    static let mainProfilerFileName = "main_\(Date().timeIntervalSince1970).csv";
    static let mainProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(mainProfilerFileName);
    
    static let rxProfilerFileName = "rx_\(Date().timeIntervalSince1970).csv";
    static let rxProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(rxProfilerFileName);
    
    static let txProfilerFileName = "tx_\(Date().timeIntervalSince1970).csv";
    static let txProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(txProfilerFileName);
    
    static var lastTimestamp = 0.0;
    
        // for type: 3 is tx, 2 is rx complete packet, 1 is thumbnail (besides the final one)
    static var mainCsvText = "Action,Timestamp,Type,Duration\n";
    static var rxCsvText = "Rx Action,Rx Duration\n";
    static var txCsvText = "Tx Action,Tx Duration\n";
    
    static var profilerStopwatch = Date();
    
    var name: String;
    var nickname = "";
    var RSSI: Int;
    var batteryPercentage: Int = -1;
        // the current mode
    var currentModeIndex: Int;
    var mode = Mode(default: true);
    
        // whether or not this is a "demo", non-BLE enabled digital device
    var isDemoDevice = false;
    
        // whether this device uses the nRF8001 ("v1") or nRF51822 ("v2") hardware/firmware
    var hardwareVersion = Constants.HARDWARE_VERSION.UNKNOWN;
    
        // a list of all the modes this device has, from Get Mode;
    var modes = [Mode]();
    
        // a list of all the thumbnails this device has, from Get Thumbnail
    var thumbnails = [UIImage]();
    
        // a list of all the "mimic devices" that this device should command
    var mimicList = [NSUUID]();
    
    var mimicListNames = [String]();
    
        // a list of all the actual mimic devices this device is currently commanding
    var connectedMimicDevices = [Device]();
    
        // a way to track where Get Thumbnail is in getting a thumbnail
    var thumbnailRowIndex: Int = 0;
    
        // the max number of modes
    var maxNumModes: Int;
        // the max number of bitmaps
    var maxBitmaps: Int;
    
    var brightness: Int;
    
    var peripheral: CBPeripheral!;
    var txCharacteristic: CBCharacteristic?;
    var rxCharacteristic: CBCharacteristic?;
    var UUID: NSUUID!;
    
        // flags for connecting
    var isConnected: Bool = false;
    var isConnecting: Bool = false;
    var hasDiscoveredCharacteristics: Bool = false;
    
        // quasi-"handshaking" error check
    var expectedPacketType = "";
    
        // if a message fails/gives an improper response, we can send it again
    var lastUnsentMessage = [NSData]();
    
        // flags for parsing individual packets
    var requestedLimits = false;
    var requestedBrightness = false;
    var requestedVersion = false;
    var requestedBattery = false;
    var requestedName = false;
    var receivedName = false;
    var requestedMode = false;
    var requestedThumbnail = false;
    var requestedBrightnessChange = false;
    var requestedStandbyActivated = false;
    var requestedStandbyDeactivated = false;
    var requestedModeChange = false;
    var requestWithoutResponse = false;
    var requestedFirstOfTwoColorsChanged = false;
    
        // flag to prompt a popup about editting the mimic list when first entering the choose mode screen with a non-empty mimic list
    var promptedMimicListSettings = false;
    
        // flags / storage for the startup standby mode
    var isInStandby = false;
    var dimmedBrightnessForStandby = false;
    var storedBrightness = -1;
    
        // flags for parsing multiple packets / unusual cases
    var currentlyParsingName = false;
    var currentlyBuildingThumbnails = false;
    var currentlyRevertingMode = false;
    
    var readyToShowModes = false;
    
        // a timer to tell if it's an nRF8001 or nRF51822
    var getMimicVersionTimer = Timer();
    
    // MARK: Singleton
    
        // initializing as nil
    static var connectedDevice = Device(isFakeDevice: true, equalsNil: true);
    
    // MARK: Initialization
    
    init(name: String, RSSI: Int, peripheral: CBPeripheral)
    {
        self.name = name;
        self.RSSI = RSSI;
        self.peripheral = peripheral;
        self.UUID = peripheral.identifier as NSUUID;
        
        
        
            // default values, before being read from hardware
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
    
    // constructor from cache with everything discovered
    init(name: String, nickname: String, modes: [Mode], thumbnails: [UIImage], UUID: NSUUID, mimicList: [NSUUID], mimicListNames: [String])
    {
        self.name = name;
        self.nickname = nickname;
        self.RSSI = -1;
        self.peripheral = nil;
        self.UUID = UUID;
        self.mimicList = mimicList;
        self.mimicListNames = mimicListNames;
        
        self.modes = modes;
        self.thumbnails = thumbnails;
        
        // will also need to be read and set with the new protocol
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
        // constructor from cache with mimic list discovered but no mimic names array
    init(name: String, nickname: String, modes: [Mode], thumbnails: [UIImage], UUID: NSUUID, mimicList: [NSUUID])
    {
        self.name = name;
        self.nickname = nickname;
        self.RSSI = -1;
        self.peripheral = nil;
        self.UUID = UUID;
        self.mimicList = mimicList;
        
        self.modes = modes;
        self.thumbnails = thumbnails;
        
        // will also need to be read and set with the new protocol
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
    // constructor from cache WITHOUT mimic list discovered
    init(name: String, nickname: String, modes: [Mode], thumbnails: [UIImage], UUID: NSUUID)
    {
        self.name = name;
        self.nickname = nickname;
        self.RSSI = -1;
        self.peripheral = nil;
        self.UUID = UUID;
        //self.mimicList = [NSUUID]();
        
        self.modes = modes;
        self.thumbnails = thumbnails;
        
        // will also need to be read and set with the new protocol
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
        // for setting an empty reference for the current device
    init?(isFakeDevice: Bool, equalsNil: Bool)
    {
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
        return nil;
    }
    
    
    init(demoDeviceName: String)
    {
        self.name = demoDeviceName;
        
        isDemoDevice = true;
        // just for this demo, choosing a random int between 1 and 100 as the "RSSI value"
        RSSI = -1;
        
        // starting at mode -1; in the real app, would read current mode from device
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        
        // initial value;
        brightness = -1;
        
        hardwareVersion = .DEMO;
        
        // mock declaration without a peripheral, so not connected
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
        // an initializer for mimic devices, so they can be stored in a list
    init(mimicDevicePeripheral: CBPeripheral)
    {
        self.name = mimicDevicePeripheral.name ?? "unknown name";
        self.peripheral = mimicDevicePeripheral;
        isDemoDevice = false;
        RSSI = -1;
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        isConnected = true;
        isConnecting = false
        hasDiscoveredCharacteristics = false;
    }
    
        // an initializer to show mimics that are on the mimic list but not advertising
    init(mimicDeviceName: String)
    {
        self.name = mimicDeviceName;
        //self.peripheral = mimicDevicePeripheral;
        isDemoDevice = false;
        RSSI = -1;
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        isConnected = true;
        isConnecting = false
        hasDiscoveredCharacteristics = false;
    }
    
        // as a placeholder when disconnecting from a device.
    init(_ emptyDevice: Bool)
    {
        
        self.name = "emptyDevice";
        
            // just for this demo, choosing a random int between 1 and 100 as the "RSSI value"
        RSSI = -1;
        
            // starting at mode -1; in the real app, would read current mode from device
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
            
            // initial value;
        brightness = -1;
            
            // mock declaration without a peripheral, so not connected
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
        
    }
    
    // MARK: - Actions
    
    func setBrightness(value: Int)
    {
        brightness = value;
    }
    
    func setBatteryPercentage(percentage: Int)
    {
        batteryPercentage = percentage;
    }
    
    func setTXCharacteristic(_ txCharacteristic: CBCharacteristic)
    {
        self.txCharacteristic = txCharacteristic;
    }
    
    func setRXCharacteristic(_ rxCharacteristic: CBCharacteristic)
    {
        self.rxCharacteristic = rxCharacteristic;
    }
    
        // setting the timer 
    func setGetMimicVersionTimer()
    {
        getMimicVersionTimer.invalidate();
        getMimicVersionTimer = Timer.scheduledTimer(withTimeInterval: Constants.VERSION_TIMEOUT_TIME, repeats: false)
        { timer in
            //os_log("Sending message", log: OSLog.default, type: .debug);
            if (self.hardwareVersion == .UNKNOWN)
            {
                self.hardwareVersion = .NRF8001;
            }
        }
    }
    
    public static func setConnectedDevice(newDevice: Device)
    {
        connectedDevice = newDevice;
    }
    
    public static func createDemoDevice() -> Device
    {
        let demoDeviceData = NSDataAsset.init(name: "Data");
        var devices = NSKeyedUnarchiver.unarchiveObject(with: demoDeviceData!.data) as? [Device];
        var output = devices![0];
        output.isDemoDevice = true;
        output.hardwareVersion = .DEMO;
        output.name = Constants.DEMO_DEVICE_NAME;
        
        return output;
    }
    
        // a function for formatting packets to be sent over BLE.  This function returns an array of two NSData objects, the first for the nRF8001 and the second for the nRF51822 protocols
    public static func formatPacket(_ inputString: String, inputInts: [Int] = [Int](), digitsPerInput: Int = 2) -> [NSData]
    {
        //print(" ");
        //print(" ");
        //print("Formatting BLE command \(inputString) with arguments \(inputInts)")
        
        
            // formatting the string part of the packet
        var intsToParse = inputInts;
        let stringArray: [UInt8] = Array(inputString.utf8);
        var uInt8Array8001 = [UInt8]();
        var uInt8Array51822 = [UInt8]();
            // formatting ints, if any
        if (intsToParse.count > 0)
        {
                // No longer the case:
                // Set color for the nRF51822 has its first index byte be one digit, while the RGB values themselves are 3 bytes per channel.
//            if (inputString.elementsEqual(EnlightedBLEProtocol.ENL_BLE_SET_COLOR))
//            {
//                uInt8Array51822 += formatForNRF51822(intsToParse[0], numExpectedDigits: 1)
//                uInt8Array8001.append(UInt8(intsToParse[0]));
//                intsToParse.remove(at: 0);
//            }
            
            
            while (intsToParse.count > 0)
            {
                    // the nRF51822 protocol requires special formatting
                uInt8Array51822 += (formatForNRF51822(intsToParse[0], numExpectedDigits: digitsPerInput));
               
                uInt8Array8001.append(UInt8(intsToParse[0]));
                
                intsToParse.remove(at: 0);
            }
        }
        
            // formatting as data
        let outputArray8001 = stringArray + uInt8Array8001;
        let outputData8001 = NSData(bytes: outputArray8001, length: outputArray8001.count);
        
        var outputArray51822 = stringArray + uInt8Array51822;
            // in order to fit both colors in one packet on the nRF51822 protocol, "Set Color" is actually !C, not !SC, and so requires a special string
        if (inputString.elementsEqual(EnlightedBLEProtocol.ENL_BLE_SET_COLOR))
        {
            let nRF51822StringArray: [UInt8] = Array(EnlightedBLEProtocol.ENL_BLE_SET_COLOR_NRF51822.utf8);
            outputArray51822 = nRF51822StringArray + uInt8Array51822;
        }
        let outputData51822 = NSData(bytes: outputArray51822, length: outputArray51822.count);
        
            // MARK: profiling: sending message
        if (Device.profiling && Device.currentlyProfiling)
        {
                // 'type' is 3, a sent message
            var commandString = "tx: \(inputString)";
            let duration = (Date().timeIntervalSince(Device.profilerStopwatch) - Device.lastTimestamp) * 1000;
            Device.lastTimestamp = Date().timeIntervalSince(Device.profilerStopwatch);
            commandString += (inputInts.map { String($0) }.joined(separator: " "));
            let newMainLine = "\(commandString),\(Date().timeIntervalSince(Device.profilerStopwatch)),\(3),\(duration)\n";
            let newTxLine = "\(commandString),\(duration)\n";
            Device.mainCsvText.append(contentsOf: newMainLine);
            Device.txCsvText.append(contentsOf: newTxLine);
        }
        
            // "handshaking" error tracking;
            // if we did a set command, we expect the "success" response
        if (inputString.prefix(2).lowercased().elementsEqual("!s"))
        {
            Device.connectedDevice!.expectedPacketType = "Success";
        }
            // while if we did a get command, we expect an appropriate response
        else
        {
            Device.connectedDevice!.expectedPacketType = inputString;
        }
        
            // returning formatted data
        return [outputData8001, outputData51822];
    }
    
    private static func formatForNRF51822(_ input: Int, numExpectedDigits: Int = 2) -> [UInt8]
    {
        var inputString = String(input);
        var output = [UInt8]();
        
        // hundreds place (if necessary)
        while inputString.count < numExpectedDigits
        {
                // add as many leading zeroes as necessary
            inputString = "0" + inputString;
        }
        
        output = Array(inputString.utf8);
        return output;
        
    }
    
    private static func formatAsLegalInt(_ value: Int) -> Int
    {
            // absolute value
        var output = abs(value);
        
        output = min(Int(UInt8.max), max(value, Int(UInt8.min)));
        
        return output;
    }
    
    public static func convertUIColorToIntArray(_ color: UIColor) -> [Int]
    {
        // creating variables for RGB values of color
        var red: CGFloat = 0;
        var green: CGFloat = 0;
        var blue: CGFloat = 0;
        var alpha: CGFloat = 0;
        
        // getting color1's RGB values (from 0 to 1.0)
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // scaling up to 255
        red *= 255;
        green *= 255;
        blue *= 255;
        
        // removing decimal places, removing signs
        let redInt = formatAsLegalInt(Int(red));
        let greenInt = formatAsLegalInt(Int(green));
        let blueInt = formatAsLegalInt(Int(blue));
        
        return [redInt] + [greenInt] + [blueInt];
    }
    
        // a function for reporting errors, whose function can be determined later
    public static func reportError(_ error: ENL_ERROR, additionalInfo: String = "")
    {
        print("");
        print("*************************************************************************");
        print("");
        os_log("Received an error with error code:", log: OSLog.default, type: .debug);
        print("                         \(error.errorCode)               ")
        print("                     Name: \(error.name)");
        print("                 \(additionalInfo)");
        print("");
        print("*************************************************************************");
        print("");
        
        
    }
    
    // MARK: - NSCoding
    
    func encode(with aCoder: NSCoder)
    {
            // encoding name (in order to recognize it) and modes and thumbnails (because of their size)
        aCoder.encode(name, forKey: PropertyKey.name);
        aCoder.encode(nickname, forKey: PropertyKey.nickname);
        aCoder.encode(modes, forKey: PropertyKey.modes);
        aCoder.encode(UUID, forKey: PropertyKey.NSUUID)
        //print("Just encoded \(modes.count) modes");
        aCoder.encode(thumbnails, forKey: PropertyKey.thumbnails);
        aCoder.encode(mimicList, forKey: PropertyKey.mimicList);
        aCoder.encode(mimicListNames, forKey: PropertyKey.mimicListNames);
    }
    
    required convenience init?(coder aDecoder: NSCoder)
    {
        guard let modes = aDecoder.decodeObject(forKey: PropertyKey.modes) as? [Mode] else
        {
            os_log("Unable to decode the modes for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
        guard let thumbnails = aDecoder.decodeObject(forKey: PropertyKey.thumbnails) as? [UIImage] else
        {
            os_log("Unable to decode the thumbnails for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else
        {
            os_log("Unable to decode the name for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
        guard let nickname = aDecoder.decodeObject(forKey: PropertyKey.nickname) as? String else
        {
            os_log("Unable to decode the nickname for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
        guard let UUID = aDecoder.decodeObject(forKey: PropertyKey.NSUUID) as? NSUUID else
        {
            os_log("Unable to decode the CBPeripheral for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
        
        guard let mimicList = aDecoder.decodeObject(forKey: PropertyKey.mimicList) as? [NSUUID] else
        {
            os_log("Unable to decode the mimic list for the Device.", log: OSLog.default, type: .debug);
            self.init(name: name, nickname: nickname, modes: modes, thumbnails: thumbnails, UUID: UUID);
            return;
        }
        
        guard let mimicListNames = aDecoder.decodeObject(forKey: PropertyKey.mimicListNames) as? [String] else
        {
            os_log("Unable to decode the mimic list names for the Device.", log: OSLog.default, type: .debug);
            self.init(name: name, nickname: nickname, modes: modes, thumbnails: thumbnails, UUID: UUID, mimicList: mimicList);
            return;
        }
        
            // must call designated initializer.
        self.init(name: name, nickname: nickname, modes: modes, thumbnails: thumbnails, UUID: UUID, mimicList: mimicList, mimicListNames: mimicListNames);
    }
}




// MARK: - Data + CRC
extension Data {
    mutating func appendCrc() {
        var dataBytes = [UInt8](repeating: 0, count: count)
        copyBytes(to: &dataBytes, count: count)
        
        var crc: UInt8 = 0
        for i in dataBytes {    //add all bytes
            crc = crc &+ i
        }
        crc = ~crc  //invert
        
        append(&crc, count: 1)
    }
}

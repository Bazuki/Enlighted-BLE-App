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
        static let NSUUID = "nsuuid";
    }
    
    // MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("devices")
    
    var name: String;
    var RSSI: Int;
    var batteryPercentage: Int = -1;
        // the current mode
    var currentModeIndex: Int;
    var mode = Mode(default: true);
    
        // whether or not this is a "demo", non-BLE enabled digital device
    var isDemoDevice = false;
    
        // a list of all the modes this device has, from Get Mode;
    var modes = [Mode]();
    
        // a list of all the thumbnails this device has, from Get Thumbnail
    var thumbnails = [UIImage]();
    
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
    
        // flags for parsing individual packets
    var requestedLimits = false;
    var requestedBrightness = false;
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
    
        // flags / storage for the startup standby mode
    var isInStandby = false;
    var dimmedBrightnessForStandby = false;
    var storedBrightness = -1;
    
        // flags for parsing multiple packets / unusual cases
    var currentlyParsingName = false;
    var currentlyBuildingThumbnails = false;
    var currentlyRevertingMode = false;
    
    var readyToShowModes = false;
    
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
        
        
        
        // will also need to be read and set with the new protocol
        currentModeIndex = -1;
        maxNumModes = -1;
        maxBitmaps = -1;
        brightness = -1;
        
        isConnected = false;
        isConnecting = false;
        hasDiscoveredCharacteristics = false;
    }
    
    init(name: String, modes: [Mode], thumbnails: [UIImage], UUID: NSUUID)
    {
        self.name = name;
        self.RSSI = -1;
        self.peripheral = nil;
        self.UUID = UUID;
        
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
        
        // mock declaration without a peripheral, so not connected
        isConnected = false;
        isConnecting = false;
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
    
    func setBrightness(value:Int)
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
        output.name = Constants.DEMO_DEVICE_NAME;
        
        return output;
    }
    
    // MARK: - NSCoding
    
    func encode(with aCoder: NSCoder)
    {
            // encoding name (in order to recognize it) and modes and thumbnails (because of their size)
        aCoder.encode(name, forKey: PropertyKey.name);
        aCoder.encode(modes, forKey: PropertyKey.modes);
        aCoder.encode(UUID, forKey: PropertyKey.NSUUID)
        //print("Just encoded \(modes.count) modes");
        aCoder.encode(thumbnails, forKey: PropertyKey.thumbnails);
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
        
        guard let UUID = aDecoder.decodeObject(forKey: PropertyKey.NSUUID) as? NSUUID else
        {
            os_log("Unable to decode the CBPeripheral for the Device.", log: OSLog.default, type: .debug);
            return nil;
        }
        
            // must call designated initializer.
        self.init(name: name, modes: modes, thumbnails: thumbnails, UUID: UUID);
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

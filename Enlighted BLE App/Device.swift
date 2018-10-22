//
//  ENLBLEDevice.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import CoreBluetooth;

class Device
{
    // MARK: Properties
    
    var name: String;
    var RSSI: Int;
    var batteryPercentage: Int = 100;
        // the current mode
    var currentModeIndex: Int;
    var mode = Mode();
    
        // the max number of modes
    var maxNumModes: Int;
    
    var brightness: Int;
    
    var peripheral: CBPeripheral!;
    var txCharacteristic: CBCharacteristic?;
    var rxCharacteristic: CBCharacteristic?;
    
    var isConnected: Bool = false;
    
    // MARK: Singleton
    
    static var connectedDevice = Device();
    
    // MARK: Initialization
    
    // creating a new "device" for purposes of flow, with useless parameters.  In actual implementation, these would be read from the device.
    init(name:String)
    {
        self.name = name;
        
        // just for this demo, choosing a random int between 1 and 100 as the "RSSI value"
        RSSI = Int(arc4random_uniform(100) + 1);
        
        // starting at mode 1; in the real app, would read current mode from device
        currentModeIndex = 1;
        maxNumModes = 4;
        
        // initial value;
        brightness = 50;
        
            // mock declaration without a peripheral, so not connected
        isConnected = false;
        
    }
    
    init(name: String, RSSI: Int, peripheral: CBPeripheral)
    {
        self.name = name;
        self.RSSI = RSSI;
        self.peripheral = peripheral;
        
        
        
        // will also need to be read and set with the new protocol
        currentModeIndex = 1;
        maxNumModes = 4;
        brightness = 50;
        
        isConnected = true;
        
    }
    
    // for setting an empty reference for the current device
    init?()
    {
        isConnected = false;
        return nil;
    }
    
    // MARK: Actions
    
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

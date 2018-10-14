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
    var currentModeIndex: Int;
    var mode = Mode();
    
    var brightness: Int;
    
    var peripheral: CBPeripheral!;
    
    
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
        
        // initial value;
        brightness = 50;
    }
    
    init(name:String, RSSI: Int, peripheral: CBPeripheral)
    {
        self.name = name;
        self.RSSI = RSSI;
        self.peripheral = peripheral;
        
        // will also need to be read and set
        currentModeIndex = 1;
        brightness = 50;
    }
    
    // for setting an empty reference for the current device
    init?()
    {
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
    
    public static func setConnectedDevice(newDevice: Device)
    {
        connectedDevice = newDevice;
    }
}

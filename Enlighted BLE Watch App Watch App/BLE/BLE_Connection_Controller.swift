//
//  BLE_Connection_Controller.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/17/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import Foundation
import CoreBluetooth
import UIKit

var txCharacteristic : CBCharacteristic?;
var rxCharacteristic : CBCharacteristic?;
var batteryCharacteristic : CBCharacteristic?;

var blePeripheral: CBPeripheral?;
// temporary place to display read Characteristic strings, before parsing
var rxCharacteristicValue = String();//NSData();

// a timer to see how long the BLE board takes to respond to BLE requests
var packetStopwatch = Date();


class BLEConnectionController: NSObject, CBCentralManagerDelegate, ObservableObject, CBPeripheralDelegate, Observable {
    @Published var isBluetoothEnabled = false
    
    // The bluetooth CentralManager object controlling the connection to peripherals
    private var centralManager: CBCentralManager!
    
    //MARK: Properties copied from the iOS version
    static var CBCentralState: Constants.CBCM_STATE = .UNCONNECTED_SCANNING_FOR_PRIMARY;
    
    static var advertisingPeripherals = [CBPeripheral]();
    
    static var advertisingRSSIs = [NSNumber]();
    
    static var nicknames = [String]();
    
    // The WatchDevices that show up on the connection screen.
    @Published var visibleDevices: [Enlighted_BLE_Watch_App_Watch_App.WatchDevice] = [Enlighted_BLE_Watch_App_Watch_App.WatchDevice]()
    
    // the demo WatchDevice
    var demoDevice: Enlighted_BLE_Watch_App_Watch_App.WatchDevice = Enlighted_BLE_Watch_App_Watch_App.WatchDevice(true)
    
    // theWatchDevices we have stored in memory, which we will recognize by name
    var cachedDevices: [Enlighted_BLE_Watch_App_Watch_App.WatchDevice] = [Enlighted_BLE_Watch_App_Watch_App.WatchDevice]()
    
    // A timer object to help in searching
    var timer = Timer();
    
    // A timer object to know when to prompt the "Demo" WatchDevice
    var WatchDeviceTimeoutTimer = Timer();
    
    var BLETimeoutTimer = Timer();
    
    // A timer to introduce a delay for older hardware
    var delayTimer = Timer();
    
    // Whether or not the demo WatchDevice can show up (if there are no "real" WatchDevices)
    @Published var canShowDemoDevice = false;
    
    // list of peripherals, and their associated RSSI values
    var peripherals: [CBPeripheral] = [];
    // want to get "real" names from advertising data
    var peripheralNames = [String]();
    var RSSIs = [NSNumber]();
    var data = NSMutableData();
    
    // variable to help in parsing names
    var parsedName: String = "";
    
    // variable for identifying the additional packets of multi-packet messages - should only be set to "" or one of the EnlightedBLEProtocol get command strings.
    var currentPacketType: String = "";
    
    // variable for keeping track of the contents of multi-packet messages
    var currentPacketContents = [UInt8]();
    
    // variable for keeping track of whether we need to construct a multipacket message or start a new one
    var incompletePacketReceived = false;
    
    // pixel data – credit to https://stackoverflow.com/questions/30958427/pixel-array-to-uiimage-in-swift
    public struct Pixel
    {
        var r: UInt8;
        var g: UInt8;
        var b: UInt8;
        var a: UInt8 = 255;
    }
    
    var bitmapPixels = [Pixel]();
    var bitmapPixelRow = [Pixel]();
    
    var initialSearchingIndicatorHeight: CGFloat = 0;
    
    // override constructor so we can initialize our central manager and setup the start scan listener
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(startScan), name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(requestNextDataWithDelay), name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil)
    }
    
    //Automatically called when the central manager has a new state
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn{
            //If bluetooth is on, let's start scanning
            Swift.print("Bluetooth Enabled")
            isBluetoothEnabled = true
            startScan()
        }
        else{ //If bluetooth is off, we're just going to disconnect
            Swift.print("Should go to the Connect Screen at this point")
            //disconnect from the active WatchDevice, if there is one
            peripherals = [CBPeripheral]()
            peripheralNames = [String]()
            RSSIs = [NSNumber]()
            visibleDevices = [Enlighted_BLE_Watch_App_Watch_App.WatchDevice]()
            isBluetoothEnabled = false
            //TODO: Also make sure the table updates and hide the searching indicator (should be handled in front end)
            
            Swift.print("Bluetooth disabled, make sure your WatchDevice is turned on")
            //TODO: Bluetooth pop-up (should be handled by front end) and display demoWatchDevice
        }
    }
    
    //Called every time the CBCentralManager finds a bluetooth device 
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
            // the true (non-cached) advertised name of the device
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String;
        
        if (advertisedName?.lowercased().prefix(3) == "enl")
        {
            print("Found a new device \(String(describing: advertisedName)), cached name \(String(describing: peripheral.name)), adding it, its advertised name, and its RSSI to the list");
            self.peripherals.append(peripheral);
                // if there wasn't an advertised name, use the real name
            self.peripheralNames.append(advertisedName ?? peripheral.name!);
            self.RSSIs.append(RSSI);
            print("      List state: \(self.peripherals)")
        }
        else
        {
            print("Found a new device \(String(describing: advertisedName)), but it doesn't look like it's an Enlighted device, so it will be excluded from the list");
            return;
        }
        
        peripheral.delegate = self;
            // discovering Bluefruit GATT services (shouldn't be done here, this is for connected devices)
        //peripheral.discoverServices([BLEService_UUID]);
            // discovering BLE services related to battery
        //peripheral.discoverServices([BLEBatteryService_UUID]);
            // reloading table view data
        //deviceTableView.reloadData();
//        if blePeripheral == nil
//        {
//            print("We found a new peripheral device with services");
//            print("Peripheral name: \(peripheral.name ?? "no name")");
//            print("*****************************");
//            print("Advertisement data: \(advertisementData)");
//            blePeripheral = peripheral;
//        }
    }
    
        // starting to scan for peripherals that have Bluefruit's unique GATT indicator
    @objc func startScan()
    {
        let scanTime = Constants.SCAN_DURATION;
        
            // don't scan if we can't
        if (centralManager.state != CBManagerState.poweredOn)
        {
            print("Bluetooth isn't available right now, make sure it's activated on your phone");
            return;
        }
        
            // debug message to make sure we're connecting/disconnecting properly
        //print(centralManager.retrieveConnectedPeripherals(withServices: [BLEService_UUID]));
        
            // make sure everything is hidden/shown correctly – if we aren't connected, and not currently connecting
        if ((WatchDevice.connectedDevice == nil || WatchDevice.connectedDevice?.name == "emptyDevice") && !(WatchDevice.connectedDevice?.isConnecting ?? false))
        {
            //TODO: Indicate searching
        }
        
            // clearing the visibleDevices list when we're scanning again
        //visibleDevices = [Device]();
        peripherals = [CBPeripheral]();
        peripheralNames = [String]();
        RSSIs = [NSNumber]();
        
        print("Now scanning...");
        self.timer.invalidate();
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        self.timer = Timer.scheduledTimer(timeInterval: scanTime, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false);
    }
    
        // cancelling the scan for peripherals
    @objc func cancelScan()
    {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
        
            // making the peripherals visible from anywhere
        BLEConnectionController.advertisingPeripherals = peripherals;
        BLEConnectionController.advertisingRSSIs = RSSIs;
        
        // if we're scanning for a primary device, update that list
        if (BLEConnectionController.CBCentralState == .UNCONNECTED_SCANNING_FOR_PRIMARY || BLEConnectionController.CBCentralState == .CONNECTED_SCANNING_FOR_PRIMARY)
            //(Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
        {
                // going through devices
            if (visibleDevices.count > 0)
            {
                // if there are real devices, we don't want to be immediately showing the demo device afterward
                canShowDemoDevice = false;
                if (WatchDeviceTimeoutTimer.isValid)
                {
                    WatchDeviceTimeoutTimer.invalidate();
                }
                
                
                var deviceIndex = 0;
                while (deviceIndex < visibleDevices.count)
                {
                        // update device RSSIs of devices we know
                    if let foundPeripheralIndex = peripherals.firstIndex(of: visibleDevices[deviceIndex].peripheral)
                    {
                        print("Found a new RSSI for \(visibleDevices[deviceIndex].name)");
                        visibleDevices[deviceIndex].RSSI = RSSIs[foundPeripheralIndex].intValue;
                            // since we already have a Device for this peripheral, we can remove it (and its corresponding RSSI value and name)
                        peripherals.remove(at: foundPeripheralIndex);
                        peripheralNames.remove(at: foundPeripheralIndex);
                        RSSIs.remove(at: foundPeripheralIndex);
                        
                        deviceIndex += 1;
                    }
                            // if we don't see this peripheral anymore
                    else if (!peripherals.contains(visibleDevices[deviceIndex].peripheral))
                    {
                            // if it's because we're already connected, then we want to read the RSSI (which is done differently)
                        if (WatchDevice.connectedDevice?.peripheral == visibleDevices[deviceIndex].peripheral)
                        {
                            WatchDevice.connectedDevice?.peripheral.readRSSI();
                            visibleDevices[deviceIndex].RSSI = WatchDevice.connectedDevice!.RSSI;
                            deviceIndex += 1;
                        }
                        else
                        {
                            print("Removing device named \(visibleDevices[deviceIndex].name)");
                            visibleDevices.remove(at: deviceIndex);
                        }
                        
                    }
                    else
                    {
                        deviceIndex += 1;
                    }
                }
            }
            
            // we removed peripherals we have devices for already, so there should only be "new" peripherals in this array now
            if (peripherals.count > 0)
            {
                print("Found an extra peripheral besides the \(visibleDevices.count) we already knew about");
                for i in 0...(peripherals.count - 1)
                {
                    print("Found a new device named \(peripheralNames[i]), adding it");
                    
                    if (cachedDevices.count > 0)
                    {
                            // whether or not we recognized this device as one of our own
                        var foundCachedDevice = false;
                        
                        let backwardsIndex = cachedDevices.count - 1;
                            // going through cache to see if we can match the name
                        for j in 0...(cachedDevices.count - 1)
                        {
                            
                                // if they have the same name, use that instead of creating a new device
                            if (cachedDevices[backwardsIndex - j].UUID! as UUID == peripherals[i].identifier)
                            {
                                let newDevice = cachedDevices[backwardsIndex - j];
                                newDevice.peripheral = peripherals[i];
                                newDevice.RSSI = RSSIs[i].intValue;
                                    // because we may have cached an old name, overwriting it here
                                newDevice.name = peripheralNames[i];
                                visibleDevices.append(newDevice);
                                foundCachedDevice = true;
                                print("We recognized it from our cache at index \(backwardsIndex - j) (out of \(backwardsIndex + 1) total), adding \(peripheralNames[i]) to visible device list");
                                print("It has \(newDevice.modes.count) modes and \(newDevice.thumbnails.count) thumbnails stored");
                                break;
                            }
                        }
                        
                        if (!foundCachedDevice)
                        {
                            // otherwise create a brand-new device
                            print("Didn't recognize it from cache, creating new device");
                            visibleDevices.append(WatchDevice(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i]));
                        }
                    }
                    else
                    {
                        // otherwise create a brand-new device
                        visibleDevices.append(WatchDevice(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i]));
                    }
                }
            }
                // if there aren't any visible devices and no peripherals, we should start the countdown to show the "demo device":
            else
            {
                    // as long as we are not already counting down AND we aren't connected to a device
                if (!(WatchDeviceTimeoutTimer.isValid) && WatchDevice.connectedDevice == nil)
                {
                    // create a new timer and when it fires, the demo device can be shown (if there are no "real" devices found)
                    print("starting demo device countdown")
                    WatchDeviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Constants.SCAN_TIMEOUT_TIME), repeats: false, block:
                                                                    { (WatchDeviceTimeoutTimer) in
                        if (WatchDevice.connectedDevice == nil){
                            self.canShowDemoDevice = true;
                            print("Showing demo device")
                        } else {
                            print("We've connected since timer was fired, not showing demo")
                        }
                    })
                } else if (!(WatchDeviceTimeoutTimer.isValid) && WatchDevice.connectedDevice!.name == "nil"){
                    // create a new timer and when it fires, the demo device can be shown (if there are no "real" devices found)
                    print("starting demo device countdown")
                    WatchDeviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Constants.SCAN_TIMEOUT_TIME), repeats: false, block:
                                                                    { (WatchDeviceTimeoutTimer) in
                        if (WatchDevice.connectedDevice == nil){
                            self.canShowDemoDevice = true;
                            print("Showing demo device")
                        } else {
                            print("We've connected since timer was fired, not showing demo")
                        }
                    })
                }
            }
            // if the device hasn't connected, keep scanning
            if (WatchDevice.connectedDevice == nil){
                startScan()
            } else if(WatchDevice.connectedDevice!.name == "nil"){ //this is another version of not having a connected device
                startScan();
            }
            
        }
                // if we're looking for any BLE peripherals to show
        else if (BLEConnectionController.CBCentralState == .SCANNING_FOR_MIMICS_TO_DISPLAY)
        {
            print("We are looking for mimic devices to display on the Choose Mimic Device To Display screen");
            print(peripherals);
            
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_NEW_PERIPHERALS), object: nil);
            
            startScan();
            
        }
        else if (BLEConnectionController.CBCentralState == .SCANNING_FOR_MIMICS_TO_CONNECT)
        {
            if (peripherals.count > 0)
            {
                for i in 0...(peripherals.count - 1)
                {
                        // if the peripheral's on the mimic list
                    if (WatchDevice.connectedDevice!.mimicList.contains(peripherals[i].identifier as NSUUID))
                    {
                            // connect to it (it's added to the "connected mimic devices" list in the callback)
                        centralManager.connect(peripherals[i], options: nil);
                    }
                }
            }
            
            startScan();
        }
        
    }
    
    //MARK: txCharacteristic commands
    
    //Getting limits of the primary device, which is the first thing we get from the device
    func getPrimaryLimits(){
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
        WatchDevice.connectedDevice?.requestedLimits = true;
    }
    
    //Getting brightness of the primary device, which we may have to do more than just in the setup phase
    func getPrimaryBrightness(){
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS);
        WatchDevice.connectedDevice?.requestedBrightness = true;
    }
    
    //Setting the brightness to a new value
    func changeBrightness(newBrightness: Double)
    {
        print("Sending new Brightness value: \(newBrightness)");
        WatchDevice.connectedDevice?.lastSentBrightness = Int(newBrightness);
        WatchDevice.connectedDevice?.brightness = Int(newBrightness);  //Setting the current brightness here before we get the success response because we will double check in the brightness tick once the slider has stopped moving and replace this value with what the hardware actually says its brightness is.  Setting it here helps the UI not stutter
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInts: [Int(newBrightness)], digitsPerInput: 3, sendToMimicDevices: true)
        WatchDevice.connectedDevice?.requestedBrightnessChange = true
        
    }
    
    func changeCrossfade(newCrossfade: Double){
        print("Sending new Crossfade value: \(newCrossfade)");
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_CROSSFADE, inputInts: [Int(newCrossfade)], digitsPerInput: 3, sendToMimicDevices: true)
        WatchDevice.connectedDevice?.crossfade = Int(newCrossfade)
        WatchDevice.connectedDevice?.requestedCrossfadeChange = true
    }
    
    //Depending on whether the primary device is a demo or a real device, we set a variety of boolean flags in the main WatchDevice
    func setupPrimaryDevice(){
        if (WatchDevice.connectedDevice!.isDemoDevice)
        {
                // since it's a demo device, we have to fake getBattery and getBrightness, and skip all of those "get" steps
            WatchDevice.connectedDevice?.batteryPercentage = 100;
            WatchDevice.connectedDevice?.brightness = Constants.DEFAULT_BRIGHTNESS;
            WatchDevice.connectedDevice?.crossfade = Constants.DEFAULT_CROSSFADE;
            
            WatchDevice.connectedDevice?.readyToShowModes = true;
        }
        else
        {
            print("resetting flags")
            // reset the flags, so we get all items
            WatchDevice.connectedDevice!.expectedPacketType = "";
            
            WatchDevice.connectedDevice?.requestedLimits = false;
            WatchDevice.connectedDevice?.requestedName = false;
            WatchDevice.connectedDevice?.requestedBrightnessChange = false;
            WatchDevice.connectedDevice?.requestedMode = false;
            WatchDevice.connectedDevice?.requestedBrightness = false;
            WatchDevice.connectedDevice?.requestedCrossfade = false;
            WatchDevice.connectedDevice?.supportsCrossfade = false;
            WatchDevice.connectedDevice?.checkedCrossfade = false;
            WatchDevice.connectedDevice?.modeNames = [String]()
            WatchDevice.connectedDevice?.loadingStatus = "Loading"
            
            // we always want to do some setup, but if we already have modes / thumbnails it should be quick
            WatchDevice.connectedDevice?.readyToShowModes = false;
        }
        
        //Once we've setup everything, start requesting data
        requestNextData()
    }
    
    //Recursive-ish function for getting data from the device based on which flags are set in the main WatchDevice
    func requestNextData(){
        print("checking what we need still")
        if (((WatchDevice.connectedDevice?.currentModeIndex)! < 0) || !(WatchDevice.connectedDevice?.requestedLimits)!)
        {
                // if we haven't already, getLimits for this device, so that we'll know it when we change it on the settings screen
            print("requesting limits")
            getPrimaryLimits()
            WatchDevice.connectedDevice?.loadingStatus = "Getting Limits"
            
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
            return;
        }
            // MARK: Hardware Version
        else if (((WatchDevice.connectedDevice?.hardwareVersion)! == .UNKNOWN))
        {
            // if we haven't already, get the hardware version for this device
            if (!(WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_VERSION)))
            {
                print("requesting version")
                formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_VERSION);
                WatchDevice.connectedDevice?.requestedVersion = true;
                WatchDevice.connectedDevice?.loadingStatus = "Getting Version"
                
            }
            // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
            return;
        }
        else if (((WatchDevice.connectedDevice?.brightness)! < 0) || !(WatchDevice.connectedDevice?.requestedBrightness)!)
        {
            // if we haven't already, getBrightness for this device, so that we'll know it for the slider
            if (!(WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS)))
            {
                print("requesting brightness")
                getPrimaryBrightness()
                WatchDevice.connectedDevice?.loadingStatus = "Getting Brightness"
                
            }
            // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
            return;
        }
        else if (!(WatchDevice.connectedDevice?.requestedCrossfade)!){
            
            // if we haven't already, get crossfade for this device, so that we'll know it for the slider
            if (!(WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE))){
                print("requesting crossfade")
                formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE)
                WatchDevice.connectedDevice?.requestedCrossfade = true;
                WatchDevice.connectedDevice?.loadingStatus = "Getting Crossfade"
                
            }
            return;
        }
        else if ((WatchDevice.connectedDevice?.modeNames.count)! < (WatchDevice.connectedDevice?.maxNumModes)!) {
            //Getting mode names so we can display them on the control page
            if (!(WatchDevice.connectedDevice?.requestedName)!){
                print("Getting name for mode: \((WatchDevice.connectedDevice?.modeNames.count)!)")
                formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_NAME, inputInts: [(WatchDevice.connectedDevice?.modeNames.count)! + 1])
                WatchDevice.connectedDevice?.requestedName = true;
                WatchDevice.connectedDevice?.loadingStatus = "Getting Mode \((WatchDevice.connectedDevice?.modeNames.count)! + 1) of \((WatchDevice.connectedDevice?.maxNumModes)!)"
                
            }
            return;
        }
        print("We didn't need anything")
        NotificationCenter.default.post(name: Notification.Name(Constants.MESSAGES.WATCH_READY_TO_SHOW), object: nil)
    }
    
    //Starts the request next data function but with a delay depending on the hardware version
    @objc func requestNextDataWithDelay()
    {

            // resetting the timeout timer so it doesn't count the delay time
        BLETimeoutTimer.invalidate();
        print("Stopping timer as we request next data")
        
        if (WatchDevice.connectedDevice!.hardwareVersion == .NRF8001)
        {
            //If we're using 8001 hardware, we need to add a small delay before triggering the next request
            delayTimer.invalidate();
            delayTimer = Timer.scheduledTimer(withTimeInterval: Constants.NRF8001_DELAY_TIME, repeats: false)
            { timer in
                self.requestNextData();
            }
        }
        else
        {
            print("requesting next data");
            requestNextData();
        }
    }
    
    //Helper function for setting the new primary mode
    func setPrimaryMode(newModeIndex:Int){
        print("Setting mode to: \(newModeIndex)")
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_MODE, inputInts: [newModeIndex], sendToMimicDevices: true)
    }
    
    // Gets called when our bluetooth timeout timer has fired, usually means we requested something with no response, so we don't want to get hung up at this state, since the user will just see a loading screen
    @objc func bleMessageTimeout()
    {
        print("Got ble timeout on: \(WatchDevice.connectedDevice!.expectedPacketType)")
        WatchDevice.reportWatchError(Constants.TIMEOUT_BEFORE_RECEIVING_COMPLETE_MESSAGE);
        
        //If we got hung up on limits and still need it, reset it's flag so requestNextData requests it
        if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS)){
            WatchDevice.connectedDevice!.requestedLimits = false
            WatchDevice.connectedDevice!.expectedPacketType = "";
            print("Got hung up on limits, trying again")
        }
        
        //If we got hung up on version and still need it, reset it's flag so requestNextData requests it
        if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_VERSION)){
            WatchDevice.connectedDevice!.requestedVersion = false
            WatchDevice.connectedDevice!.expectedPacketType = "";
            print("Got hung up on version, trying again")
        }
        
        //If we got hung up on version and still need it, reset it's flag so requestNextData requests it
        if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS)){
            WatchDevice.connectedDevice!.requestedBrightness = false
            WatchDevice.connectedDevice!.expectedPacketType = "";
            print("Got hung up on brightness, trying again")
        }
        
        //If the device is still connected, request the next data, otherwise we can't ask for more data
        if (WatchDevice.connectedDevice!.isConnected) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
        } else {
            print("Since the device is disconnected, we won't ask it for anything anymore");
        }
    }
    
    //Stops timeout timer
    @objc func stopBLERxTimeoutTimer()
    {
        BLETimeoutTimer.invalidate();
    }
    
    //Restarts timeout timer
    @objc func restartBLERxTimeoutTimer()
    {
            // setting timeout timer
        BLETimeoutTimer.invalidate();
        var timeoutTime = 0.0;
        //Depending on what hardware version we have, change the timeout time
        if (WatchDevice.connectedDevice!.hardwareVersion == .NRF51822)
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_NRF51822;
        }
        else if (WatchDevice.connectedDevice!.hardwareVersion == .FASTNRF51822)
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_FASTNRF51822;
        }
        else
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_NRF8001;
        }
        print("setting ble timeout timer")
        //Set timer
        BLETimeoutTimer = Timer.scheduledTimer(timeInterval: timeoutTime, target: self, selector: #selector(bleMessageTimeout) , userInfo: nil, repeats: false);

    }
    
    // sends commands to the hardware, using the protocol as the inputString (and an optional few ints at the end, for certain commands)
private func formatAndSendPacket(_ inputString: String, inputInts: [Int] = [Int](), digitsPerInput: Int = 2, sendToMimicDevices: Bool = false, toSingleDevice: WatchDevice? = nil)
{
    print(" ");
    print(" ");
    print("About to send BLE command \(inputString) with arguments \(inputInts)")
    
    //If we aren't connected, we can't send any data
    if (!(WatchDevice.connectedDevice?.isConnected)!)
    {
        print("Device is not connected");
        return;
    }
    if (WatchDevice.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
    {
        print("Disconnected");
            // stop the setup process, if active
        timer.invalidate()
        //TODO: error popup on UI side
        return;
    }
    
        // formatting data
    let outputData = WatchDevice.formatPacket(inputString, inputInts: inputInts, digitsPerInput: digitsPerInput)
    
        // if we're getting the modes, and if we've asked for this same info too many times, stop
    
//    if (WatchDevice.connectedDevice!.lastFewMessages.count >= Constants.NUM_ALLOWED_RETRIES_PER_PACKET && !WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.maxNumModes > 0)
//    {
//        var hasTriedPacketTooManyTimes = true;
//        for oldData in WatchDevice.connectedDevice!.lastFewMessages
//        {
//                // if we asked for a different packet in the last few packets, we're fine to ask for this one
//            if (oldData != outputData[0])
//            {
//                hasTriedPacketTooManyTimes = false;
//            }
//        }
//            // don't send the packet again if we already have a bunch of times without response
//        if (hasTriedPacketTooManyTimes)
//        {
//            WatchDevice.reportWatchError(Constants.REQUESTED_DATA_WITH_NO_RESPONSE_TOO_MANY_TIMES);
//            return;
//        }
//    }
    
    
        // if we're getting data from hardware, we want look for timeouts
    if (!WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.brightness < 0)
    {
        restartBLERxTimeoutTimer();
    }
    
    BLEConnectionController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: sendToMimicDevices, settingMode: inputString.elementsEqual(EnlightedBLEProtocol.ENL_BLE_SET_MODE), toSingleDevice: toSingleDevice);
    
        // filling up "last few messages"
    if (!WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.maxNumModes > 0)
    {
            // if we have a full history, remove the last item
        if (WatchDevice.connectedDevice!.lastFewMessages.count >= Constants.NUM_ALLOWED_RETRIES_PER_PACKET)
        {
            WatchDevice.connectedDevice!.lastFewMessages.remove(at: 0);
        }
        WatchDevice.connectedDevice!.lastFewMessages.append(outputData[0]);
        
    }
    
}

    
    //MARK: Parsing rxCharacteristic
    
        /* called automatically after characteristics we've subscribed to are updated AKA a callback when our connected device sends us information
         - Taken from BLEConnectionTableViewController
        */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
            // parsing/dealing with the info read from the firmware of the primary
        if characteristic == WatchDevice.connectedDevice?.rxCharacteristic
        {
            
                // if there's an error, it shouldn't keep going
            if let e = error
            {
                WatchDevice.reportWatchError(Constants.CALLBACK_ERROR_FROM_DID_UPDATE_VALUE_FOR_RX, additionalInfo: e.localizedDescription);
                
                    // if we're currently loading the modes, we should try again
//                if (!WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.maxNumModes > 0)
//                {
//                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
//                }
                return;
            }
            
            if (characteristic.value!.count < 1)
            {
                //print("Empty characteristic value returned")
                WatchDevice.reportWatchError(Constants.RECEIVED_EMPTY_RX_CHARACTERISTIC_VALUE);
                return;
            }
            
            var receivedArray: [UInt8] = [];
            
            var rxValue = [UInt8](characteristic.value!);
            
            receivedArray = Array(characteristic.value!);
            
                // converting data to a string
            var rxString = String(bytes: receivedArray, encoding: .ascii);
            
                //converting first byte into an int, for the 1 or 0 success responses
            let rxInt = Int(receivedArray[0]);
            
            // TODO: enable this for debugging; removing for performance
            //print("Received \(receivedArray) from \(String(describing: peripheral.name))");
            
            
            
            
                // if we have received more of an incomplete response, add it to what we already have
            if ((incompletePacketReceived) && currentPacketType != "")
            {
                currentPacketContents += rxValue;
            }
            else
            {
                //Check what type of packet we're receiving based on what we're expecting
                currentPacketType = "";
                currentPacketContents = rxValue;
                    // Get Thumbnail
                if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL))
                {
                    //print("Receiving a Thumbnail")
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL;
                }
                else if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_TOTAL_THUMBNAIL))
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_TOTAL_THUMBNAIL;
                }
                else if (WatchDevice.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_PALETTE))
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_PALETTE
                    print("expecting a palette");
                }
                    // Get Battery
                else if (rxString?.prefix(1) == "B")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL;
                }
                    // Get Limits
                else if (rxString?.prefix(1) == "L")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_LIMITS;
                }
                    // Get Mode
                else if (rxString?.prefix(1) == "M")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_MODE;
                }
                    // Get Name
                else if (rxString?.prefix(1) == "\"")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_NAME;
                }
                    // Get Brightness
                else if (rxString?.prefix(1) == "G")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS;
                }
                   // Get Crossfade
                else if (rxString?.prefix(1) == "X")
                {
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE;
                }
                    // Get Version
                else if (rxString?.prefix(1) == "V")
                {
                    //print("Receiving a hardware version")
                    currentPacketType = EnlightedBLEProtocol.ENL_BLE_GET_VERSION;
                }
                else if (rxInt == 1)
                {
                    print("Receiving a success response");
                    currentPacketType = "Success";
                }
                else if (rxInt == 0)
                {
                    print("Receiving a failure response");
                    currentPacketType = "Failure";
                }
                else
                {
                    print("Unable to parse response")
                    return
                }
                
                
            }
            
            if (currentPacketType != "")
            {
                    // evaluating based on packet type whether the packet is complete
                let completePacket = Constants.PACKET_REQUIREMENTS[currentPacketType]!(currentPacketContents);
                //print("Received complete packet? \(completePacket)")
                    // if we didn't receive a complete packet, we want to return and wait for the next part of it
                incompletePacketReceived = !completePacket;
                if (!completePacket)
                {
                        // MARK: profiling: receiving incomplete message
                    if (WatchDevice.profiling && WatchDevice.currentlyProfiling)
                    {
                            // 'type' is 1, an incomplete message
                        let duration = (Date().timeIntervalSince(WatchDevice.profilerStopwatch) - WatchDevice.lastTimestamp) * 1000;
                        WatchDevice.lastTimestamp = Date().timeIntervalSince(WatchDevice.profilerStopwatch);
                        let commandString = "rx: \(currentPacketType) (partial)";
                        let newLine = "\(commandString),\(Date().timeIntervalSince(WatchDevice.profilerStopwatch)),\(1),\(duration),\n";
                        let newRxLine = "\(commandString),\(duration),\n";
                        WatchDevice.mainCsvText.append(contentsOf: newLine);
                        WatchDevice.rxCsvText.append(contentsOf: newRxLine);
                    }
                    
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RESTART_BLE_RX_TIMEOUT_TIMER), object: nil);
                    print(currentPacketContents);
                    print("incomplete message: waiting for rest of message")
                    
                    return;
                }
                else
                {
                    
                        // MARK: profiling: receiving complete message
                    if (WatchDevice.profiling && WatchDevice.currentlyProfiling)
                    {
                            // 'type' is 2, a complete message
                        let duration = (Date().timeIntervalSince(WatchDevice.profilerStopwatch) - WatchDevice.lastTimestamp) * 1000;
                        let completeMessageDuration = (Date().timeIntervalSince(WatchDevice.profilerStopwatch) - WatchDevice.lastTxTimestamp) * 1000;
                        WatchDevice.lastTimestamp = Date().timeIntervalSince(WatchDevice.profilerStopwatch);
                        let commandString = "rx: \(currentPacketType) (complete)";
                        let newLine = "\(commandString),\(Date().timeIntervalSince(WatchDevice.profilerStopwatch)),\(2),\(duration),\(completeMessageDuration)\n";
                        let newRxLine = "\(commandString),\(duration),\(completeMessageDuration)\n";
                        WatchDevice.mainCsvText.append(contentsOf: newLine);
                        WatchDevice.rxCsvText.append(contentsOf: newRxLine);
                    }
                    
                        // resetting BLE Rx timeout timer
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.STOP_BLE_RX_TIMEOUT_TIMER), object: nil);

                    
                    let diff = Date().timeIntervalSince(packetStopwatch);
                    print("Received complete packet in \(diff) seconds")
                }
            }
            else
            {
                //print("Unable to identify received packet")
                WatchDevice.reportWatchError(Constants.UNABLE_TO_PARSE_PACKET, additionalInfo: "Received \(receivedArray) from \(String(describing: peripheral.name))");
                incompletePacketReceived = false;
                currentPacketType = "";
                currentPacketContents = [UInt8]();
                return;
            }
            
                // checking to make sure we were expecting this type of packet
            if (!(currentPacketType == WatchDevice.connectedDevice!.expectedPacketType) && !(WatchDevice.connectedDevice!.expectedPacketType.elementsEqual("Success") && currentPacketType.elementsEqual("Failure")) && !currentPacketType.elementsEqual("Success"))
            {
                WatchDevice.reportWatchError(Constants.UNEXPECTED_PACKET_TYPE, additionalInfo: "Received a packet of type \(currentPacketType), but expected a packet of type \(WatchDevice.connectedDevice!.expectedPacketType)");
                //print("");
                //print("Received a packet we didn't expect: ");
                //print("received a packet of type \(currentPacketType), but expected a packet of type \(Device.connectedDevice!.expectedPacketType)");
                //print("");
                currentPacketContents = [UInt8]();
                currentPacketType = "";
                WatchDevice.connectedDevice!.expectedPacketType = "";
                
                WatchDevice.connectedDevice!.requestWithoutResponse = false;
                    // if we already have limits but are reading modes/bitmaps/etc from hardware, we want to go back to that loop when we parse a packet
                if (!WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.maxNumModes > 0)
                {
                    //print("Finished parsing packet, going back to loop")
                    
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
                        // FIX-ME: trying to see what went wrong on the nRF8001
                        // if it's the nRF8001, we need to introduce a bit of delay, otherwise, do this instantly
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
                }
                
                return;
            }
            else
            {
                // stopping "active request" flag, because a response has been received
                if ((WatchDevice.connectedDevice?.requestWithoutResponse)!)
                {
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.STOP_BLE_RX_TIMEOUT_TIMER), object: nil);

                    WatchDevice.connectedDevice?.requestWithoutResponse = false;
                    //print("packet matches requested packet, allowing next packet");
                }
                
            }
            WatchDevice.connectedDevice!.expectedPacketType = "";
            
            rxValue = currentPacketContents;
            rxString = String(bytes: currentPacketContents, encoding: .ascii);
            
                // MARK: Parsing Complete Packets:
            switch currentPacketType
            {
                // MARK: Get Battery Level
            case EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL:
                
                // conversion from https://stackoverflow.com/questions/32830866/how-in-swift-to-convert-int16-to-two-uint8-bytes
                let ADCValue = Int16(rxValue[1]) << 8 | Int16(rxValue[2]);
                
                //print("Received a complete battery level packet, parsing: " + rxString!.prefix(1), Int(ADCValue));
                //print("Value Recieved: " + ;
                let voltage = (Float(ADCValue) / 1024) * 16.5;
                // calculates the battery percentage given the voltage
                WatchDevice.connectedDevice?.batteryPercentage = calculateBatteryPercentage(voltage);
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BATTERY_VALUE), object: nil);
                
                // MARK: Get Limits
            case EnlightedBLEProtocol.ENL_BLE_GET_LIMITS:
                
                print("Received a complete limits packet, parsing: " + rxString!.prefix(1), Int(rxValue[1]), Int(rxValue[2]), Int(rxValue[3]));
                //print(Int(rxValue[1]));
                WatchDevice.connectedDevice?.currentModeIndex = Int(rxValue[1]);
                WatchDevice.connectedDevice?.maxNumModes = Int(rxValue[2]);
                WatchDevice.connectedDevice?.maxBitmaps = Int(rxValue[3]);
                
                print("Current Mode Index: ",(WatchDevice.connectedDevice?.currentModeIndex ?? "no mode index found"))
                
                // making sure that the current mode isn't above the max (which can sometimes happen in a sort of "demo" mode)
                if ((WatchDevice.connectedDevice?.currentModeIndex)! > (WatchDevice.connectedDevice?.maxNumModes)!)
                {
                    // if it is, default to mode 1 on the app
                    WatchDevice.connectedDevice?.currentModeIndex = 1;
                    print("Defaulting to mode 1")
                }
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_LIMITS_VALUE), object: nil);
                
                // MARK: Get Mode
            case EnlightedBLEProtocol.ENL_BLE_GET_MODE:
                
                // the first byte after "M" determines whether it's a bitmap or color mode
                let usesBitmap = (rxValue[1] == 0);
                let usesPalette = (rxValue[1] == 2);
                
                let currentIndex = (WatchDevice.connectedDevice?.modes.count)! + 1;
                
                if (currentIndex <= (WatchDevice.connectedDevice?.maxNumModes)!)
                {
                    // if it's a bitmap mode, we should create one and add it to the Device's list
                    if (usesBitmap)
                    {
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2]);
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        // clamping to min/max
                        let bitmapIndex = min(max(Int(rxValue[2]), 1), (WatchDevice.connectedDevice?.maxBitmaps)!);
                        WatchDevice.connectedDevice?.modes += [Mode(name: parsedName, index: currentIndex, usesPalette: usesPalette, usesBitmap: usesBitmap, bitmapIndex: bitmapIndex, colors: [nil])!];
                    }
                    else if (usesPalette)
                    {
                        //if it's a palette mode, we need to make a mode without any color data so that we can later populate the palette and add the index to the emptyPalettes array so that we know where to put the palettes that we ask for later
                        WatchDevice.connectedDevice?.modes += [Mode(name: parsedName, index: currentIndex, usesPalette: usesPalette, usesBitmap: usesBitmap, bitmapIndex: nil, colors: [nil])!];
                        WatchDevice.connectedDevice?.emptyPalettes += [currentIndex];
                        print("found a palette mode - adding to emptyPalettes");
                    }
                    else
                    {
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        
                        let color1 = UIColor(displayP3Red: CGFloat(Float(rxValue[2]) / 255), green: CGFloat(Float(rxValue[3]) / 255), blue: CGFloat(Float(rxValue[4]) / 255), alpha: 1)
                        let color2 = UIColor(displayP3Red: CGFloat(Float(rxValue[5]) / 255), green: CGFloat(Float(rxValue[6]) / 255), blue: CGFloat(Float(rxValue[7]) / 255), alpha: 1)
                        WatchDevice.connectedDevice?.modes += [Mode(name: parsedName, index: currentIndex, usesPalette: usesPalette, usesBitmap: usesBitmap, bitmapIndex: nil, colors: [color1, color2])!];
                        
                    }
                }
                // if we're currently reverting the mode
                else if ((WatchDevice.connectedDevice?.currentlyRevertingMode)!)
                {
                    //print("Recieved a mode we want to use for reversion");
                    
                    WatchDevice.connectedDevice?.mode?.usesBitmap = usesBitmap;
                    
                    if (usesBitmap)
                    {
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2]);
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        // clamping to min/max
                        let bitmapIndex = min(max(Int(rxValue[2]), 1), (WatchDevice.connectedDevice?.maxBitmaps)!);
                        WatchDevice.connectedDevice?.mode?.bitmapIndex = bitmapIndex;
                    }
                    else
                    {
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        
                        let color1 = UIColor(displayP3Red: CGFloat(Float(rxValue[2]) / 255), green: CGFloat(Float(rxValue[3]) / 255), blue: CGFloat(Float(rxValue[4]) / 255), alpha: 1)
                        let color2 = UIColor(displayP3Red: CGFloat(Float(rxValue[5]) / 255), green: CGFloat(Float(rxValue[6]) / 255), blue: CGFloat(Float(rxValue[7]) / 255), alpha: 1)
                        WatchDevice.connectedDevice?.mode?.color1 = color1;
                        WatchDevice.connectedDevice?.mode?.color2 = color2;
                        
                    }
                    WatchDevice.connectedDevice?.currentlyRevertingMode = false;
                    print("No longer looking for modes for reversion, ready to send message to EditScreenViewController");
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_MODE_VALUE), object: nil);
                }
                
                //Device.connectedDevice!.expectedPacketType = "";
                //Device.connectedDevice?.requestedName = false;
                //Device.connectedDevice?.requestedMode = false;
                
                // MARK: Get Name
            case EnlightedBLEProtocol.ENL_BLE_GET_NAME:
                
                //print("Received a complete name packet: " + rxString!);
                // if the end quote is in this string, the whole name was sent in one packet (which should always happen, as it's only parsing complete packets
                if (rxString!.suffix(1) == "\"")
                {
                    let receivedName = rxString!;
                    // taking off quotes
                    parsedName = receivedName.filter { $0 != "\"" }
                    WatchDevice.connectedDevice?.modeNames.append(parsedName) //Add the name to the list of mode names
                    if WatchDevice.connectedDevice?.modeNames.count == WatchDevice.connectedDevice?.maxNumModes{
                        //Reset the loadingStatus when we receive the last the last mode name so it doesn't show up as 33 of 34 when you reconnect
                        WatchDevice.connectedDevice?.loadingStatus = "Loading"
                    }
                    WatchDevice.connectedDevice?.requestedName = false;
                    WatchDevice.connectedDevice?.receivedName = true;
                    
                }
                
                // MARK: Get Thumbnail
            case EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL:
                
                //print("Received a complete thumbnail row, parsing")
                bitmapPixelRow = [Pixel]();
                for i in 0...19
                {
                    let indexOffset = i * 3;
                    bitmapPixelRow.append(Pixel(r: currentPacketContents[0 + indexOffset], g: currentPacketContents[1 + indexOffset], b: currentPacketContents[2 + indexOffset], a: UInt8(255)));
                }
                
                // if we just finished a row of 20 pixels, we can go on to the next one
                if (bitmapPixelRow.count == 20)
                {
                    // if this command was interrupted, we need to make sure it ends, but we don't want it to leave a remnant in the pixel array
                    if ((WatchDevice.connectedDevice?.currentlyBuildingThumbnails)!)
                    {
                        // adding this row to the whole thing
                        bitmapPixels += bitmapPixelRow;
                        // resetting row
                        bitmapPixelRow = [Pixel]();
                        WatchDevice.connectedDevice?.thumbnailRowIndex += 1;
                    }
                    // if we get a pixel row at the wrong time, we want to make sure the pixel array is empty for when we really want thumbnails
                    else
                    {
                        // reset the whole thumbnail
                        bitmapPixels = [Pixel]();
                        // reset the row counter
                        WatchDevice.connectedDevice?.thumbnailRowIndex = 0;
                        // reset the individual row
                        bitmapPixelRow = [Pixel]();
                        
                    }
                    
                    //Device.connectedDevice!.expectedPacketType = "";
                    //Device.connectedDevice?.requestedThumbnail = false;
                }
                // if the 20x20 grid is finished, turn it into a UIImage and go on to the next one
                if (bitmapPixels.count >= 400)
                {
                    //print("Finished bitmap");
                    // Generate a new UIImage (20x20 is hardcoded)
                    guard let newThumbnail = UIImageFromBitmap(pixels: bitmapPixels, width: 20) else
                    {
                        print("Was unable to generate UIImage thumbnail");
                        return;
                    }
                    // add it to the Device
                    WatchDevice.connectedDevice?.thumbnails.append(newThumbnail);
                    // clear the Pixel array
                    bitmapPixels = [Pixel]();
                    // reset the row counter
                    WatchDevice.connectedDevice?.thumbnailRowIndex = 0;
                }
                //MARK: Get Total Thumbnail
            case EnlightedBLEProtocol.ENL_BLE_GET_TOTAL_THUMBNAIL:
                print("PARSING GTT");
                
                
                //print("Received a complete thumbnail row, parsing")
                bitmapPixelRow = [Pixel]();
                //for j in 0...19
                //{
                    //let rowOffset = j * 20;
                    for i in 0...399
                    {
                        let indexOffset = i * 3;
                        bitmapPixelRow.append(Pixel(r: currentPacketContents[0 + indexOffset], g: currentPacketContents[1 + indexOffset], b: currentPacketContents[2 + indexOffset], a: UInt8(255)));
                        if(bitmapPixelRow.count == 20){
                            if ((WatchDevice.connectedDevice?.currentlyBuildingThumbnails)!)
                            {
                                // adding this row to the whole thing
                                bitmapPixels += bitmapPixelRow;
                                // resetting row
                                bitmapPixelRow = [Pixel]();
                            }
                            // if we get a pixel row at the wrong time, we want to make sure the pixel array is empty for when we really want thumbnails
                            else
                            {
                                // reset the whole thumbnail
                                bitmapPixels = [Pixel]();
                                // reset the individual row
                                bitmapPixelRow = [Pixel]();
                                
                            }
                        }
                    }
                    
                // if the 20x20 grid is finished, turn it into a UIImage and go on to the next one
                if (bitmapPixels.count >= 400)
                {
                    //print("Finished bitmap");
                    // Generate a new UIImage (20x20 is hardcoded)
                    guard let newThumbnail = UIImageFromBitmap(pixels: bitmapPixels, width: 20) else
                    {
                        print("Was unable to generate UIImage thumbnail");
                        return;
                    }
                    // add it to the Device
                    WatchDevice.connectedDevice?.thumbnails.append(newThumbnail);
                    // clear the Pixel array
                    bitmapPixels = [Pixel]();
                    // reset the row counter
                    WatchDevice.connectedDevice?.thumbnailRowIndex = 0;
                }
            
                
                    // MARK: Get Brightness
            case EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS:
                
                print("Received a complete brightness level packet, parsing: " + rxString!.prefix(1), Int(rxValue[1]));
                WatchDevice.connectedDevice?.brightness = Int(rxValue[1]);
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BRIGHTNESS_VALUE), object: nil);
                
                // MARK: Get Crossfade
            case EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE:
                print("Got Crossfade Value: ", Int(rxValue[1]));
          
                // if we got a response here, that means our hardware supports crossfading -> lets set the value and flip the boolean so that we know that in the future
                WatchDevice.connectedDevice?.crossfade = Int(rxValue[1]);
                WatchDevice.connectedDevice?.supportsCrossfade = true;
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECIEVED_CROSSFADE_VALUE), object: nil);
                
                // MARK: Get Palette
            case EnlightedBLEProtocol.ENL_BLE_GET_PALETTE:
                print("incoming palette");
                //print(currentPacketContents);
                var rawPalette = currentPacketContents;
                
                var currentPalette: [UIColor] = [UIColor]();
                
                // remove all the "P#" ascii values from the bytes that we got back so that we can treat the rest as rgb values - going backwards so that we don't mess up any of the important indexes later in the array
                for i in (0...55).reversed()
                {
                    if (i % 14 == 0 || i % 14 == 1)
                    {
                        rawPalette.remove(at: i);
                    }
                }
                
                print("Palette after pruning 'P_' values: \n", rawPalette);
                
                // once we've pruned out all the ascii values, we can parse the rest of the rgb values and create UIColor objects to pass into the setPalette function
                for i in 0...15
                {
                    let indexOffset = i * 3;
                    print("Current Color: ", rawPalette[0 + indexOffset], rawPalette[1 + indexOffset], rawPalette[2 + indexOffset]);
                    currentPalette.append(UIColor(red: CGFloat(Double(rawPalette[0 + indexOffset])/255.0), green: CGFloat(Double(rawPalette[1 + indexOffset])/255.0), blue: CGFloat(Double(rawPalette[2 + indexOffset])/255.0), alpha: CGFloat(1.0)));
                }
                
                // set the palette in the corresponding mode and then remove the mode from the list of modes that still need palette information so that we don't ask for the same one infinitely
                WatchDevice.connectedDevice?.modes[(WatchDevice.connectedDevice?.emptyPalettes[0])! - 1].setPalette(palette: currentPalette);
                WatchDevice.connectedDevice?.emptyPalettes.remove(at:0);
                
                    // MARK: Get Version
            case EnlightedBLEProtocol.ENL_BLE_GET_VERSION:
                
                //print("Received a hardware version packet: " + rxString!.prefix(2));
                //(rxString!.prefix(2).suffix(1);
                
                //Checking if we have access to the faster version of the nRF51822 firmware
                if(rxString!.suffix(1) == "3")
                {
                    WatchDevice.connectedDevice?.hardwareVersion = .FASTNRF51822;
                    print("FIRMWARE VERSION: 3");
                }
                //otherwise just set it to the normal nRF51822
                else if(rxString!.suffix(1) == "2")
                {
                    WatchDevice.connectedDevice?.hardwareVersion = .NRF51822;
                    print("FIRMWARE VERSION 2");
                }
                    // MARK: Success Response
            case "Success":
                
                print("Command succeeded.");
                
                    // we need to know if a "change mode" was just done, so that we can apply user settings
                if ((WatchDevice.connectedDevice?.requestedModeChange)!)
                {
                    print("Since the command to set the mode succeeded, we are going to change the mode settings now.")
                    WatchDevice.connectedDevice?.requestedModeChange = false;
                    let identifier = [0: peripheral.identifier as NSUUID];
                    var waitingForMimics: Bool = false;
                    for mimic in (WatchDevice.connectedDevice?.connectedMimicDevices)!
                    {
                        if mimic.requestedModeChange
                        {
                            waitingForMimics = true;
                            break;
                        }
                    }
                    // we only want to send this message to the notificationCenter if we are done waiting for all mimics to receive their success messages, otherwise the last mimic to receive will do it for us
                    if !(waitingForMimics)
                    {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_MODE_VALUE), object: nil, userInfo: identifier);
                    }
                }
                
                    // we need to know when the first color was changed so we can change the second (as of 1.0.33, both protocols change color in 1 packet)
//                else if ((Device.connectedDevice!.requestedFirstOfTwoColorsChanged))
//                {
//                    print("Since the command to set the first color succeeded, we are going to set the second one now.")
//                    Device.connectedDevice?.requestedFirstOfTwoColorsChanged = false;
//                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_FIRST_COLOR), object: nil);
//
//                }
                        // if there's an unsent "set mode" message
                else if (WatchDevice.connectedDevice!.lastUnsentMessage.count > 0)
                {
                    print("Since there's an unsent 'Set Mode' request, we are going to send that now.");
                    BLEConnectionController.sendBLEPacketToConnectedPeripherals( valueData: WatchDevice.connectedDevice!.lastUnsentMessage, sendToMimicDevices: true, settingMode: true)
                }
                
                    // we need to know if the standby was set, in order to do other things in the setup loop
                if ((WatchDevice.connectedDevice?.requestedStandbyActivated)!)
                {
                    WatchDevice.connectedDevice?.requestedStandbyActivated = false;
                    WatchDevice.connectedDevice?.isInStandby = true;
                }
                else if ((WatchDevice.connectedDevice?.requestedStandbyDeactivated)!)
                {
                    WatchDevice.connectedDevice?.requestedStandbyDeactivated = false;
                    WatchDevice.connectedDevice?.isInStandby = false;
                }
                
                
                    // and likewise for the standby brightness change
                if ((WatchDevice.connectedDevice?.requestedBrightnessChange)!)
                {
                        // if the stored brightness isn't its default value (i.e. something's been stored because we're in standby mode and so have set it to something else)
                    if (WatchDevice.connectedDevice?.storedBrightness != -1)
                    {
                        print("Standby brightness activated.")
                            // set the flag that we're in that standby mode
                        WatchDevice.connectedDevice?.dimmedBrightnessForStandby = true;
                    }
                        // otherwise
                    else
                    {
                        print("Standby brightness deactivated.")
                            // set the flag that we aren't in that mode
                        WatchDevice.connectedDevice?.dimmedBrightnessForStandby = false;
                    }
                    print("Successfully set brightness")
                    WatchDevice.connectedDevice?.checkedLastBrightnessChange = false;
                    WatchDevice.connectedDevice?.requestedBrightnessChange = false;
                }
                
                if ((WatchDevice.connectedDevice?.requestedCrossfadeChange)!){
                    WatchDevice.connectedDevice?.requestedCrossfadeChange = false
                }
                
                    // MARK: Failure Response
            case "Failure":
                
                print("Command failed.");
                
                WatchDevice.reportWatchError(Constants.RECEIVED_FAILURE_RESPONSE);
                WatchDevice.connectedDevice!.requestWithoutResponse = false;
                WatchDevice.connectedDevice!.expectedPacketType = "";
                if ((WatchDevice.connectedDevice?.requestedBrightnessChange)!){
                    print("Failed to set brightness, retrying now")
                    changeBrightness(newBrightness: Double(WatchDevice.connectedDevice!.lastSentBrightness))
                }
                    // MARK: Unidentifiable Packet
            default:
                
                //print("unable to parse response, might be unimplemented");
                if (rxString == nil)
                {
                    WatchDevice.reportWatchError(Constants.UNABLE_TO_PARSE_PACKET, additionalInfo: "Recieved \(rxValue)");
                }
                else
                {
                    WatchDevice.reportWatchError(Constants.UNABLE_TO_PARSE_PACKET, additionalInfo: "String recieved: " + (rxString ?? "ERROR"));
                }
            }
            
                // resetting these, since we're done with their contents and we're ready for a new packet/packet type
            currentPacketContents = [UInt8]();
            currentPacketType = "";
            
                // if we already have limits but are reading modes/bitmaps/etc from hardware, we want to go back to that loop when we parse a packet
            if (!WatchDevice.connectedDevice!.readyToShowModes && WatchDevice.connectedDevice!.maxNumModes > 0)
            {
                //print("Finished parsing packet, going back to loop")
                
                //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
                    // FIX-ME: trying to see what went wrong on the nRF8001
                    // if it's the nRF8001, we need to introduce a bit of delay, otherwise, do this instantly
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
            }
            if ((WatchDevice.connectedDevice?.requestedBrightnessChange)!){
                print("Failed to set brightness, retrying now")
                changeBrightness(newBrightness: Double(WatchDevice.connectedDevice!.lastSentBrightness))
            }
        }
            // receiving from other characteristics, most likely the mimic devices' rxCharacteristics (the only thing we expect here is the hardware version)
        else
        {
                // MARK: Mimic Device rx parsing
            if let e = error
            {
                //print("ERROR didUpdateValueFor \(e.localizedDescription)");
                WatchDevice.reportWatchError(Constants.CALLBACK_ERROR_FROM_DID_UPDATE_VALUE_FOR_RX, additionalInfo: e.localizedDescription);
                
                return;
            }
            
            if (characteristic.value!.count < 1)
            {
                //print("Empty characteristic value returned")
                //Device.reportError(Constants.RECEIVED_EMPTY_RX_CHARACTERISTIC_VALUE);
                return;
            }
            
            var receivedArray: [UInt8] = [];
            
            var rxValue = [UInt8](characteristic.value!);
            
            receivedArray = Array(characteristic.value!);
            
                // converting data to a string
            var rxString = String(bytes: receivedArray, encoding: .ascii);
            
            let rxInt = Int(receivedArray[0]);
            
                // if we get a "V" back, we're getting a version response
            if (rxString?.prefix(1).lowercased().elementsEqual("v") ?? false)
            {
                for mimicDevice in WatchDevice.connectedDevice!.connectedMimicDevices
                {
                    if mimicDevice.peripheral.identifier as NSUUID == peripheral.identifier as NSUUID
                    {
                        mimicDevice.hardwareVersion = .NRF51822;
                    }
                }
            }
                // if we got the success response
            else if (rxInt == 1)
            {
                print("Received a success response from a mimic!");
                for mimicDevice in WatchDevice.connectedDevice!.connectedMimicDevices
                {
                    if mimicDevice.peripheral.identifier as NSUUID == peripheral.identifier as NSUUID
                    {
                        if (mimicDevice.requestedModeChange)
                        {
                            print("Since the command to set the mode on \(mimicDevice.name) succeeded, we are going to change the mode settings now.")
                            mimicDevice.requestedModeChange = false;
                            let identifier = [0: peripheral.identifier as NSUUID];
                            // make sure we aren't waiting for the primary peripheral before sending this message
                            if !((WatchDevice.connectedDevice?.requestWithoutResponse)!)
                            {
                                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_MODE_VALUE), object: nil, userInfo: identifier);
                            }
                        }
                    }
                }
                    
            }
            
                // print the value and source
            print(" \(String(describing: rxString))) received from \(String(describing: peripheral.name))");
        }
    }
    
    
        // listening for a response after we write to txCharacteristic, though this should never happen, since we use the withoutResponse write type
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else
        {
            //print("Error receiving reponse: \(error!.localizedDescription)")
            WatchDevice.reportWatchError(Constants.BAD_RESPONSE_TO_WRITE_WITH_RESPONSE, additionalInfo: error!.localizedDescription);
            return
        }
        print("Message sent")
    }
    
        // connecting to the peripheral of the connected device in Device
    func connectToPrimaryDevice()
    {
        centralManager.connect(WatchDevice.connectedDevice!.peripheral, options: nil);
        WatchDeviceTimeoutTimer.invalidate()
        //TODO: Indicate connecting
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
            // print info about the connected peripheral
        print ("*******************************************************");
        print("Connection complete");
        print("Peripheral info: \(peripheral) ");
        
            // set connected flag on device object, if we're connecting to the primary
        if (peripheral.identifier as NSUUID == WatchDevice.connectedDevice?.peripheral.identifier as! NSUUID)
        {
            // changing state to reflect the central's newly connected status
            if (BLEConnectionController.CBCentralState == .UNCONNECTED_SCANNING_FOR_PRIMARY)
            {
                BLEConnectionController.CBCentralState = .CONNECTED_SCANNING_FOR_PRIMARY;
                print(BLEConnectionController.CBCentralState);
            }
            
            WatchDevice.connectedDevice?.isConnected = true;
            WatchDevice.connectedDevice?.isConnecting = false;
            
            
            // once we've connected, we can rescan again TODO: Deal with this in UI
            //searchButton.isEnabled = true;
        }
        else
        {
            var newDevice = WatchDevice(mimicDevicePeripheral: peripheral);
                // setting the UUID
            newDevice.UUID = newDevice.peripheral.identifier as NSUUID;
            
            WatchDevice.connectedDevice?.connectedMimicDevices += [newDevice];
            
            updateMimicDevicesAndCentralState();
        }
        
            // erase data we might have
        data.length = 0;
        
        
        
        
            // Discovery callback
        peripheral.delegate = self;
            // Only look for services that match the transmit UUID
        peripheral.discoverServices([BLEService_UUID]);
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    {
        //print("Failed to connect to peripheral, \()");
        WatchDevice.reportWatchError(Constants.FAILED_TO_CONNECT_TO_PERIPHERAL, additionalInfo: error?.localizedDescription ?? "");
        
        //TODO: Indicate the failure to connect in the UI and reload the list of devices
        print("Couldn't connect")
        // starting the scan again
        startScan();
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        guard (peripheral.identifier as NSUUID != WatchDevice.connectedDevice?.UUID) else
        {
            WatchDevice.connectedDevice!.isConnected = false;
            WatchDevice.connectedDevice!.requestWithoutResponse = false;
            BLEConnectionController.CBCentralState = .UNCONNECTED_SCANNING_FOR_PRIMARY;
            print(BLEConnectionController.CBCentralState);
            
            //print("We disconnected from our connected primary peripheral.");
            //print("\(error?.localizedDescription ?? "unknown error")");
            WatchDevice.reportWatchError(Constants.DISCONNECTED_FROM_PRIMARY_PERIPHERAL_UNEXPECTEDLY, additionalInfo: error?.localizedDescription ?? "unknown error");
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.DISCONNECTED_FROM_WATCH_DEVICE), object: nil)
            
            // TODO: error popup, deselect/disconnect device, start scanning again
            return;
        }
        
        print("Disconnected from " + peripheral.name!);
        print("\(error?.localizedDescription ?? "unknown error")");
        WatchDevice.reportWatchError(Constants.DISCONNECTED_FROM_MIMIC_PERIPHERAL_UNEXPECTEDLY, additionalInfo: "Disconnected from \(peripheral.name!); \(error?.localizedDescription ?? "unknown error")");
        
            // if it's not the primary, it still might be one of the mimic devices
        if (WatchDevice.connectedDevice!.connectedMimicDevices.count > 0)
        {
            for i in 0...(WatchDevice.connectedDevice!.connectedMimicDevices.count - 1)
            {
                // and so we have to remove it from the list
                
                print("index \(i) of: \(WatchDevice.connectedDevice!.connectedMimicDevices)")
                
                if (WatchDevice.connectedDevice!.connectedMimicDevices[i].peripheral.identifier as NSUUID == peripheral.identifier as NSUUID)
                {
                    print("removing \(String(describing: peripheral.name)) at index \(i) from the list \(WatchDevice.connectedDevice!.connectedMimicDevices)")
                    
                    WatchDevice.connectedDevice!.connectedMimicDevices.remove(at: i);
                    
                    updateMimicDevicesAndCentralState();
                    return;
                }
                
            }
        }
        
        
        
        
        
        
    }
    
        // handling the discovery of services of a peripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        print("*******************************************************");
        
        if ((error) != nil)
        {
            //print("Error discovering services: \(error!.localizedDescription)");
            WatchDevice.reportWatchError(Constants.FAILED_TO_DISCOVER_SERVICES, additionalInfo: error!.localizedDescription);
            return;
        }
        
        guard let services = peripheral.services else
        {
            return;
        }
        
            // We need to get all characteristics
        for service in services
        {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
        print("Discovered services: \(services)");
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
        print("*******************************************************");
        
        if ((error) != nil)
        {
            //print("Error discovering characteristics: \(error!.localizedDescription)");
            WatchDevice.reportWatchError(Constants.FAILED_TO_DISCOVER_CHARACTERISTICS, additionalInfo: error!.localizedDescription);
            return;
        }
        
        guard let characteristics = service.characteristics else
        {
            return;
        }
        
        print("Found \(characteristics.count) characteristics!");
        
        if (peripheral.identifier as NSUUID == WatchDevice.connectedDevice!.peripheral.identifier as NSUUID)
        {
        
            for characteristic in characteristics
            {
                    // looks for the read characteristic
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)
                {
                    rxCharacteristic = characteristic;
                        // set a reference to this characteristic in the device
                    WatchDevice.connectedDevice!.setRXCharacteristic(characteristic);
                    
                        // once found, subscribe to this particular characteristic
                    peripheral.setNotifyValue(true, for: rxCharacteristic!)
                    
                    peripheral.readValue(for: characteristic);
                    print("Rx Characteristic of primary \(String(describing: WatchDevice.connectedDevice?.name)): \(characteristic.uuid)");
                }
                
                    // looks for the transmission characteristic
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
                {
                    txCharacteristic = characteristic;
                        // set a reference to this characteristic in the device
                    WatchDevice.connectedDevice!.setTXCharacteristic(characteristic);
                    print("Tx Characteristic of primary \(String(describing: WatchDevice.connectedDevice?.name)): \(characteristic.uuid)");
                    
                    // set flag
                    WatchDevice.connectedDevice?.hasDiscoveredCharacteristics = true;
                    // notify connection button that it can be enabled
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_PRIMARY_CHARACTERISTICS), object: nil);
                }
                
                    // looks for the battery level characteristic (Never called, because we don't look for the battery service
    //            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_batteryValue)
    //            {
    //                batteryCharacteristic = characteristic;
    //
    //                    // once found, subscribe to this characteristic to update the battery level
    //                peripheral.setNotifyValue(true, for: batteryCharacteristic!);
    //
    //                peripheral.readValue(for: characteristic);
    //                print("Battery characteristic: \(characteristic.uuid)");
    //            }
                
                peripheral.discoverDescriptors(for: characteristic);
            }
        }
        else
        {
            
            var mimicDevice: WatchDevice?;
            
            for characteristic in characteristics
            {
                peripheral.discoverDescriptors(for: characteristic);
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
                {
                    //txCharacteristic = characteristic;
                    
                    for device in WatchDevice.connectedDevice!.connectedMimicDevices
                    {
                        if device.peripheral.identifier as NSUUID == peripheral.identifier as NSUUID
                        {
                            mimicDevice = device;
                        }
                    }
                    
                    if (mimicDevice != nil)
                    {
                        // set a reference to this characteristic in the device
                        mimicDevice?.setTXCharacteristic(characteristic);
                        mimicDevice?.hasDiscoveredCharacteristics = true;
                        print("Tx Characteristic of mimic device \(String(describing: mimicDevice?.name)): \(characteristic.uuid)");
                            // getting the mimic device's hardware version
                        getHardwareVersionForMimicDevice(peripheral.identifier as NSUUID);
                    }
                    
                }
                
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)
                {
                    //rxCharacteristic = characteristic;
                    // set a reference to this characteristic in the device
                    //Device.connectedDevice!.setRXCharacteristic(characteristic);
                    
                    // once found, subscribe to this particular characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    
                    peripheral.readValue(for: characteristic);
                    //print("Rx Characteristic of mimic device \(mimicDevice?.name): \(characteristic.uuid)");
                }
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil
        {
            //print("\(error.debugDescription)")
            WatchDevice.reportWatchError(Constants.FAILED_TO_DISCOVER_CHARACTERISTIC_DESCRIPTORS, additionalInfo: error!.localizedDescription);
            return
        }
        if ((characteristic.descriptors) != nil) {
            
            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor?
                print("function name: DidDiscoverDescriptorForChar \(String(describing: descript?.description))")
                print("Rx Value \(String(describing: rxCharacteristic?.value))")
                print("Tx Value \(String(describing: txCharacteristic?.value))")
            }
        }
        
        //Connect message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            NotificationCenter.default.post(name: Notification.Name(Constants.MESSAGES.CONNECTED_TO_WATCH_DEVICE), object: nil)
        })
    }
    
        // console updates for notification state for a given service, taken from Bluefruit's "simple chat app".
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    {
        print("*******************************************************")
        
        if (error != nil)
        {
            //print("Error changing notification state:\(String(describing: error?.localizedDescription))");
            WatchDevice.reportWatchError(Constants.FAILED_TO_UPDATE_CHARACTERISTIC_NOTIFICATION_STATE, additionalInfo: error!.localizedDescription);
        }
        else
        {
            print("Characteristic's value subscribed");
        }
        
        if (characteristic.isNotifying)
        {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)");
        }
    }
    
        // reading the RSSI value of the connected peripheral (if any)
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?)
    {
        if (error != nil)
        {
            //print("Error reading RSSI of connected peripheral:\(String(describing: error?.localizedDescription))");
            WatchDevice.reportWatchError(Constants.FAILED_TO_READ_RSSI, additionalInfo: error!.localizedDescription);
        }
        else
        {
                // updating the Device object's RSSI value, which is communicated to visibleDevices[] in cancelScan().
            WatchDevice.connectedDevice?.RSSI = RSSI.intValue;
        }
    }
    
    func disconnectFromPrimaryDevice()
    {
            // Disconnect from real device
        if WatchDevice.connectedDevice?.peripheral != nil
        {
            centralManager?.cancelPeripheralConnection(WatchDevice.connectedDevice!.peripheral);
            WatchDevice.connectedDevice!.isConnected = false;
            WatchDevice.connectedDevice!.hasDiscoveredCharacteristics = false;
            //Device.connectedDevice? = Device(true);
                // setting the connectedDevice to the "emptyDevice" placeholder
            
            BLEConnectionController.CBCentralState = .UNCONNECTED_SCANNING_FOR_PRIMARY;
            print(BLEConnectionController.CBCentralState);
        }
                // if it's a demo device, it also has to be "disconnected"
        else if (WatchDevice.connectedDevice?.isDemoDevice ?? false)
        {
            WatchDevice.connectedDevice!.isConnected = false;
            WatchDevice.connectedDevice!.hasDiscoveredCharacteristics = false;
            //Device.connectedDevice? = Device(true);
        }
        //Pass the false parameter into the demoDevice constructor so we know it's an actual placeholder and not an intentional demo
        WatchDevice.connectedDevice? = WatchDevice(false);
        
        //Begin scanning again
        startScan()
    }
    
    func disconnectAllDevices()
    {
        disconnectFromPrimaryDevice();
        
            // all the currently connected peripherals
        let peripheralsToDisconnectFrom = centralManager.retrieveConnectedPeripherals(withServices: [BLEService_UUID]);
        
            // if there are still some left over, we need to disconnect from them
        if (peripheralsToDisconnectFrom.count > 0)
        {
            for i in 0...peripheralsToDisconnectFrom.count - 1
            {
                centralManager.cancelPeripheralConnection(peripheralsToDisconnectFrom[i]);
            }
        }
    }
    
    // MARK: - Public Methods
    
        // takes two data objects in an array, the first for the nRF8001 and the second for the nRF51822, and if the "settingMode" is specified, it can "store" a mode to set later
    static func sendBLEPacketToConnectedPeripherals( valueData: [NSData], sendToMimicDevices: Bool, settingMode: Bool = false, toSingleDevice: WatchDevice? = nil)
    {
        if (WatchDevice.connectedDevice!.isDemoDevice)
        {
            print("Not sending BLE packets to a demo device");
            return;
        }
            // if we're still waiting on a response, don't send a new message
        if ((toSingleDevice == nil || toSingleDevice == WatchDevice.connectedDevice!) && WatchDevice.connectedDevice!.requestWithoutResponse)
        {
            print("Still waiting on a response");
                // TODO: vibrate if command failed
            
                // converting data to a string
            let failedPacketString = String(data: valueData[1] as Data, encoding: .ascii);
            WatchDevice.reportWatchError(Constants.COULD_NOT_TX_BLE_BECAUSE_WAITING_FOR_RESPONSE, additionalInfo: "Unable to send packet \(failedPacketString ?? "(inconvertible)") because the app was already waiting for a response to a different packet.  ");
            if (settingMode && !(toSingleDevice != nil))
            {
                WatchDevice.connectedDevice!.lastUnsentMessage = valueData;
            }
            return;
        }
        
            // if toSingleDevice is specified, only send to that specific peripheral
        if (toSingleDevice != nil)
        {
            print(" ");
            print("*********************************************************************");
            print(" ");
            print("     Sending \(valueData) to specific peripheral");
            print(" ");
            if (settingMode)
            {
                toSingleDevice!.requestedModeChange = true;
            }
            if (toSingleDevice!.hardwareVersion == .UNKNOWN || toSingleDevice!.hardwareVersion == .NRF8001)
            {
                    // since the "Get Version" command is the same for both protocols, we can use the nRF8001 version (valueData[0]) blind
                toSingleDevice!.peripheral.writeValue(valueData[0] as Data, for: toSingleDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
            }
            else if (toSingleDevice!.hardwareVersion == .NRF51822 || toSingleDevice!.hardwareVersion == .FASTNRF51822)
            {
                //MARK: Testing checking for peripheral availability before sending
                toSingleDevice!.peripheral.writeValue(valueData[1] as Data, for: toSingleDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
            }
            
            return;
        }
        
            // TODO: useful debug messages, disable for performance (?)
        print(" ");
        print("*********************************************************************");
        print(" ");
        print("     Sending \(valueData) to primary peripheral");
        print(" ");
        
        if (settingMode)
        {
            WatchDevice.connectedDevice?.requestedModeChange = true;
        }
        
            // setting stopwatch
        packetStopwatch = Date();
        
        
        if WatchDevice.connectedDevice!.hasDiscoveredCharacteristics
        {
            
                // send differently-formatted data packets depending on hardware type
            if (WatchDevice.connectedDevice!.hardwareVersion == .NRF51822 || WatchDevice.connectedDevice!.hardwareVersion == .FASTNRF51822)
            {
                print("Sending to NRF51822", valueData[1]);
                WatchDevice.connectedDevice!.peripheral.writeValue(valueData[1] as Data, for: WatchDevice.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            }
            else
            {
                print("Sending to NRF8001");
                WatchDevice.connectedDevice!.peripheral.writeValue(valueData[0] as Data, for: WatchDevice.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            }
            
            print("waiting for response");
            WatchDevice.connectedDevice!.requestWithoutResponse = true;
            WatchDevice.connectedDevice!.lastUnsentMessage = [NSData]();
        }
        else
        {
            WatchDevice.reportWatchError(Constants.ATTEMPTED_TO_SEND_PACKET_WITHOUT_DISCOVERING_CHARACTERISTIC, additionalInfo: "The primary has not yet discovered the txCharacteristic, not sending packet");
            //print("The primary has not yet discovered the txCharacteristic, not sending packet");
        }
        
        // if there are mimic devices connected, and this command should be sent to them
        if (WatchDevice.connectedDevice!.connectedMimicDevices.count > 0 && sendToMimicDevices)
        {
            for i in 0...WatchDevice.connectedDevice!.connectedMimicDevices.count - 1
            {
                if (WatchDevice.connectedDevice!.connectedMimicDevices[i].hasDiscoveredCharacteristics)
                {
                    if (settingMode)
                    {
                        WatchDevice.connectedDevice!.connectedMimicDevices[i].requestedModeChange = true;
                    }
                    if (WatchDevice.connectedDevice!.connectedMimicDevices[i].hardwareVersion == .NRF51822)
                    {
                        print("sending \(valueData[1]) to nRF51822 mimic peripheral #\(i + 1) ");
                        WatchDevice.connectedDevice!.connectedMimicDevices[i].peripheral.writeValue(valueData[1] as Data, for: WatchDevice.connectedDevice!.connectedMimicDevices[i].txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
                    }
                    else if (WatchDevice.connectedDevice!.connectedMimicDevices[i].hardwareVersion == .NRF8001)
                    {
                        print("sending \(valueData[0]) to nRF8001 mimic peripheral #\(i + 1) ");
                        WatchDevice.connectedDevice!.connectedMimicDevices[i].peripheral.writeValue(valueData[0] as Data, for: WatchDevice.connectedDevice!.connectedMimicDevices[i].txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
                    }
                    else
                    {
                        print("Have not yet discovered what hardware this mimic device is running, not sending packets yet");
                    }
                    
                    
                }
                else
                {
                    WatchDevice.reportWatchError(Constants.ATTEMPTED_TO_SEND_PACKET_WITHOUT_DISCOVERING_CHARACTERISTIC, additionalInfo: "The mimic device \(WatchDevice.connectedDevice!.connectedMimicDevices[i].name) has not yet discovered the txCharacteristic, not sending packet");
                    //print("The mimic device \(Device.connectedDevice!.connectedMimicDevices[i].name) has not yet discovered the txCharacteristic, not sending packet");
                }
            }
        }
        
        
    }
    
    @objc func updateMimicDevicesAndCentralState()
    {
        print("–––––––––––––––––––Updating mimic device list and central state–––––––––––––––––––––");
        
        var mimicDevices = WatchDevice.connectedDevice!.connectedMimicDevices
        var mimicDevicesToDisconnectFrom = [WatchDevice]();
        
        if (mimicDevices.count > 0)
        {
        
                // check to see what mimic devices are connected to but aren't on the list
            for i in 0...(mimicDevices.count - 1)
            {
                // if we can't find this device in the mimic list
                if !(WatchDevice.connectedDevice?.mimicList.contains(mimicDevices[i].peripheral.identifier as NSUUID))!
                {
                    mimicDevicesToDisconnectFrom += [mimicDevices[i]];
                }
            }
            
            if (mimicDevicesToDisconnectFrom.count > 0)
            {
                // disconnect from the excess mimic devices
                for i in 0...(mimicDevicesToDisconnectFrom.count - 1)
                {
                    // disconnect from the peripheral
                    centralManager?.cancelPeripheralConnection(mimicDevicesToDisconnectFrom[i].peripheral);
                    // remove it from the list of connected mimic peripherals
                    WatchDevice.connectedDevice!.connectedMimicDevices.remove(at: WatchDevice.connectedDevice!.connectedMimicDevices.firstIndex(of: mimicDevicesToDisconnectFrom[i])!);
                }
            }
            
            
        }
        
        if (WatchDevice.connectedDevice!.mimicList.count > 0)
        {
                // if we aren't connected to each device on the mimic list, we need to work on doing so
            if (WatchDevice.connectedDevice!.mimicList.count > WatchDevice.connectedDevice!.connectedMimicDevices.count)
            {
                BLEConnectionController.CBCentralState = .SCANNING_FOR_MIMICS_TO_CONNECT;
                print(BLEConnectionController.CBCentralState);
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil);
            }
                // otherwise we're good and don't need to scan
            else
            {
                BLEConnectionController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
                print(BLEConnectionController.CBCentralState);
            }
        }
        else
        {
            BLEConnectionController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
            print(BLEConnectionController.CBCentralState);
        }
        
    }
    
    // MARK: - Private Methods
    
    //TODO: Error popup in UI and email enlighted
    
        // if we receive a timeout error after requesting a thumbnail row, we have to
    @objc private func resetThumbnailRow()
    {
        print("Timed out, clearing row");
            // clear the half-baked row
        bitmapPixelRow = [Pixel]();
        //thumbnailRow = [UInt8]();
        incompletePacketReceived = false;
        currentPacketType = "";
        currentPacketContents = [UInt8]();
            // tell the ModeTableViewController setup loop to get the thumbnails again
        WatchDevice.connectedDevice?.expectedPacketType = "";
        WatchDevice.connectedDevice!.requestWithoutResponse = false;
        
        if (WatchDevice.connectedDevice!.isConnected)
        {
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
        }
        else
        {
            print("Since the device is disconnected, we won't ask it for anything anymore");
        }
    }
    
    func getHardwareVersionForMimicDevice( _ id: NSUUID)
    {
        for mimicDevice in WatchDevice.connectedDevice!.connectedMimicDevices
        {
            if mimicDevice.peripheral.identifier as NSUUID == id
            {
                mimicDevice.setGetMimicVersionTimer();
                BLEConnectionController.sendBLEPacketToConnectedPeripherals(valueData: WatchDevice.formatPacket(EnlightedBLEProtocol.ENL_BLE_GET_VERSION), sendToMimicDevices: false, toSingleDevice: mimicDevice)
                
            }
        }
    }
    
    
        // credit to https://stackoverflow.com/questions/30958427/pixel-array-to-uiimage-in-swift
    private func UIImageFromBitmap(pixels: [Pixel], width: Int) -> UIImage?
    {
        guard (width > 0) else
        {
            WatchDevice.reportWatchError(Constants.ATTEMPTED_TO_CREATE_THUMBNAIL_WITH_ZERO_WIDTH);
            //print("Insufficient width");
            return nil;
        }
        guard (pixels.count % width == 0) else
        {
            WatchDevice.reportWatchError(Constants.BITMAP_PIXELS_ARE_NOT_EVENLY_DIVISIBLE_BY_WIDTH);
            //print("Pixel count isn't evenly divisible by the width");
            return nil;
        }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB();
            //"Alpha" value is the last in structure
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue);
        let bitsPerComponent = 8;
        let bitsPerPixel = 32;
        
            // copy to mutable []
        var data = pixels;
        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * MemoryLayout<Pixel>.size)) else
        {
            WatchDevice.reportWatchError(Constants.UNABLE_TO_CREATE_DATAPROVIDER_FOR_THUMBNAIL);
            print("Unable to create dataprovider");
            return nil;
        }
        
            // creating a CGImage
        guard let image = CGImage(
            width: width,
            height: pixels.count / width,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * MemoryLayout<Pixel>.size,
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: false, // I think this is anti-aliasing, which we don't want
            intent: .defaultIntent
        )
        else
        {
            WatchDevice.reportWatchError(Constants.UNABLE_TO_CREATE_THUMBNAIL_CGIMAGE_FROM_BITMAP_PIXELS);
            print("Unable to create CGImage");
            return nil;
        }
        
            // getting a UIImage from that CGImage
        let uiImage = UIImage(cgImage: image);
        
            // for creating the demo mode, save that image to camera roll (to be sent to computer, credit to https://stackoverflow.com/a/11131077 ):
        //UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil);
        
        return uiImage;
    }
    
    private func createSampleDeviceWithName(_ name: String) -> Mode
    {
        let bitmap2 = UIImage(named: "Bitmap2");
        
            // adding a blank mode with just the correct name (hopefully)
        return Mode(name: name, index: -1, usesPalette: false, usesBitmap: true, bitmap: bitmap2, colors: [nil])!;
        
    }
            
    private func calculateBatteryPercentage(_ voltage: Float) -> Int
    {
        //print("received voltage of \(voltage)");
        // key representing voltage thresholds for battery percentages (index 0 is 0%, 1 is 5%, 2 is 10%, etc).  From Development Details document.
        let batteryCapacityKey: [Float] = [0, 6.98, 8.71, 9.17, 9.37, 9.51, 9.63, 9.72, 9.79, 9.84, 9.88, 9.91, 9.93, 9.95, 9.96, 9.97, 9.98, 10, 10.09, 10.38, 10.91];
        
        var index: Int = 20;
        // going through the key
        for _ in 0...20
        {
            
                // if the voltage is ever greater than or equal to a key value, than the corresponding percentage is returned
            if (voltage >= batteryCapacityKey[index])
            {
                print("calculated a percentage of \(index * 5)");
                return index * 5;
            }
            
            index = index - 1;
        }
        
        return -1
        
    }
    
        // loads stored Devices from storage, so that we can circumvent having to load
    static func loadDevices() -> [WatchDevice]?
    {
        return NSKeyedUnarchiver.unarchiveObject(withFile: WatchDevice.ArchiveURL.path) as? [WatchDevice];
    }
    
}

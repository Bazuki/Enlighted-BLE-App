//
//  BLEConnectionTableViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation

var txCharacteristic : CBCharacteristic?;
var rxCharacteristic : CBCharacteristic?;
var batteryCharacteristic : CBCharacteristic?;

var blePeripheral: CBPeripheral?;
    // temporary place to display read Characteristic strings, before parsing
var rxCharacteristicValue = String();//NSData();


class BLEConnectionTableViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate
{
        // MARK: Properties
    
        // The devices that show up on the connection screen.
    var visibleDevices = [Device]();
    
        // the devices we have stored in memory, which we will recognize by name
    var cachedDevices = [Device]();
    
        // The bluetooth CentralManager object controlling the connection to peripherals
    var centralManager : CBCentralManager!;
        // A timer object to help in searching
    var timer = Timer();
    var scanTimer = Timer();
    
    var scanTimeInterval: Double = 20;
    
        // list of peripherals, and their associated RSSI values
    var peripherals: [CBPeripheral] = [];
        // want to get "real" names from advertising data
    var peripheralNames = [String]();
    var RSSIs = [NSNumber]();
    var data = NSMutableData();
    
        // variables to help in parsing names
    //var currentlyParsingName = false;
    var parsedName: String = "";
    
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
    
    @IBOutlet weak var deviceTableView: UITableView!
    
        // MARK: - UIViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        centralManager = CBCentralManager(delegate:self, queue: nil);
        
        NotificationCenter.default.addObserver(self, selector: #selector(resetThumbnailRow), name: Notification.Name(rawValue: "resendRow"), object: nil)
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        
            // Disconnect detection should work even when the viewcontroller is not shown (From Bluefruit code)
//        didDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: didDisconnectFromPeripheral)
        
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
            // load cached devices
        cachedDevices = loadDevices() ?? [Device]();
        
        //centralManager = CBCentralManager(delegate:self, queue: nil);
        
            // if we're currently connected to a device as we enter this screen, disconnect (because we'll be choosing a new one)
        disconnectFromDevice();
        
            // we want to clear the visibleDevices() array now that we have cached memory
        visibleDevices = [Device]();
        
            // shorter scan on entry so that devices will be culled quickly
        startScan(0.2);
    }
    
        // start scan on appearance of viewController
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated);
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
        // MARK: - Bluetooth
    
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        if central.state == CBManagerState.poweredOn
        {
            print("Bluetooth Enabled")
            startScan(0.5);
            
            // should scan multiple times
            
            //scanTimer = Timer.scheduledTimer(timeInterval: scanTimeInterval, target: self, selector: #selector(startScan), userInfo: nil, repeats: true);// startScan();
        }
        else
        {
            print("Bluetooth disabled, make sure your device is turned on");
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertControllerStyle.alert);
            let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil);
            })
            alertVC.addAction(action);
            self.present(alertVC, animated: true, completion: nil);
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
        self.peripherals.append(peripheral);
        self.peripheralNames.append(advertisementData[CBAdvertisementDataLocalNameKey] as! String);
        self.RSSIs.append(RSSI);
        
            // handled in cancelScan()
//        if let devicesIndex = self.visibleDevices.firstIndex(where: { (device: Device) -> Bool in
//            return device.peripheral == peripheral;
//            })
//        {
//            print("Found this peripheral at index \(devicesIndex), updating RSSI");
//            self.visibleDevices[devicesIndex].RSSI = RSSI.intValue;
//        }
//            // otherwise, add it to the list
//        else if !(self.visibleDevices.contains(where: { $0.peripheral == peripheral }))
//        {
//            print("Didn't find this peripheral, adding it to the list (visibleDevices is \(visibleDevices.count) items long");
//            self.visibleDevices.append(Device(name: peripheral.name!, RSSI: RSSI.intValue, peripheral: peripheral));
//        }
        
        
        
        peripheral.delegate = self;
            // discovering Bluefruit GATT services (shouldn't be done here, this is for connected devices)
        //peripheral.discoverServices([BLEService_UUID]);
            // discovering BLE services related to battery
        //peripheral.discoverServices([BLEBatteryService_UUID]);
            // reloading table view data
        deviceTableView.reloadData();
        if blePeripheral == nil
        {
            print("We found a new peripheral device with services");
            print("Peripheral name: \(peripheral.name ?? "no name")");
            print("*****************************");
            print("Advertisement data: \(advertisementData)");
            blePeripheral = peripheral;
        }
    }
    
        // starting to scan for peripherals that have Bluefruit's unique GATT indicator
    @objc func startScan(_ scanTime: Double)
    {
            // don't scan if we can't
        if (centralManager.state != CBManagerState.poweredOn)
        {
            print("Bluetooth isn't available right now, make sure it's activated on your phone");
            return;
        }
            // clearing the visibleDevices list when we're scanning again
        //visibleDevices = [Device]();
        peripherals = [CBPeripheral]();
        RSSIs = [NSNumber]();
        
        print("Now scanning...");
        self.timer.invalidate();
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: scanTime, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false);
    }
    
        // cancelling the scan for peripherals
    @objc func cancelScan()
    {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
        
        // if we aren't connected to a device, keep trying
        if (Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
        {
                // going through devices
            if (visibleDevices.count > 0)
            {
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
                    else if !peripherals.contains(visibleDevices[deviceIndex].peripheral)
                    {
                        print("Removing device named \(visibleDevices[deviceIndex].name)");
                        visibleDevices.remove(at: deviceIndex);
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
                            visibleDevices.append(Device(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i]));
                        }
                    }
                    else
                    {
                        // otherwise create a brand-new device
                        visibleDevices.append(Device(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i]));
                    }
                }
            }
            // if the device hasn't connected, keep scanning
            startScan(Constants.SCAN_DURATION);
        }
        
        if (Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
        {
                // reload table
            deviceTableView.reloadData();
        }
        
    }
    
    //MARK: Parsing rxCharacteristic
    
        // called automatically after characteristics we've subscribed to are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
            // parsing/dealing with the info read from the firmware
        if characteristic == rxCharacteristic
        {
            
                // if there's an error, it shouldn't keep going
            if let e = error
            {
                print("ERROR didUpdateValueFor \(e.localizedDescription)");
                return;
            }
            
            
            var receivedArray: [UInt8] = [];
            
            let rxValue = [UInt8](characteristic.value!);
            
            receivedArray = Array(characteristic.value!);
            
                // converting data to a string
            let rxString = String(bytes: receivedArray, encoding: .ascii);
            
                //converting first byte into an int, for the 1 or 0 success responses
            let rxInt = Int(receivedArray[0]);
            
            
            print("received \(receivedArray)");
            
            
                // stopping "active request" flag, because a response has been received
            if ((Device.connectedDevice?.requestWithoutResponse)!)
            {
                Device.connectedDevice?.requestWithoutResponse = false;
            }
            
                // check for the end of a name first, because the first letter could be "L" or "M", etc.
            if ((Device.connectedDevice?.currentlyParsingName)!)
            {
                if (rxString?.suffix(1) == "\"")
                {
                    
                    Device.connectedDevice?.currentlyParsingName = false;
                    parsedName = parsedName + rxString!.filter { $0 != "\"" };
                //Device.connectedDevice?.requestedName = false;
                    
                    print("Received complete name: " + parsedName);
                    Device.connectedDevice?.receivedName = true;
                    return;
                }
                else
                    // if the response after the first half of a name isn't a name, something's wrong, and we should clear everythin
                {
                    print("Caught a name error: \(parsedName)");
                    Device.connectedDevice?.currentlyParsingName = false;
                    parsedName = "";
                }
            }
                
                // if it's a 15-byte value and we've requested the thumbnail, it's probably the thumbnail
            if ((Device.connectedDevice?.requestedThumbnail)! && rxValue.count == 15)
            {
                // debug message, but super slow to print every time
                //print("Value Received: \(rxValue[0], rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7], rxValue[8], rxValue[9], rxValue[10], rxValue[11], rxValue[12], rxValue[13], rxValue[14])");
                
                for i in 0...4
                {
                    let indexOffset = i * 3;
                    bitmapPixelRow.append(Pixel(r: rxValue[0 + indexOffset], g: rxValue[1 + indexOffset], b: rxValue[2 + indexOffset], a: UInt8(255)));
                }
                // debug message, might slow down the program too much
                //print("Thumbnail \((Device.connectedDevice?.thumbnails.count)! + 1) is \(Float(bitmapPixels.count) / 4.0) percent complete");
                // if we just finished a row of 20 pixels, we can go on to the next one
                if (bitmapPixelRow.count == 20)
                {
                    // if this command was interrupted, we need to make sure it ends, but we don't want it to leave a remnant in the pixel array
                    if ((Device.connectedDevice?.currentlyBuildingThumbnails)!)
                    {
                        // adding this row to the whole thing
                        bitmapPixels += bitmapPixelRow;
                        // resetting row
                        bitmapPixelRow = [Pixel]();
                        Device.connectedDevice?.thumbnailRowIndex += 1;
                    }
                        // if we get a pixel row at the wrong time, we want to make sure the pixel array is empty for when we really want thumbnails
                    else
                    {
                            // reset the whole thumbnail
                        bitmapPixels = [Pixel]();
                            // reset the row counter
                        Device.connectedDevice?.thumbnailRowIndex = 0;
                            // reset the individual row
                        bitmapPixelRow = [Pixel]();
                        
                    }
                    
                    Device.connectedDevice?.requestedThumbnail = false;
                }
                // if the 20x20 grid is finished, turn it into a UIImage and go on to the next one
                if (bitmapPixels.count >= 400)
                {
                    print("Finished bitmap");
                    // Generate a new UIImage (20x20 is hardcoded)
                    guard let newThumbnail = UIImageFromBitmap(pixels: bitmapPixels, width: 20) else
                    {
                        print("Was unable to generate UIImage thumbnail");
                        return;
                    }
                    // add it to the Device
                    Device.connectedDevice?.thumbnails.append(newThumbnail);
                    // clear the Pixel array
                    bitmapPixels = [Pixel]();
                    // reset the row counter
                    Device.connectedDevice?.thumbnailRowIndex = 0;
                }
            }
                // if the first letter is "L", we're getting the current mode, lower-, and upper-mode count limits.
            else if (rxString?.prefix(1) == "L") //[(rxString?.startIndex)!] == "L")
            {
                print("Value Recieved: " + rxString!.prefix(1), Int(rxValue[1]), Int(rxValue[2]), Int(rxValue[3]));
                //print(Int(rxValue[1]));
                Device.connectedDevice?.currentModeIndex = Int(rxValue[1]);
                Device.connectedDevice?.maxNumModes = Int(rxValue[2]);
                Device.connectedDevice?.maxBitmaps = Int(rxValue[3]);
                
                NotificationCenter.default.post(name: Notification.Name(rawValue:"gotLimits"), object: nil);
            }
                // if the first letter is "G", we're getting the brightness, on a scale from 0-255;
            else if (rxString?.prefix(1) == "G") //[(rxString?.startIndex)!] == "G")
            {
                print("Value Recieved: " + rxString!.prefix(1), Int(rxValue[1]));
                Device.connectedDevice?.brightness = Int(rxValue[1]);
                NotificationCenter.default.post(name: Notification.Name(rawValue: "gotBrightness"), object: nil);
            }
                // if the first letter is "B", we're getting the battery, which must be manipulated to give percentage
            else if (rxString?.prefix(1) == "B")
            {
                
                    // conversion from https://stackoverflow.com/questions/32830866/how-in-swift-to-convert-int16-to-two-uint8-bytes
                let ADCValue = Int16(rxValue[1]) << 8 | Int16(rxValue[2]);
                print("Value Recieved: " + rxString!.prefix(1), Int(ADCValue));
                let voltage = (Float(ADCValue) / 1024) * 16.5;
                    // calculates the battery percentage given the voltage
                Device.connectedDevice?.batteryPercentage = calculateBatteryPercentage(voltage);
                NotificationCenter.default.post(name: Notification.Name(rawValue: "gotBattery"), object: nil);
            }
                // if the first letter is "M", we're getting details about a mode, and need to add it to the Device.connectedDevice's list
            else if (rxString?.prefix(1) == "M")
            {
                    // the first value after "M" determines whether or not it's a bitmap-type mode
                let usesBitmap = (rxValue[1] == 0);
                
                let currentIndex = (Device.connectedDevice?.modes.count)! + 1;
                
                if (currentIndex <= (Device.connectedDevice?.maxNumModes)!)
                {
                // if it's a bitmap mode, we should create one and add it to the Device's list
                    if (usesBitmap)
                    {
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2]);
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                            // clamping to min/max
                        let bitmapIndex = min(max(Int(rxValue[2]), 1), (Device.connectedDevice?.maxBitmaps)!);
                        Device.connectedDevice?.modes += [Mode(name: parsedName, index: currentIndex, usesBitmap: usesBitmap, bitmapIndex: bitmapIndex, colors: [nil])!];
                    }
                    else
                    {
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        
                        let color1 = UIColor(displayP3Red: CGFloat(Float(rxValue[2]) / 255), green: CGFloat(Float(rxValue[3]) / 255), blue: CGFloat(Float(rxValue[4]) / 255), alpha: 1)
                        let color2 = UIColor(displayP3Red: CGFloat(Float(rxValue[5]) / 255), green: CGFloat(Float(rxValue[6]) / 255), blue: CGFloat(Float(rxValue[7]) / 255), alpha: 1)
                        Device.connectedDevice?.modes += [Mode(name: parsedName, index: currentIndex, usesBitmap: usesBitmap, bitmapIndex: nil, colors: [color1, color2])!];
                        
                    }
                }
                    // if we're currently reverting the mode
                else if ((Device.connectedDevice?.currentlyRevertingMode)!)
                {
                    Device.connectedDevice?.mode?.usesBitmap = usesBitmap;
                    
                    if (usesBitmap)
                    {
                        //print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2]);
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        // clamping to min/max
                        let bitmapIndex = min(max(Int(rxValue[2]), 1), (Device.connectedDevice?.maxBitmaps)!);
                        Device.connectedDevice?.mode?.bitmapIndex = bitmapIndex;
                    }
                    else
                    {
                        print("Value Received: " + rxString!.prefix(1), rxValue[1], rxValue[2], rxValue[3], rxValue[4], rxValue[5], rxValue[6], rxValue[7]);
                        
                        let color1 = UIColor(displayP3Red: CGFloat(Float(rxValue[2]) / 255), green: CGFloat(Float(rxValue[3]) / 255), blue: CGFloat(Float(rxValue[4]) / 255), alpha: 1)
                        let color2 = UIColor(displayP3Red: CGFloat(Float(rxValue[5]) / 255), green: CGFloat(Float(rxValue[6]) / 255), blue: CGFloat(Float(rxValue[7]) / 255), alpha: 1)
                        Device.connectedDevice?.mode?.color1 = color1;
                        Device.connectedDevice?.mode?.color2 = color2;
                        
                    }
                    Device.connectedDevice?.currentlyRevertingMode = false;
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "revertedMode"), object: nil);
                }
                Device.connectedDevice?.requestedName = false;
                Device.connectedDevice?.requestedMode = false;
                
            }
                // if the first character is a " (quote) we're starting to get a name of a mode (unless we're currently parsing a name, in which case it could be that only the final quote was sent in the second packet (and it shouldn't be a new name in that case)
            else if (rxString?.prefix(1) == "\"" && !(Device.connectedDevice?.currentlyParsingName)!)
            {
                print("Receiving name: " + rxString!);
                    // if the end quote is in this string, the whole name was sent in one packet
                if (rxString!.suffix(1) == "\"")
                {
                    let receivedName = rxString!;
                        // taking off quotes
                    parsedName = receivedName.filter { $0 != "\"" }
                    //Device.connectedDevice?.requestedName = false;
                    print("Received complete name: " + parsedName);
                    Device.connectedDevice?.receivedName = true;
                    
                }
                    // otherwise we have to wait for the second half
                else
                {
                    Device.connectedDevice?.currentlyParsingName = true;
                    parsedName = rxString!.filter { $0 != "\"" };
                }
            }
            else if (rxInt == 1)
            {
                print("Command succeeded.");
                
                    // we need to know if a "change mode" was just done, so that we can apply user settings
                if ((Device.connectedDevice?.requestedModeChange)!)
                {
                    Device.connectedDevice?.requestedModeChange = false;
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "changedMode"), object: nil);
                }
                
                    // we need to know if the standby was set, in order to do other things in the setup loop
                if ((Device.connectedDevice?.requestedStandbyActivated)!)
                {
                    Device.connectedDevice?.requestedStandbyActivated = false;
                    Device.connectedDevice?.isInStandby = true;
                }
                else if ((Device.connectedDevice?.requestedStandbyDeactivated)!)
                {
                    Device.connectedDevice?.requestedStandbyDeactivated = false;
                    Device.connectedDevice?.isInStandby = false;
                }
                
                    // and likewise for the standby brightness change
                if ((Device.connectedDevice?.requestedBrightnessChange)!)
                {
                        // if the stored brightness isn't its default value (i.e. something's been stored because we're in standby mode and so have set it to something else)
                    if (Device.connectedDevice?.storedBrightness != -1)
                    {
                            // set the flag that we're in that standby mode
                        Device.connectedDevice?.dimmedBrightnessForStandby = true;
                    }
                        // otherwise
                    else
                    {
                            // set the flag that we aren't in that mode
                        Device.connectedDevice?.dimmedBrightnessForStandby = false;
                    }
                    
                    Device.connectedDevice?.requestedBrightnessChange = false;
                }
            }
            else if (rxInt == 0)
            {
                print("Command failed.");
                    // vibrate if command failed
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
            else
            {
                print("unable to parse response, might be unimplemented");
                if (rxString == nil)
                {
                    print("Recieved \(rxValue)");
                }
                else
                {
                    print("String recieved: " + (rxString ?? "ERROR"));
                }
            }
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
        }
        
        
        
        
//            // updating battery information on device (unused service)
//        if characteristic == batteryCharacteristic
//        {
//                // credit to https://useyourloaf.com/blog/swift-integer-quick-guide/for help with encoding int8
//            let value = characteristic.value;
//            let valueUInt8 = [UInt8](value!);
//            let batteryLevel: Int32 = Int32(bitPattern: UInt32(valueUInt8[0]));
//            Device.connectedDevice?.setBatteryPercentage(percentage: Int(batteryLevel));
//        }
    }
    
        // writing to txCharacteristic
    func writeValue(data: String)
    {
        if (!(Device.connectedDevice?.isConnected)!)
        {
            print("Device is not connected");
            return;
        }
        else if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
        {
            print("Disconnected");
            
            // error popup
            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {(action) -> Void in
                print("Should go to the Connect Screen at this point");
                _ = self.navigationController?.popToRootViewController(animated: true);
            })
            
            dialogMessage.addAction(ok);
            
            self.present(dialogMessage, animated: true, completion: nil);
            // shows the Connection page (hopefully/eventually)
            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
            //self.show(newViewController, sender: self);
        }
        
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue);
            // if the blePeripheral variable is set
        if let blePeripheral = blePeripheral
        {
            // and the txCharacteristic variable is set
            if let txCharacteristic = txCharacteristic
            {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withoutResponse);
            }
        }
    }
    
        // listening for a response after we write to txCharacteristic
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        print("Message sent")
    }
    
        // connecting to the peripheral of the connected device in Device
    func connectToDevice()
    {
        centralManager.connect(Device.connectedDevice!.peripheral, options: nil);
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
            // print info about the connected peripheral
        print ("*******************************************************");
        print("Connection complete");
        print("Peripheral info: \(peripheral) ");
        
            // set connected flag on device object
        
        Device.connectedDevice?.isConnected = true;
        Device.connectedDevice?.isConnecting = false;
        
            
        
            // stop scanning
        centralManager?.stopScan();
        print("Scan stopped");
            // stopping the normal scan timer
        timer.invalidate();
        
            // erase data we might have
        data.length = 0;
        
        
        
        
            // Discovery callback
        peripheral.delegate = self;
            // Only look for services that match the transmit UUID
        peripheral.discoverServices([BLEService_UUID]);
        //peripheral.discoverServices([BLEBatteryService_UUID]);
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        guard (peripheral.identifier as NSUUID != Device.connectedDevice?.UUID) else
        {
            print("This was our connected peripheral");
            
            // error popup
            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {(action) -> Void in
                print("Should go to the Connect Screen at this point");
                _ = self.navigationController?.popToRootViewController(animated: true);
            })
            
            dialogMessage.addAction(ok);
            
            self.present(dialogMessage, animated: true, completion: nil);
            
            return;
        }
        
        print("Disconnected from " + peripheral.name!);
        
        
    }
    
        // handling the discovery of services of a peripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        print("*******************************************************");
        
        if ((error) != nil)
        {
            print("Error discovering services: \(error!.localizedDescription)");
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
            print("Error discovering characteristics: \(error!.localizedDescription)");
            return;
        }
        
        guard let characteristics = service.characteristics else
        {
            return;
        }
        
        print("Found \(characteristics.count) characteristics!");
        
        for characteristic in characteristics
        {
            
                // looks for the read characteristic
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)
            {
                rxCharacteristic = characteristic;
                    // set a reference to this characteristic in the device
                Device.connectedDevice!.setRXCharacteristic(characteristic);
                
                    // once found, subscribe to this particular characteristic
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                
                peripheral.readValue(for: characteristic);
                print("Rx Characteristic: \(characteristic.uuid)");
            }
            
                // looks for the transmission characteristic
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
            {
                txCharacteristic = characteristic;
                    // set a reference to this characteristic in the device
                Device.connectedDevice!.setTXCharacteristic(characteristic);
                print("Tx Characteristic: \(characteristic.uuid)");
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
            // set flag
        Device.connectedDevice?.hasDiscoveredCharacteristics = true;
            // notify connection button that it can be enabled
        NotificationCenter.default.post(name: Notification.Name(rawValue: "didDiscoverPeripheralCharacteristics"), object: nil);
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        if ((characteristic.descriptors) != nil) {
            
            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor!
                print("function name: DidDiscoverDescriptorForChar \(String(describing: descript?.description))")
                print("Rx Value \(String(describing: rxCharacteristic?.value))")
                print("Tx Value \(String(describing: txCharacteristic?.value))")
            }
        }
    }
    
        // console updates for notification state for a given service, taken from Bluefruit's "simple chat app".
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    {
        print("*******************************************************")
        
        if (error != nil)
        {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
            
        } else
        {
            print("Characteristic's value subscribed")
        }
        
        if (characteristic.isNotifying)
        {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    }
    
    func disconnectFromDevice()
    {
        if Device.connectedDevice?.peripheral != nil
        {
            centralManager?.cancelPeripheralConnection(Device.connectedDevice!.peripheral);
            Device.connectedDevice!.isConnected = false;
            Device.connectedDevice!.hasDiscoveredCharacteristics = false;
            Device.connectedDevice? = Device(true);
                // setting the connectedDevice to the "emptyDevice" placeholder
        }
    }
    
    


    
    
    

    

    // Table view data source

    
    // MARK: - UITableDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
//        guard visibleDevices.count >= indexPath.row else
//        {
//            print("The device in the list doesn't exist yet");
//            return;
//        }
        
        
        
            // if the current connectedDevice doesn't exist, then select the one at IndexPath
        guard Device.connectedDevice != nil && Device.connectedDevice?.name != "emptyDevice" else
        {
            print("Selected new device");
            //disconnectFromDevice();  // no need to disconnect if there isn't a connected device
            Device.setConnectedDevice(newDevice: visibleDevices[indexPath.row]);
            Device.connectedDevice?.isConnected = false;
            Device.connectedDevice?.isConnecting = true;
            connectToDevice();
            return;
        }
        
        
        
            // if the current connectedDevice does exist, only select it if it isn't already connected
        if (Device.connectedDevice!.peripheral != visibleDevices[indexPath.row].peripheral)
        {
                // disconnect from old devices, if any
            disconnectFromDevice();
            Device.setConnectedDevice(newDevice: visibleDevices[indexPath.row]);
            Device.connectedDevice?.isConnected = false;
            Device.connectedDevice?.isConnecting = true;
            connectToDevice();
        }
        else
        {
            print("Selected the same device");
        }
        
        
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return visibleDevices.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "BLEConnectionTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BLEConnectionTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of BLEConnectionTableViewCell.");
        }

        // Fetches the appropriate device for that row
        let device = visibleDevices[indexPath.row];
        //print("Creating a cell with name: \(device.name)");
        cell.deviceNameLabel.text = device.name;
        cell.RSSIValue.text = String(device.RSSI);
        cell.device = device;
        
        return cell
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
            // changing the "back button" text to show that it will disconnect the device, and so that it will fit
            // credit to https://stackoverflow.com/questions/28471164/how-to-set-back-button-text-in-swift
        let backItem = UIBarButtonItem();
        backItem.title = "Disconnect";
        navigationItem.backBarButtonItem = backItem;
        
            // clearing visibleDevices
        visibleDevices = [Device]();
        
    }
    
    
    // MARK: Private Methods
    
        // if we receive a timeout error after requesting a thumbnail row, we have to
    @objc private func resetThumbnailRow()
    {
        print("Timed out, clearing row");
            // clear the half-baked row
        bitmapPixelRow = [Pixel]();
            // tell the ModeTableViewController setup loop to get the thumbnails again
        Device.connectedDevice?.requestedThumbnail = false;
    }
    
        // credit to https://stackoverflow.com/questions/30958427/pixel-array-to-uiimage-in-swift
    private func UIImageFromBitmap(pixels: [Pixel], width: Int) -> UIImage?
    {
        guard (width > 0) else
        {
            print("Insufficient width");
            return nil;
        }
        guard (pixels.count % width == 0) else
        {
            print("Pixel count isn't evenly divisible by the width");
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
            print("Unable to create CGImage");
            return nil;
        }
        
            // returning a UIImage from that CGImage
        return UIImage(cgImage: image);
    }
    
    private func createSampleDeviceWithName(_ name: String) -> Mode
    {
        let bitmap2 = UIImage(named: "Bitmap2");
        
        
            // adding a blank mode with just the correct name (hopefully)
        return Mode(name: name, index: -1, usesBitmap: true, bitmap: bitmap2, colors: [nil])!;
        
    }
            
    private func calculateBatteryPercentage(_ voltage: Float) -> Int
    {
        //print("received voltage of \(voltage)");
        // key representing voltage thresholds for battery percentages (index 0 is 0%, 1 is 5%, 2 is 10%, etc).  From Development Details document.
        let batteryCapacityKey: [Float] = [0, 6.98, 8.71, 9.17, 9.37, 9.51, 9.63, 9.72, 9.79, 9.84, 9.88, 9.91, 9.93, 9.95, 9.96, 9.97, 9.98, 10, 10.09, 10.38, 10.91];
        
        var index: Int = 20;
        // going through the key
        for i in 0...20
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
    private func loadDevices() -> [Device]?
    {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Device.ArchiveURL.path) as? [Device];
    }
    
//        // making fake devices to showcase the UI (no longer necessary since we can connect to real devices)
//    private func loadSampleDevices()
//    {
//
//        // Initializing some sample devices
//        let device1 = Device(name: "ENL1");
//        let device2 = Device(name: "ENL2");
//        let device3 = Device(name: "ENL3");
//        let device4 = Device(name: "ENL4");
//
//        visibleDevices += [device1, device2, device3, device4];
//
//    }
    
}

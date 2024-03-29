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
    
    static var CBCentralState: Constants.CBCM_STATE = .UNCONNECTED_SCANNING_FOR_PRIMARY;
    
    static var advertisingPeripherals = [CBPeripheral]();
    
    static var advertisingRSSIs = [NSNumber]();
    
    static var nicknames = [String]();
    
        // The devices that show up on the connection screen.
    var visibleDevices = [Device]();
    
        // the demo device, initialized in ViewWillAppear()
    var demoDevice = Device(true);
    
        // the devices we have stored in memory, which we will recognize by name
    var cachedDevices = [Device]();
    
        // The bluetooth CentralManager objects controlling the connection to peripherals
            // one for nRF8001 devices (this is the "main" one, which is checked for state for example, and the nRF51822CentralManager mirrors)
    var nRF8001CentralManager : CBCentralManager!;
            // one for nRF51822 devices
    var nRF51822CentralManager : CBCentralManager!;
    
        // A timer object to help in searching
    var timer = Timer();
    
        // A timer object to know when to prompt the "Demo" device
    var deviceTimeoutTimer = Timer();
    
        // Whether or not the demo device can show up (if there are no "real" devices)
    var canShowDemoDevice = false;
    
        // list of peripherals, and their associated RSSI values
    var peripherals: [CBPeripheral] = [];
        // want to get "real" names from advertising data
    var peripheralNames = [String]();
    var RSSIs = [NSNumber]();
    var types = [Constants.PERIPHERAL_TYPE]();
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
    
        // a reference to the table view
    @IBOutlet weak var deviceTableView: UITableView!
    
        // a reference to the searching indicator items at the top
    @IBOutlet weak var searchingIndicator: UIView!
    @IBOutlet weak var searchingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var searchButton: UIButton!
    
    var initialSearchingIndicatorHeight: CGFloat = 0;
    
    // MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // storing the height of the searching indicator, so we can restore it to this height if we have to re-load
        initialSearchingIndicatorHeight = searchingIndicator.frame.size.height;
        
        // initializing both central managers
        nRF8001CentralManager = CBCentralManager(delegate:self, queue: nil);
        nRF51822CentralManager = CBCentralManager(delegate:self, queue: nil);
        
        NotificationCenter.default.addObserver(self, selector: #selector(resetThumbnailRow), name: Notification.Name(rawValue: Constants.MESSAGES.RESEND_THUMBNAIL_ROW), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateMimicDevicesAndCentralState), name: Notification.Name(rawValue: Constants.MESSAGES.UPDATE_CBCENTRAL_STATE), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(startScan), name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil)

        deviceTableView.separatorStyle = UITableViewCellSeparatorStyle.singleLine;
        
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
        cachedDevices = BLEConnectionTableViewController.loadDevices() ?? [Device]();
        
        //centralManager = CBCentralManager(delegate:self, queue: nil);
        
            // if we're currently connected to a device as we enter this screen, disconnect (because we'll be choosing a new one)
        disconnectFromPrimaryDevice();
        
        disconnectAllDevices();
        
        BLEConnectionTableViewController.CBCentralState = .UNCONNECTED_SCANNING_FOR_PRIMARY;
        print(BLEConnectionTableViewController.CBCentralState);
        
            // we want to clear the visibleDevices() array now that we have cached memory
        visibleDevices = [Device]();
        
        canShowDemoDevice = false;
        
            // and we want to visually clear the list
        self.deviceTableView.reloadData();
        
        searchButton.isEnabled = false;
        
         // changing how the search/rescan/disconnect button looks
        searchButton.setTitle("Searching for BLE Devices...", for: UIControlState.disabled);
        searchButton.setTitle("Disconnect", for: UIControlState.normal);
        
        searchingIndicator.isHidden = true;
        
            // shorter scan on entry so that devices will be culled quickly
        startScan();
        
        
            // initializing the demo device, with cached modes/bitmaps/etc.
        demoDevice = Device.createDemoDevice();
        
        deviceTimeoutTimer.invalidate();
        
    }
    
        // start scan on appearance of viewController
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated);
        
            // if bluetooth isn't enabled
        if (nRF8001CentralManager.state != CBManagerState.poweredOn)
        {
                // make it possible to show the demo mode eventually
            if !(self.canShowDemoDevice)
            {
                // create a new timer (with much shorter duration) and when it fires, the demo device can be shown (if there are no "real" devices found)
                self.deviceTimeoutTimer.invalidate();
                self.deviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: false, block:
                    { (deviceTimeoutTimer) in
                        self.canShowDemoDevice = true;
                        if (Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
                        {
                            // reload table
                            self.deviceTableView.reloadData();
                        }
                })
            }
        }
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
            print("Bluetooth Enabled, \(central) is active")
            startScan();
            
            // should scan multiple times
            
            //scanTimer = Timer.scheduledTimer(timeInterval: scanTimeInterval, target: self, selector: #selector(startScan), userInfo: nil, repeats: true);// startScan();
        }
            // we only want to do these actions once (the disconnectFromPrimaryDevice function can handle devices of either type)
        else if (central == nRF8001CentralManager)
        {
            print("Should go to the Connect Screen at this point");
            _ = self.navigationController?.popToRootViewController(animated: true);
                // if there is an active device, disconnect from it
            disconnectFromPrimaryDevice();
                // clearing table data
            peripherals = [CBPeripheral]();
            peripheralNames = [String]();
            RSSIs = [NSNumber]();
            types = [Constants.PERIPHERAL_TYPE]();
            
            visibleDevices = [Device]();
            deviceTableView.reloadData();
            
                // since we aren't searching, hide this message
            searchingIndicator.isHidden = true;
            
            print("Bluetooth disabled, make sure your device is turned on");
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on.", preferredStyle: UIAlertControllerStyle.alert);
            let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
                
                // even if we're disconnected, we can still show the demo device (also allows us to see it in the simulator, which has no bluetooth capability)
                if !(self.canShowDemoDevice)
                {
                    // create a new timer (with much shorter duration) and when it fires, the demo device can be shown (if there are no "real" devices found)
                    self.deviceTimeoutTimer.invalidate();
                    self.deviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: false, block:
                        { (deviceTimeoutTimer) in
                            self.canShowDemoDevice = true;
                            if (Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
                            {
                                // reload table
                                self.deviceTableView.reloadData();
                            }
                    })
                }
                
                    // close the popup
                self.dismiss(animated: true, completion: nil);
            })
            alertVC.addAction(action);
            self.present(alertVC, animated: true, completion: nil);
            
           
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
            // the true (non-cached) advertised name of the device
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as! String;
        
        if (advertisedName.lowercased().prefix(3) == "enl")
        {
            print("Found a device \(advertisedName), cached name \(String(describing: peripheral.name)), adding it, its advertised name, and its RSSI to the list");
            self.peripherals.append(peripheral);
            self.peripheralNames.append(advertisedName);
            self.RSSIs.append(RSSI);
                // specifying the type based on which central discovered the peripheral
            if (central == nRF8001CentralManager)
            {
                self.types.append(.nRF8001);
            }
            else if (central == nRF51822CentralManager)
            {
                self.types.append(.nRF51822);
            }
            else
            {
                self.types.append(.UNKNOWN);
            }
            
        }
        else
        {
            print("Found a new device \(advertisedName) with UUID \(peripheral.identifier.description), but it doesn't look like it's an Enlighted device, so it will be excluded from the list");
            
            let advertisedServiceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as! [CBUUID];
            print(advertisedServiceUUIDs);
//            if (advertisedServiceUUIDs.contains(nRF8001_BLEService_UUID))
//            {
//                print("This device is advertising the nRF8001 Uart service UUID");
//            }
//            if (advertisedServiceUUIDs.contains(nRF51822_BLEService_UUID))
//            {
//                print("This device is advertising the nRF51822 Uart service UUID");
//            }
            
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
        if (nRF8001CentralManager.state != CBManagerState.poweredOn)
        {
            print("Bluetooth isn't available right now, make sure it's activated on your phone");
            return;
        }
        
            // debug message to make sure we're connecting/disconnecting properly
        //print(centralManager.retrieveConnectedPeripherals(withServices: [BLEService_UUID]));
        
            // make sure everything is hidden/shown correctly – if we aren't connected, and not currently connecting
        if ((Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice") && !(Device.connectedDevice?.isConnecting ?? false))
        {
            searchButton.isEnabled = false;
            searchButton.setTitle("Searching for BLE Devices...", for: UIControlState.disabled);
        }
        
        if (searchingIndicator.isHidden)
        {
            searchingActivityIndicator.isHidden = false;
            searchingIndicator.isHidden = false;
        }
        
            // clearing the visibleDevices list when we're scanning again
        //visibleDevices = [Device]();
        peripherals = [CBPeripheral]();
        peripheralNames = [String]();
        RSSIs = [NSNumber]();
        types = [Constants.PERIPHERAL_TYPE]();
        
        print("Now scanning...");
        self.timer.invalidate();
            // scanning with both centralmanagers, for different service UUIDs
        nRF8001CentralManager?.scanForPeripherals(withServices: [nRF8001_BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        nRF51822CentralManager?.scanForPeripherals(withServices: [nRF51822_BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        self.timer = Timer.scheduledTimer(timeInterval: scanTime, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false);
    }
    
        // cancelling the scan for peripherals
    @objc func cancelScan()
    {
        self.nRF8001CentralManager?.stopScan()
        self.nRF51822CentralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
        
            // making the peripherals visible from anywhere
        BLEConnectionTableViewController.advertisingPeripherals = peripherals;
        BLEConnectionTableViewController.advertisingRSSIs = RSSIs;
        
        // if we're scanning for a primary device, update that list
        if (BLEConnectionTableViewController.CBCentralState == .UNCONNECTED_SCANNING_FOR_PRIMARY || BLEConnectionTableViewController.CBCentralState == .CONNECTED_SCANNING_FOR_PRIMARY)
            //(Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
        {
                // going through devices
            if (visibleDevices.count > 0)
            {
                // if there are real devices, we don't want to be immediately showing the demo device afterward
                canShowDemoDevice = false;
                if (deviceTimeoutTimer.isValid)
                {
                    deviceTimeoutTimer.invalidate();
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
                        types.remove(at: foundPeripheralIndex);
                        
                        deviceIndex += 1;
                    }
                            // if we don't see this peripheral anymore
                    else if (!peripherals.contains(visibleDevices[deviceIndex].peripheral))
                    {
                            // if it's because we're already connected, then we want to read the RSSI (which is done differently)
                        if (Device.connectedDevice?.peripheral == visibleDevices[deviceIndex].peripheral)
                        {
                            Device.connectedDevice?.peripheral.readRSSI();
                            visibleDevices[deviceIndex].RSSI = Device.connectedDevice!.RSSI;
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
                                newDevice.hardwareType = types[i];
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
                            visibleDevices.append(Device(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i], type: types[i]));
                        }
                    }
                    else
                    {
                        // otherwise create a brand-new device
                        visibleDevices.append(Device(name: peripheralNames[i], RSSI: RSSIs[i].intValue, peripheral: peripherals[i], type: types[i]));
                    }
                }
            }
                // if there aren't any visible devices and no peripherals, we should start the countdown to show the "demo device":
            else
            {
                    // as long as we are not already counting down
                if !(deviceTimeoutTimer.isValid)
                {
                        // create a new timer and when it fires, the demo device can be shown (if there are no "real" devices found)
                    deviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Constants.SCAN_TIMEOUT_TIME), repeats: false, block:
                        { (deviceTimeoutTimer) in
                            self.canShowDemoDevice = true;
                    })
                }
            }
            // if the device hasn't connected, keep scanning
            startScan();
            
            // find the index of the currently selected row, if any
            let indexPath = deviceTableView.indexPathForSelectedRow;
            
            //[self.tableView selectRowAtIndexPath:ipath animated:NO scrollPosition:UITableViewScrollPositionNone]
            
            // reload table
            deviceTableView.reloadData();
            
            // if there was a previously selected row, re-select it
            if (indexPath != nil)
            {
                deviceTableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none);
            }
            
        }
                // if we're looking for any BLE peripherals to show
        else if (BLEConnectionTableViewController.CBCentralState == .SCANNING_FOR_MIMICS_TO_DISPLAY)
        {
            print("We are looking for mimic devices to display on the Choose Mimic Device To Display screen");
            print(peripherals);
            
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_NEW_PERIPHERALS), object: nil);
            
            startScan();
            
        }
        else if (BLEConnectionTableViewController.CBCentralState == .SCANNING_FOR_MIMICS_TO_CONNECT)
        {
            if (peripherals.count > 0)
            {
                for i in 0...(peripherals.count - 1)
                {
                        // if the peripheral's on the mimic list
                    if (Device.connectedDevice!.mimicList.contains(peripherals[i].identifier as NSUUID))
                    {
                            // connect to it (it's added to the "connected mimic devices" list in the callback)
                        if (types[i] == .nRF8001)
                        {
                            nRF8001CentralManager.connect(peripherals[i], options: nil);
                        }
                        else if (types[i] == .nRF51822)
                        {
                            nRF51822CentralManager.connect(peripherals[i], options: nil);
                        }
                        else
                        {
                            print("Found mimic device named \(peripheralNames[i]) we would like to connect to, but unable to connect to devices of hardware type \(types[i])");
                        }
                    }
                }
            }
            
            startScan();
        }
        
//        if (Device.connectedDevice == nil || Device.connectedDevice?.name == "emptyDevice")
//        {
//
//        }
        
    }
    
    //MARK: Parsing rxCharacteristic
    
        // called automatically after characteristics we've subscribed to are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
            // parsing/dealing with the info read from the firmware of the primary
        if characteristic == Device.connectedDevice?.rxCharacteristic
        {
            
                // if there's an error, it shouldn't keep going
            if let e = error
            {
                print("ERROR didUpdateValueFor \(e.localizedDescription)");
                return;
            }
            if (characteristic.value!.count < 1)
            {
                print("Empty value. Returning");
                return;
            }
            
            var receivedArray: [UInt8] = [];
            
            let rxValue = [UInt8](characteristic.value!);
            
            receivedArray = Array(characteristic.value!);
            
                // converting data to a string
            let rxString = String(bytes: receivedArray, encoding: .ascii);
            
                //converting first byte into an int, for the 1 or 0 success responses
            let rxInt = Int(receivedArray[0]);
            
            
            print("received \(receivedArray) from \(String(describing: peripheral.name))");
            
            
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
                    // if the response after the first half of a name isn't a name, something's wrong, and we should clear everything
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
                // if the first letter is "L", we're getting the current mode, max number of modes, and max number of bitmaps.
            else if (rxString?.prefix(1) == "L") //[(rxString?.startIndex)!] == "L")
            {
                print("Value Recieved: " + rxString!.prefix(1), Int(rxValue[1]), Int(rxValue[2]), Int(rxValue[3]));
                //print(Int(rxValue[1]));
                Device.connectedDevice?.currentModeIndex = Int(rxValue[1]);
                Device.connectedDevice?.maxNumModes = Int(rxValue[2]);
                Device.connectedDevice?.maxBitmaps = Int(rxValue[3]);
                
                    // making sure that the current mode isn't above the max (which can sometimes happen in a sort of "demo" mode)
                if ((Device.connectedDevice?.currentModeIndex)! > (Device.connectedDevice?.maxNumModes)!)
                {
                        // if it is, default to mode 1 on the app
                    Device.connectedDevice?.currentModeIndex = 1;
                }
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_LIMITS_VALUE), object: nil);
            }
                // if the first letter is "G", we're getting the brightness, on a scale from 0-255;
            else if (rxString?.prefix(1) == "G") //[(rxString?.startIndex)!] == "G")
            {
                print("Value Recieved: " + rxString!.prefix(1), Int(rxValue[1]));
                Device.connectedDevice?.brightness = Int(rxValue[1]);
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BRIGHTNESS_VALUE), object: nil);
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
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BATTERY_VALUE), object: nil);
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
                    print("Recieved a mode we want to use for reversion");
                    
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
                    print("No longer looking for modes for reversion, ready to send message to EditScreenViewController");
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_MODE_VALUE), object: nil);
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
                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_MODE_VALUE), object: nil);
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
            //NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
        }
            // receiving from other characteristics, most likely the mimic devices' rxCharacteristics
        else
        {
                // print the value and source
            print(" \(String(describing: characteristic.value)) received from \(String(describing: peripheral.name))");
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
//    func writeValue(data: String)
//    {
//        if (!(Device.connectedDevice?.isConnected)!)
//        {
//            print("Device is not connected");
//            return;
//        }
//        else if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
//        {
//            print("Disconnected");
//            
//            // error popup
//            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
//            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
//            {(action) -> Void in
//                print("Should go to the Connect Screen at this point");
//                _ = self.navigationController?.popToRootViewController(animated: true);
//            })
//            
//            dialogMessage.addAction(ok);
//            
//            self.present(dialogMessage, animated: true, completion: nil);
//            // shows the Connection page (hopefully/eventually)
//            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
//            //self.show(newViewController, sender: self);
//        }
//        
//        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue);
//            // if the blePeripheral variable is set
//        if let blePeripheral = blePeripheral
//        {
//            // and the txCharacteristic variable is set
//            if let txCharacteristic = txCharacteristic
//            {
//                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withoutResponse);
//            }
//        }
//    }
    
        // listening for a response after we write to txCharacteristic
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        print("Message sent")
    }
    
        // connecting to the peripheral of the connected device in Device
    func connectToPrimaryDevice()
    {
        if (Device.connectedDevice?.hardwareType == Constants.PERIPHERAL_TYPE.nRF8001)
        {
            nRF8001CentralManager.connect(Device.connectedDevice!.peripheral, options: nil);
        }
        else if (Device.connectedDevice?.hardwareType == Constants.PERIPHERAL_TYPE.nRF51822)
        {
            nRF51822CentralManager.connect(Device.connectedDevice!.peripheral, options: nil);
        }
        else
        {
            print("Attempted to connect to device \(Device.connectedDevice?.name), but unable to connect to devices of hardware type \(Device.connectedDevice?.hardwareType)");
        }
        
        
            // making sure the top bar's items are correctly shown/hidden/enabled
        
        //searchingActivityIndicator.isHidden = true;
        searchButton.setTitle("Connecting...", for: UIControlState.disabled);
        //searchButton.isEnabled = false;
        //searchButton.isHidden = false;
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
            // print info about the connected peripheral
        print ("*******************************************************");
        print("Connection complete");
        print("Peripheral info: \(peripheral) ");
        
            // set connected flag on device object, if we're connecting to the primary
        if (peripheral.identifier as NSUUID == Device.connectedDevice?.peripheral.identifier as! NSUUID)
        {
            // changing state to reflect the central's newly connected status
            if (BLEConnectionTableViewController.CBCentralState == .UNCONNECTED_SCANNING_FOR_PRIMARY)
            {
                BLEConnectionTableViewController.CBCentralState = .CONNECTED_SCANNING_FOR_PRIMARY;
                print(BLEConnectionTableViewController.CBCentralState);
            }
            
            Device.connectedDevice?.isConnected = true;
            Device.connectedDevice?.isConnecting = false;
            
            // once we've connected, we can rescan again
            searchButton.isEnabled = true;
        }
        else
        {
            var newDevice = Device(mimicDevicePeripheral: peripheral);
                // setting the UUID
            newDevice.UUID = newDevice.peripheral.identifier as NSUUID;
            if (central == nRF8001CentralManager)
            {
                newDevice.hardwareType = .nRF8001;
            }
            else if (central == nRF51822CentralManager)
            {
                newDevice.hardwareType = .nRF51822;
            }
            //sendBLEPacketsToConnectedPeripherals(
            
            Device.connectedDevice?.connectedMimicDevices += [newDevice];
            
            updateMimicDevicesAndCentralState();
        }
        
        
        
            // stop scanning
        //centralManager?.stopScan();
        //print("Scan stopped");
            // stopping the normal scan timer
        //timer.invalidate();
        
            // erase data we might have
        data.length = 0;
        
        
        
        
            // Discovery callback
        peripheral.delegate = self;
            // Only look for services that match the transmit UUID
        peripheral.discoverServices([nRF8001_BLEService_UUID]);
        //peripheral.discoverServices([BLEBatteryService_UUID]);
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    {
        print("Failed to connect to peripheral, \(error?.localizedDescription)");
        
        let alertVC = UIAlertController(title: "Failed to connect to device", message: "Please select that device again, or select a different device.", preferredStyle: UIAlertControllerStyle.alert);
        let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
            
                // close the error window
            self.dismiss(animated: true, completion: nil);
        })
        alertVC.addAction(action);
        self.present(alertVC, animated: true, completion: nil);
        
        // reloading the data, removing the selection and removing the device if it isn't there anymore
        deviceTableView.reloadData();
        // starting the scan again
        startScan();
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        guard (peripheral.identifier as NSUUID != Device.connectedDevice?.UUID) else
        {
            BLEConnectionTableViewController.CBCentralState = .UNCONNECTED_SCANNING_FOR_PRIMARY;
            print(BLEConnectionTableViewController.CBCentralState);
            
            print("We disconnected from our connected primary peripheral.");
            print("\(error?.localizedDescription ?? "unknown error")");
            // error popup
            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {(action) -> Void in
                print("Should go to the Connect Screen at this point");
                _ = self.navigationController?.popToRootViewController(animated: true);
                
                // disconnect from the device, if any
                self.disconnectFromPrimaryDevice();
                
                // deselect the currently selected item
                if let index = self.deviceTableView.indexPathForSelectedRow
                {
                    self.deviceTableView.deselectRow(at: index, animated: true);
                }
                
                // scanning again, using the shorter scan time to quickly and roughly update the list
                self.startScan();
                
            })
            
            dialogMessage.addAction(ok);
            
                // presenting this view controller over the current screen, whatever that may be
            self.navigationController?.topViewController?.present(dialogMessage, animated: true, completion: nil);
            
            return;
        }
        
        print("Disconnected from " + peripheral.name!);
        print("\(error?.localizedDescription ?? "unknown error")");
        
            // if it's not the primary, it still might be one of the mimic devices
        if (Device.connectedDevice!.connectedMimicDevices.count > 0)
        {
            for i in 0...(Device.connectedDevice!.connectedMimicDevices.count - 1)
            {
                // and so we have to remove it from the list
                
                print("index \(i) of: \(Device.connectedDevice!.connectedMimicDevices)")
                
                if (Device.connectedDevice!.connectedMimicDevices[i].peripheral.identifier as NSUUID == peripheral.identifier as NSUUID)
                {
                    print("removing \(peripheral.name) at index \(i) from the list \(Device.connectedDevice!.connectedMimicDevices)")
                    
                    Device.connectedDevice!.connectedMimicDevices.remove(at: i);
                    
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
        
            // by default, look for the "old" nRF8001 characteristics
        var BLE_Characteristic_uuid_Rx = nRF8001_Rx_BLECharacteristic_UUID;
        var BLE_Characteristic_uuid_Tx = nRF8001_Tx_BLECharacteristic_UUID;
        
            // but if this is an nRF51822 service/board, use those instead
        if (service.uuid == nRF51822_BLEService_UUID)
        {
            BLE_Characteristic_uuid_Rx = nRF51822_Rx_BLECharacteristic_UUID;
            BLE_Characteristic_uuid_Tx = nRF51822_Tx_BLECharacteristic_UUID;
        }
        
        
            // if this is the main connected device
        if (peripheral.identifier as NSUUID == Device.connectedDevice!.peripheral.identifier as! NSUUID)
        {
            
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
                    print("Rx Characteristic of primary \(Device.connectedDevice?.name): \(characteristic.uuid)");
                }
                
                    // looks for the transmission characteristic
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
                {
                    txCharacteristic = characteristic;
                        // set a reference to this characteristic in the device
                    Device.connectedDevice!.setTXCharacteristic(characteristic);
                    print("Tx Characteristic of primary \(Device.connectedDevice?.name): \(characteristic.uuid)");
                    
                    // set flag
                    Device.connectedDevice?.hasDiscoveredCharacteristics = true;
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
            
            var mimicDevice: Device?;
            
            for characteristic in characteristics
            {
                peripheral.discoverDescriptors(for: characteristic);
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
                {
                    //txCharacteristic = characteristic;
                    
                    for device in Device.connectedDevice!.connectedMimicDevices
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
                        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_MIMIC_CHARACTERISTICS), object: nil);
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
                    print("Rx Characteristic of mimic device \(mimicDevice?.name): \(characteristic.uuid)");
                }
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil
        {
            print("\(error.debugDescription)")
            return
        }
        
        if (characteristic == Device.connectedDevice?.rxCharacteristic)
        {
            print("Discovered primary device's rxCharacteristic's descriptors: ");
            print("properties: \(String(format:"%04X", characteristic.properties.rawValue))")
        }
        else if (characteristic == Device.connectedDevice?.txCharacteristic)
        {
            print("Discovered primary device's txCharacteristic's descriptors: ");
            print("properties: \(String(format:"%04X", characteristic.properties.rawValue))")
        }
        
        if ((characteristic.descriptors) != nil)
        {
            print("\(String(describing: characteristic.descriptors?.count)) descriptors discovered: ")
            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor!
                peripheral.readValue(for: descript!)
                print("\(String(describing: descript?.description))")
            }
        }
        else
        {
            print("no descriptors discovered.");
        }
    }
    
        // getting descriptor values, from https://stackoverflow.com/questions/42984737/ios-ble-characteristic-user-description
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?)
    {
        switch descriptor.uuid.uuidString
        {
            case CBUUIDCharacteristicExtendedPropertiesString:
                guard let properties = descriptor.value as? NSNumber else
                {
                    break
                }
                print("  Extended properties: \(properties)")
            case CBUUIDCharacteristicUserDescriptionString:
                guard let description = descriptor.value as? NSString else
                {
                    break
                }
                print("  User description: \(description)")
            case CBUUIDClientCharacteristicConfigurationString:
                guard let clientConfig = descriptor.value as? NSNumber else
                {
                    break
                }
                print("  Client configuration: \(clientConfig)")
            case CBUUIDServerCharacteristicConfigurationString:
                guard let serverConfig = descriptor.value as? NSNumber else
                {
                    break
                }
                print("  Server configuration: \(serverConfig)")
            case CBUUIDCharacteristicFormatString:
                guard let format = descriptor.value as? NSData else
                {
                    break
                }
                print("  Format: \(format)")
            case CBUUIDCharacteristicAggregateFormatString:
                print("  Aggregate Format: (is not documented)")
            default:
                break
        }
    }
    
        // console updates for notification state for a given service, taken from Bluefruit's "simple chat app".
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    {
        print("*******************************************************")
        
        if (error != nil)
        {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))");
            
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
            print("Error reading RSSI of connected peripheral:\(String(describing: error?.localizedDescription))");
        }
        else
        {
                // updating the Device object's RSSI value, which is communicated to visibleDevices[] in cancelScan().
            Device.connectedDevice?.RSSI = RSSI.intValue;
        }
    }
    
    func disconnectFromPrimaryDevice()
    {
        if Device.connectedDevice?.peripheral != nil
        {
            if (Device.connectedDevice?.hardwareType == Constants.PERIPHERAL_TYPE.nRF8001)
            {
                nRF8001CentralManager?.cancelPeripheralConnection(Device.connectedDevice!.peripheral);
            }
            else if (Device.connectedDevice?.hardwareType == Constants.PERIPHERAL_TYPE.nRF51822)
            {
                nRF51822CentralManager?.cancelPeripheralConnection(Device.connectedDevice!.peripheral);
            }
            else
            {
                 print("Attempted to disconnect from device \(Device.connectedDevice?.name), but unable to find an appropriate central for devices of hardware type \(Device.connectedDevice?.hardwareType) (was the type changed after connection?)");
            }
            
            Device.connectedDevice!.isConnected = false;
            Device.connectedDevice!.hasDiscoveredCharacteristics = false;
            //Device.connectedDevice? = Device(true);
                // setting the connectedDevice to the "emptyDevice" placeholder
            
            BLEConnectionTableViewController.CBCentralState = .UNCONNECTED_SCANNING_FOR_PRIMARY;
            print(BLEConnectionTableViewController.CBCentralState);
        }
                // if it's a demo device, it also has to be "disconnected"
        else if (Device.connectedDevice?.isDemoDevice ?? false)
        {
            Device.connectedDevice!.isConnected = false;
            Device.connectedDevice!.hasDiscoveredCharacteristics = false;
            //Device.connectedDevice? = Device(true);
        }
        Device.connectedDevice? = Device(true);
    }
    
    func disconnectAllDevices()
    {
        disconnectFromPrimaryDevice();
        
            // all the currently connected nRF8001 peripherals
        let nRF8001PeripheralsToDisconnectFrom = nRF8001CentralManager.retrieveConnectedPeripherals(withServices: [nRF8001_BLEService_UUID]);
        
            // if there are still some left over, we need to disconnect from them
        if (nRF8001PeripheralsToDisconnectFrom.count > 0)
        {
            for i in 0...nRF8001PeripheralsToDisconnectFrom.count - 1
            {
                nRF8001CentralManager.cancelPeripheralConnection(nRF8001PeripheralsToDisconnectFrom[i]);
            }
        }
        
        // all the currently connected nRF8001 peripherals
        let nRF51822PeripheralsToDisconnectFrom = nRF51822CentralManager.retrieveConnectedPeripherals(withServices: [nRF51822_BLEService_UUID]);
            
                // if there are still some left over, we need to disconnect from them
        if (nRF51822PeripheralsToDisconnectFrom.count > 0)
        {
            for i in 0...nRF51822PeripheralsToDisconnectFrom.count - 1
            {
                nRF51822CentralManager.cancelPeripheralConnection(nRF51822PeripheralsToDisconnectFrom[i]);
            }
        }
    }

    // Table view data source

    
    // MARK: - UITableDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
//        guard indexPath != nil else
//        {
//            print("The selected index doesn't exist");
//            
//            return;
//        }
        
            // if there are "real" devices to select
        if (visibleDevices.count > 0 )
        {
            
                // if the current connectedDevice doesn't exist, then select the one at IndexPath
            guard Device.connectedDevice != nil && Device.connectedDevice?.name != "emptyDevice" else
            {
                print("Selected new device");
                
                //disconnectFromDevice();  // no need to disconnect if there isn't a connected device
                Device.setConnectedDevice(newDevice: visibleDevices[indexPath.row]);
                Device.connectedDevice?.isConnected = false;
                Device.connectedDevice?.isConnecting = true;
                connectToPrimaryDevice();
                return;
            }
            
            
            
                // if the current connectedDevice does exist, only select it if it isn't already connected
            if (Device.connectedDevice!.peripheral != visibleDevices[indexPath.row].peripheral)
            {
                    // disconnect from old devices, if any
                disconnectFromPrimaryDevice();
                Device.setConnectedDevice(newDevice: visibleDevices[indexPath.row]);
                Device.connectedDevice?.isConnected = false;
                Device.connectedDevice?.isConnecting = true;
                connectToPrimaryDevice();
            }
            else
            {
                print("Selected the same device");
            }
            
           
            
        }
            // otherwise we're selecting the demo device
        else
        {
            // disconnect from old devices, if any
            disconnectFromPrimaryDevice();
            Device.setConnectedDevice(newDevice: demoDevice);
                // pretend it already connected
            Device.connectedDevice?.isConnected = true;
                // and that it's no longer "connecting"
            Device.connectedDevice?.isConnecting = false;
            
            print ("Selected the demo device");
        }
        
        
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
            // if there are actual devices to show, or we can't yet show the demo device, show the real devices (even if it's zero)
        if (visibleDevices.count > 0) || (canShowDemoDevice == false)
        {
            return visibleDevices.count;
        }
            // otherwise add 1 for the demo device
        else
        {
            return 1;
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "BLEConnectionTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BLEConnectionTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of BLEConnectionTableViewCell.");
        }

        var device: Device;
        
            // if there are actual devices
        if (visibleDevices.count > 0)
        {
            // Fetches the appropriate device for that row
            device = visibleDevices[indexPath.row];
            cell.isDemoDevice = false;
            //print("Creating a cell with name: \(device.name)");
        }
        else if (canShowDemoDevice)
        {
            device = demoDevice;
            cell.isDemoDevice = true;
        }
        else
        {
            fatalError("There is no device to fill this cell.");
        }
        
        cell.device = device;
        
        var deviceDisplayName = device.name;
        
            // if there's a nickname, use that as well
        
        if (device.nickname != "")
        {
            deviceDisplayName = deviceDisplayName + " – " + device.nickname;
        }
        
        cell.deviceNameLabel.text = deviceDisplayName;
        cell.updateRSSIValue(device.RSSI);
        
        return cell;
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
        //visibleDevices = [Device]();
        
        
        // stop scanning
        if (nRF8001CentralManager.state == CBManagerState.poweredOn)
        {
            cancelScan();
        }
        
        print("Scan stopped");
        // stopping the normal scan timer
        timer.invalidate();
        
    }
    
    // MARK: - Actions
    
        // disconnecting from the currently selected peripheral, deselecting the table, and starting to scan again
    @IBAction func startScanningForPrimaryAgain(_ sender: UIButton)
    {
            // disconnect from the device, if any
        disconnectFromPrimaryDevice();
        
            // deselect the currently selected item
        if let index = deviceTableView.indexPathForSelectedRow
        {
            deviceTableView.deselectRow(at: index, animated: true);
        }
        
            // scanning again, using the shorter scan time to quickly and roughly update the list
        startScan();
    }
    
    // MARK: - Public Methods
    
    static func sendBLEPacketToConnectedPeripherals( valueData: NSData, sendToMimicDevices: Bool)
    {
            // if we're still waiting on a response, don't send a new message
        if (Device.connectedDevice!.requestWithoutResponse)
        {
            return;
        }
        
        print("sending \(valueData) to primary peripheral");
        
        if Device.connectedDevice!.hasDiscoveredCharacteristics
        {
            Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            Device.connectedDevice!.requestWithoutResponse = true;
        }
        else
        {
            print("The primary has not yet discovered the txCharacteristic, not sending packet");
        }
        
        // if there are mimic devices connected, and this command should be sent to them
        if (Device.connectedDevice!.connectedMimicDevices.count > 0 && sendToMimicDevices)
        {
            for i in 0...Device.connectedDevice!.connectedMimicDevices.count - 1
            {
                if (Device.connectedDevice!.connectedMimicDevices[i].hasDiscoveredCharacteristics)
                {
                    print("sending \(valueData) to mimic peripheral #\(i + 1) ");
                    
                    Device.connectedDevice!.connectedMimicDevices[i].peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.connectedMimicDevices[i].txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
                }
                else
                {
                    print("The mimic device \(Device.connectedDevice!.connectedMimicDevices[i].name) has not yet discovered the txCharacteristic, not sending packet");
                }
            }
        }
        
        
    }
    
    @objc func updateMimicDevicesAndCentralState()
    {
        print("–––––––––––––––––––Updating mimic device list and central state–––––––––––––––––––––");
        
        var mimicDevices = Device.connectedDevice!.connectedMimicDevices
        var mimicDevicesToDisconnectFrom = [Device]();
        
        if (mimicDevices.count > 0)
        {
        
                // check to see what mimic devices are connected to but aren't on the list
            for i in 0...(mimicDevices.count - 1)
            {
                // if we can't find this device in the mimic list
                if !(Device.connectedDevice?.mimicList.contains(mimicDevices[i].peripheral.identifier as NSUUID))!
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
                    if (mimicDevicesToDisconnectFrom[i].hardwareType == Constants.PERIPHERAL_TYPE.nRF8001)
                    {
                        nRF8001CentralManager?.cancelPeripheralConnection(mimicDevicesToDisconnectFrom[i].peripheral);
                    }
                    else if (mimicDevicesToDisconnectFrom[i].hardwareType == Constants.PERIPHERAL_TYPE.nRF51822)
                    {
                        nRF51822CentralManager?.cancelPeripheralConnection(mimicDevicesToDisconnectFrom[i].peripheral);
                    }
                    else
                    {
                         print("Attempted to disconnect from a mimic device, but unable to find an appropriate central for devices of hardware type \(mimicDevicesToDisconnectFrom[i].hardwareType) (was the type changed after connection?)");
                    }
                    // remove it from the list of connected mimic peripherals
                    Device.connectedDevice!.connectedMimicDevices.remove(at: Device.connectedDevice!.connectedMimicDevices.index(of: mimicDevicesToDisconnectFrom[i])!);
                }
            }
            
            
        }
        
        if (Device.connectedDevice!.mimicList.count > 0)
        {
                // if we aren't connected to each device on the mimic list, we need to work on doing so
            if (Device.connectedDevice!.mimicList.count > Device.connectedDevice!.connectedMimicDevices.count)
            {
                BLEConnectionTableViewController.CBCentralState = .SCANNING_FOR_MIMICS_TO_CONNECT;
                print(BLEConnectionTableViewController.CBCentralState);
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil);
            }
                // otherwise we're good and don't need to scan
            else
            {
                BLEConnectionTableViewController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
                print(BLEConnectionTableViewController.CBCentralState);
            }
        }
        else
        {
            BLEConnectionTableViewController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
            print(BLEConnectionTableViewController.CBCentralState);
        }
        
    }
    
    // MARK: - Private Methods
    
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
        return Mode(name: name, index: -1, usesBitmap: true, bitmap: bitmap2, colors: [nil])!;
        
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
    static func loadDevices() -> [Device]?
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

//
//  ModeTableViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import CoreBluetooth;
import os.log;

class ModeTableViewController: UITableViewController, CBPeripheralManagerDelegate
{
        // MARK: - Properties
    @IBOutlet weak var modeTableView: UITableView!
    
        // the loading bar
    @IBOutlet weak var loadingProgressView: UIProgressView!
        // and its corresponding message
    @IBOutlet weak var loadingLabel: UILabel!
        // a UIView holding all the loading items, which should be shrunk down when complete
    @IBOutlet weak var loadingItems: UIView!
    
    
    var totalPacketsForSetup = 0;
    
    var initialLoadingItemsHeight: CGFloat = 0;
    
    var progress: Float = 0;
    
        // list of modes
    var modes = [Mode]();
    
        // timer to set up mode table
    var timer = Timer();
    
        // timer to check BLE timeout, especially when fetching bitmaps
    var BLETimeoutTimer = Timer();
    
        // whether or not the currently selected mode has to be initialized
    var initialModeSelected = false;
    
        // whether or not the device has the full set of modes and thumbnails (if not, it has to do much more bluetooth, and so should enable the "Standby" mode.)
    var deviceHasModes = false;
    
        // whether or not the device has a non-empty mimic list
    var deviceHasMimicList = false;
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();

            // storing the height of the loading label, so we can restore it to this height if we have to re-load
        initialLoadingItemsHeight = loadingItems.frame.size.height;
        
            // and then hiding it
        var newFrame = loadingItems.frame;
        newFrame.size.height = 0;
        loadingItems.frame = newFrame;
        
        
            // setting this as the delegate of the table view
        tableView.delegate = self;
        
            // setting this as the delegate of the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil);
        //Device.connectedDevice!.peripheral.delegate = self as! CBPeripheralDelegate;
        
            // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false;
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateModeSettings), name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_MODE_VALUE), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(prepareForSetup), name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_LIMITS_VALUE), object: nil)
        
            // when we connect to a new device (like a mimic), send the current mode settings
        NotificationCenter.default.addObserver(self, selector: #selector(updateModeOnHardware), name: Notification.Name(rawValue:  Constants.MESSAGES.DISCOVERED_MIMIC_CHARACTERISTICS), object: nil)
        
            // getLimits for this device, though not if it's a demo device
        if !(Device.connectedDevice!.isDemoDevice)
        {
            getValue(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
            Device.connectedDevice?.requestedLimits = true;
        }
        else
        {
                // we have to fake getLimits if it's a demo device, based on the application saved data
            Device.connectedDevice?.maxNumModes = 20;
            Device.connectedDevice?.maxBitmaps = 20;
            if (Device.connectedDevice!.currentModeIndex < 1 || Device.connectedDevice!.currentModeIndex > 20)
            {
               Device.connectedDevice?.currentModeIndex = 1;
            }
            
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_LIMITS_VALUE), object: nil);
        }
        //progress += 0.04
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated);
        
            // only remove observers if this screen is being popped (i.e. the user is going back to the connection screen), because we want it to update the mimic devices on connection no matter what screen they connect on
        if (self.isMovingFromParentViewController)
        {
            print("Removing ModeTableViewController's observers (in viewWillDisappear)");
            NotificationCenter.default.removeObserver(self);
        }
        
    }
    
//    override func viewDidAppear(_ animated: Bool)
//    {
//        super.viewDidAppear(animated);
//    }
    
        // making sure we only setup after we have getLimits done, since that determines whether we need to go into standby mode
    @objc func prepareForSetup()
    {
            // reset progress bar, and show
        progress = 0;
        loadingProgressView.setProgress(0, animated: false);
            // configuring the style of the progress bar
        loadingProgressView.progressViewStyle = UIProgressView.Style.bar;
        loadingProgressView.isHidden = false;
        
        loadingLabel.text = "";
        loadingLabel.isHidden = false;
        
        
            // the total number of packets that must be received to fully load the mode table
        totalPacketsForSetup = 0;
        
        
        // making sure the main timer isn't running
        self.timer.invalidate();
        
        
        // if we have all the modes and thumbnails, we're ready to display them
        deviceHasModes = (Device.connectedDevice?.modes.count == Device.connectedDevice?.maxNumModes && Device.connectedDevice?.thumbnails.count == Device.connectedDevice?.maxBitmaps);
        
            // if we have a pre-existing mimic list, we want to go into a different state
        deviceHasMimicList = (Device.connectedDevice?.mimicList.count)! > 0;
        
            // if we didn't completely get the mode list & thumbnails (i.e. aren't totally ready to show modes)
        if (!deviceHasModes)
        {
            
            BLEConnectionTableViewController.CBCentralState = .READING_FROM_HARDWARE;
            print(BLEConnectionTableViewController.CBCentralState);
            
                // disabling the settings button when getting info
            self.navigationItem.rightBarButtonItem?.isEnabled = false;
            
                // if we still need to get bitmaps, we want to add that large number of packets to our total
            totalPacketsForSetup += Constants.BLE_PACKETS_PER_BITMAP * Device.connectedDevice!.maxBitmaps;
            
                // and if we still need to get modes, we also want to add those
            totalPacketsForSetup += Constants.BLE_PACKETS_PER_MODE * Device.connectedDevice!.maxNumModes;
            
                // and if we're using the standby brightness / standby modes, add those packets to our total (one to activate, one to deactivate)
            if (Constants.USE_STANDBY_MODE)
            {
                totalPacketsForSetup += 2;
            }
            if (Constants.USE_STANDBY_BRIGHTNESS)
            {
                totalPacketsForSetup += 2;
            }
            
                // and showing the loading label
            var newFrame = loadingItems.frame;
            newFrame.size.height = initialLoadingItemsHeight;
            loadingItems.frame = newFrame;
        }
        else
        {
            BLEConnectionTableViewController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
        }
        
            // if we haven't yet got the battery or brightness (it's still at its default -1), we need to add those packets too
        if (Device.connectedDevice!.batteryPercentage < 0)
        {
            totalPacketsForSetup += 1;
        }
        if (Device.connectedDevice!.brightness < 0)
        {
            totalPacketsForSetup += 1;
        }
        
        
        
        // clearing table data
        print("Wasn't ready to show modes, restarting getting data");
        
        modes = [Mode]();
        modeTableView.reloadData();
        
        
        if (Device.connectedDevice!.isDemoDevice)
        {
                // since it's a demo device, we have to fake getBattery and getBrightness, and skip all of those "get" steps
            Device.connectedDevice?.batteryPercentage = 100;
            Device.connectedDevice?.brightness = Constants.DEFAULT_BRIGHTNESS;
            
            Device.connectedDevice?.readyToShowModes = true;
        }
        else
        {
            // reset the flags, so we get all items
            Device.connectedDevice?.requestedName = false;
            Device.connectedDevice?.currentlyBuildingThumbnails = false;
            Device.connectedDevice?.requestedStandbyActivated = false;
            Device.connectedDevice?.requestedStandbyDeactivated = false;
            Device.connectedDevice?.requestedBrightnessChange = false;
            Device.connectedDevice?.requestedMode = false;
            //Device.connectedDevice?.readyToShowModes = false;
            Device.connectedDevice?.requestedBattery = false;
            Device.connectedDevice?.requestedBrightness = false;
            
            // we always want to do some setup, but if we already have modes / thumbnails it should be quick
            Device.connectedDevice?.readyToShowModes = false;
        }
        
        
        
            // disabling sleeping until loading is complete
        UIApplication.shared.isIdleTimerDisabled = true;
        
            // disabling user interaction with the empty TableView until loading is complete
        modeTableView.isUserInteractionEnabled = false;
        
        print("Setting timer");
        // Set the timer that governs the setup of the mode table
        self.timer = Timer.scheduledTimer(timeInterval: 0.04, target: self, selector: #selector(self.setUpTable), userInfo: nil, repeats: true);
        
    }
    
    @objc func setUpTable()
    {
            // update progress
        loadingProgressView.setProgress(progress, animated: true);
        
            // if it's ready to show modes, do so
        if ((Device.connectedDevice?.readyToShowModes)!)
        {
                // once loading of modes/thumbnails is done, save that Device
            saveDevice();
            
            // if we have a mimic list already, and we haven't asked what the user wants to do with it yet, ask what the user wants to do with it
            if (deviceHasMimicList && !Device.connectedDevice!.promptedMimicListSettings)
            {
                let dialogMessage = UIAlertController(title:"Mimic List Found", message: "A cached list of mimic devices was found.  Do you want to use the same mimic device list?.", preferredStyle: .alert);
                
                // defining the change settings button
                let changeSettings = UIAlertAction(title: "No, change list", style: .destructive, handler:
                {(action) -> Void in
                    
                    
                    // creating a temporary view controller of the mimic settings screen
                    let mimicSettingsVC = self.storyboard?.instantiateViewController(withIdentifier: "MimicTableViewController") as! MimicTableViewController;
                    
                    // pushing that view controller
                    _ = self.navigationController?.pushViewController(mimicSettingsVC, animated: true);
                    
                    print("settings changed");
                })
                
                // defining the keep settings button
                let keepSettings = UIAlertAction(title: "Yes, keep list", style: .default)
                { (action) -> Void in
                    print("mimic list kept");
                    //BLEConnectionTableViewController.CBCentralState = .SCANNING_FOR_MIMICS_TO_CONNECT;
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil);
                    //print(BLEConnectionTableViewController.CBCentralState);
                }
                
                // add the buttons to the message
                dialogMessage.addAction(keepSettings);
                dialogMessage.addAction(changeSettings);
                
                self.present(dialogMessage, animated: true, completion: nil);
                Device.connectedDevice!.promptedMimicListSettings = true;
            }
            else
            {
                Device.connectedDevice!.promptedMimicListSettings = true;
                //BLEConnectionTableViewController.CBCentralState = .NOT_SCANNING_FOR_MIMICS;
                //print(BLEConnectionTableViewController.CBCentralState);
            }
            
                // update the CBCentralState, depending on the length/status of the mimic list
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.UPDATE_CBCENTRAL_STATE), object: nil);
            
                // enabling the settings button when showing modes
            self.navigationItem.rightBarButtonItem?.isEnabled = true;
            
            self.timer.invalidate();
            print("Showing modes");
            loadingProgressView.setProgress(1, animated: true)
            loadingProgressView.isHidden = true;
            loadingLabel.isHidden = true;
            
                // if we're done loading, we want to get rid of the loading items (shrink them down)
            var newFrame = loadingItems.frame;
            newFrame.size.height = 0;
            loadingItems.frame = newFrame;
            
            
            
            //loadSampleModes(Device.connectedDevice?.maxNumModes ?? 4);
                // load up the modes stored on the device object
            modes = (Device.connectedDevice?.modes)!;
            
            // setting the inital mode of the Device
            Device.connectedDevice?.mode = modes[(Device.connectedDevice?.currentModeIndex)! - 1];
            
            let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
            
            modeTableView.reloadData();
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
            
                // re-enabling user interaction with the TableView since loading is complete
            modeTableView.isUserInteractionEnabled = true;
            
                // re-enabling sleeping since loading is complete
            UIApplication.shared.isIdleTimerDisabled = false;
            
        }
            // otherwise do preparatory steps, as long as a multi-message response isn't currently happening
        else if (Device.connectedDevice?.requestedThumbnail == false && Device.connectedDevice?.currentlyParsingName == false && Device.connectedDevice?.requestWithoutResponse == false)
        {
                // if getLimits hasn't received a value yet
            if ((Device.connectedDevice?.currentModeIndex)! < 0)
            {
                    // if we haven't already, getLimits for this device, so that we'll know it when we change it on the settings screen;  This should already be done, however, in viewDidLoad().  This is just in case that wasn't called somehow.
                if (!(Device.connectedDevice?.requestedLimits)!)
                {
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
                    Device.connectedDevice?.requestedLimits = true;
                    //progress += 0.4;
                }
                    // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
            else if (((Device.connectedDevice?.brightness)! < 0))
            {
                // if we haven't already, getBrightness for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice?.requestedBrightness)!)
                {
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS);
                    Device.connectedDevice?.requestedBrightness = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
            else if (Constants.USE_STANDBY_BRIGHTNESS && !deviceHasModes && !(Device.connectedDevice?.dimmedBrightnessForStandby)!)
            {
                if (!(Device.connectedDevice?.requestedBrightnessChange)!)
                {
                    // storing away the current brightness, so that we can re-apply it when the standby mode is over
                    Device.connectedDevice?.storedBrightness = (Device.connectedDevice?.brightness)!;
                    getValue(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInt: Constants.STANDBY_BRIGHTNESS)
                    Device.connectedDevice?.requestedBrightnessChange = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
                // if the device isn't in standby, but isn't ready to display modes, we need to put it in standby mode to get the modes / thumbnails
            else if (Constants.USE_STANDBY_MODE && !deviceHasModes && !(Device.connectedDevice?.isInStandby)!)
            {
                if (!(Device.connectedDevice?.requestedStandbyActivated)!)
                {
                        // turn on the standby mode (any value other than '0' is turning it on)
                    getValue(EnlightedBLEProtocol.ENL_BLE_SET_STANDBY, inputInt: 1);
                    Device.connectedDevice?.requestedStandbyActivated = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
            
            else if ((Device.connectedDevice?.batteryPercentage)! < 0)
            {
                // if we haven't already, getBatteryLevel for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice?.requestedBattery)!)
                {
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL);
                    Device.connectedDevice?.requestedBattery = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
                    // if we haven't gotten all the modes, keep chugging
            else if ((Device.connectedDevice?.modes.count)! < (Device.connectedDevice?.maxNumModes)!)
            {
                    // how much progress each Get Name is "worth"
                let progressValue: Float = 2 / Float(totalPacketsForSetup);
                
                    // if we haven't yet, request the name of the first mode we need
                if (!(Device.connectedDevice?.requestedName)!)
                {
                        // getting the name of the next Mode
                    loadingLabel.text = "Reading Mode \((Device.connectedDevice?.modes.count)! + 1) of \(Device.connectedDevice!.maxNumModes) from hardware";
                    
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_NAME, inputInt: (Device.connectedDevice?.modes.count)! + 1);
                    Device.connectedDevice?.requestedName = true;
                    Device.connectedDevice?.receivedName = false;
                    progress += progressValue;
                    //print("increasing progress by \(progressValue)");
                }
                    // if we're done getting the name but have not yet asked for the mode
                else if ((Device.connectedDevice?.receivedName)! && !(Device.connectedDevice?.requestedMode)!)
                {
                        // getting the details about the next Mode
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_MODE, inputInt: (Device.connectedDevice?.modes.count)! + 1);
                    Device.connectedDevice?.requestedMode = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
                // getting the thumbnails;
            else if ((Device.connectedDevice?.thumbnails.count)! < (Device.connectedDevice?.maxBitmaps)!)
            {
                Device.connectedDevice?.currentlyBuildingThumbnails = true;
                
                    // 4 packets per row
                let progressValue: Float = 4 / Float(totalPacketsForSetup);
                
                    // if we haven't already
                if (!(Device.connectedDevice?.requestedThumbnail)!)
                {
                    // if it's past the max, reset
                    if ((Device.connectedDevice?.thumbnailRowIndex)! >= 20)
                    {
                        Device.connectedDevice?.thumbnailRowIndex = 0;
                    }
                    
                    loadingLabel.text = "Reading Bitmap \((Device.connectedDevice?.thumbnails.count)! + 1) of \(Device.connectedDevice!.maxBitmaps) from hardware";
                    
                        // request the current thumbnail at the current row
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL, inputInt:  (Device.connectedDevice?.thumbnails.count)! + 1, secondInputInt: (Device.connectedDevice?.thumbnailRowIndex)!);
                    Device.connectedDevice?.requestedThumbnail = true;
                    
                    progress += progressValue;
                    //print("increasing progress by \(progressValue)");
                    
                    BLETimeoutTimer.invalidate();
                    BLETimeoutTimer = Timer.scheduledTimer(timeInterval: Constants.THUMBNAIL_ROW_TIMEOUT_TIME, target: self, selector: #selector(thumbnailTimeout), userInfo: nil, repeats: false);
                }
                return;
            }
                // if the Device is still dimmed, we want to set it back to its original brightness
            else if (Constants.USE_STANDBY_BRIGHTNESS && ((Device.connectedDevice?.dimmedBrightnessForStandby)! || Device.connectedDevice?.brightness == Constants.STANDBY_BRIGHTNESS))
            {
                    // we want to make sure we don't have thumbnail remnants if the "Get Thumbnail" process is interrupted
                Device.connectedDevice?.currentlyBuildingThumbnails = false;
                
                if !(Device.connectedDevice?.requestedBrightnessChange)!
                {
                    var brightness: Int;
                        // if we dimmed the brightness for a standby mode, then we have to set it back
                    if (!deviceHasModes)
                    {
                        brightness = (Device.connectedDevice?.storedBrightness)!
                        deviceHasModes = true;
                    }
                    else
                    {
                        brightness = Constants.DEFAULT_BRIGHTNESS;
                    }
                    
                        // set the brightness back to the initial pre-standby brightness we stored
                    
                    getValue(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInt: brightness);
                    Device.connectedDevice?.storedBrightness = -1;
                    Device.connectedDevice?.requestedBrightnessChange = true;
                    
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
                
            }
            else if (Constants.USE_STANDBY_MODE && (Device.connectedDevice?.isInStandby)!)
            {
                if !((Device.connectedDevice?.requestedStandbyDeactivated)!)
                {
                        // deactivating the standby mode
                    getValue(EnlightedBLEProtocol.ENL_BLE_SET_STANDBY, inputInt: 0);
                    Device.connectedDevice?.requestedStandbyDeactivated = true;
                    
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
                // once all setup is done, we are ready to show the modes
            else
            {
                Device.connectedDevice?.readyToShowModes = true;
            }
        }
//        else
//        {
//            //print("We're mid-parse of something, so don't request anything else;  requestedThumbnail?: \(Device.connectedDevice?.requestedThumbnail) currentlyParsingName?: \(Device.connectedDevice?.currentlyParsingName) requestWithoutResponse?: \(Device.connectedDevice?.requestWithoutResponse) ");
//        }
        
    }
    
    @objc func thumbnailTimeout()
    {
        if ((Device.connectedDevice?.requestedThumbnail)!)
        {
            let progressValue: Float = 4 / Float(totalPacketsForSetup);
            progress -= progressValue;
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RESEND_THUMBNAIL_ROW), object: nil);
        }
    }
    
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

        // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return (Device.connectedDevice?.modes.count)!;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ModeTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ModeTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of ModeTableViewCell");
        }

        let currentMode = (Device.connectedDevice?.modes[indexPath.row])!;
        
        
        cell.modeLabel.text = currentMode.name;
        cell.modeIndex.text = String(currentMode.index);
        cell.mode = currentMode;
        if (cell.mode?.index == Device.connectedDevice?.currentModeIndex)
        {
//            cell.setSelected(true, animated: true)
        }
        
        cell.updateImages();
        // Configure the cell...

        return cell
    }
    
    
        // MARK: - CBPeripheralManagerDelegate methods
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
        // MARK: - UITableDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        // When selecting a mode,
        
        // set the device's mode to that mode and update the index.
        Device.connectedDevice?.mode = modes[indexPath.row];
        Device.connectedDevice?.currentModeIndex = (Device.connectedDevice?.mode?.index)!;
        
            // don't set it on the physical peripheral if it's a demo device
        if !(Device.connectedDevice!.isDemoDevice)
        {
            updateModeOnHardware();
        }
        
    }
    
        // MARK: - BLE TX Methods
    
    @objc func updateModeOnHardware()
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
        
            // converting to an unsigned byte integer
        let modeIndexUInt: UInt8 = UInt8(Device.connectedDevice!.currentModeIndex);
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_MODE;// + "\(modeIndexUInt)";
        //print(valueString);
        let stringArray: [UInt8] = Array(valueString.utf8);
        let valueArray = stringArray + [modeIndexUInt]
            // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: valueArray.count)
        
        //print("\(String(describing: valueNSString))");
        //let valueNSData = valueNSString! + modeIndexUInt;
        //if let Device.connectedDevice!.txCharacteristic = txCharacteristic
        //{
        //print("sending " + valueString, Device.connectedDevice!.currentModeIndex, valueData, "to primary peripheral");
        
        
        
            // setting "active request" flag
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
        Device.connectedDevice?.requestedModeChange = true;
        
        //var mimicDevice: Device;
        
        
        
        //Device.connectedDevice!.peripheral.writeValue(valueNSString!, for: Device.connectedDevice!.txCharacteristic!, type:CBCharacteristicWriteType.withoutResponse)
        //}
    }
    
        // because changes like bitmaps aren't saved to the hardware, we have to re-set them from our memory once the mode has changed
    @objc func updateModeSettings()
    {
        if ((Device.connectedDevice?.mode?.usesBitmap)!)
        {
            setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
        }
        else
        {
            setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!)
        }
    }
    
        // needs to be done on selection so that it can match the phone
    func setBitmap(_ bitmapIndex: Int)
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
            return;
        }
        
        let bitmapIndexUInt: UInt8 = UInt8(bitmapIndex);
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BITMAP;// + "\(modeIndexUInt)";
        
        let stringArray: [UInt8] = Array(valueString.utf8);
        let valueArray = stringArray + [bitmapIndexUInt]
        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: valueArray.count)
        
        //print("sending: " + valueString, bitmapIndexUInt);
        
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
        
    }
    
    func setColors(color1: UIColor, color2: UIColor)
    {
        // checking for disconnection before using a BLE command
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
            return;
        }
        
        // creating variables for RGB values of color
        var red: CGFloat = 0;
        var green: CGFloat = 0;
        var blue: CGFloat = 0;
        var alpha: CGFloat = 0;
        
        // getting color1's RGB values (from 0 to 1.0)
        color1.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // scaling up to 255
        red *= 255;
        green *= 255;
        blue *= 255;
        
        // removing decimal places, removing signs, and making them UInt8s
        let red1 = convertToLegalUInt8(Int(red));
        let green1 = convertToLegalUInt8(Int(green));
        let blue1 = convertToLegalUInt8(Int(blue));
        
        // getting color2's RGB values
        color2.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // scaling up to 255
        red *= 255;
        green *= 255;
        blue *= 255;
        
        // removing decimal places, removing signs, and making them UInt8s
        let red2 = convertToLegalUInt8(Int(red));
        let green2 = convertToLegalUInt8(Int(green));
        let blue2 = convertToLegalUInt8(Int(blue));
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_COLOR;
        
        let stringArray: [UInt8] = Array(valueString.utf8);
        var valueArray = stringArray;
        valueArray += [red1];
        valueArray += [green1];
        valueArray += [blue1];
        valueArray += [red2];
        valueArray += [green2];
        valueArray += [blue2];
        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: valueArray.count)
        
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
    }
    
//    // old "initial selection" code
//    func tableView(_tableView: UITableView, willDisplayCell: ModeTableViewCell, forRowAtIndexPath: IndexPath)
//    {
//        // if the page is loading for the first time, select the first mode by default.
//        willDisplayCell.setSelected(true, animated: true);
//    }

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

        // credit to https://stackoverflow.com/questions/28471164/how-to-set-back-button-text-in-swift
    
    // before going to connection screen, remove observers
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
//    {
//        print("Removing ModeTableViewController's observers (in prepareForSegue)");
//        NotificationCenter.default.removeObserver(self);
//    }

    
    // MARK: Private Methods
    
        // takes an Int and makes sure it will fit in an unsigned Int8 (including calling abs())
    private func convertToLegalUInt8(_ value: Int) -> UInt8
    {
            // absolute value
        var output = abs(value);
        
        output = min(Int(UInt8.max), max(value, Int(UInt8.min)));
        
        return UInt8(output);
    }
    
        // sends get commands to the hardware, using the protocol as the inputString (and an optional int or two at the end, for certain getters)
    private func getValue(_ inputString: String, inputInt: Int = -1, secondInputInt: Int = -1)
    {
        if (!(Device.connectedDevice?.isConnected)!)
        {
            print("Device is not connected");
            return;
        }
        if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
        {
            print("Disconnected");
                // stop the setup process, if active
            timer.invalidate()
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
            return;
        }
        
        
        
            // if an input value was specified, especially for the getName/getMode commands, add it to the package
        if (inputInt != -1)
        {
            if (secondInputInt != -1)
            {
                let uInputInt: UInt8 = UInt8(inputInt);
                let secondUInputInt: UInt8 = UInt8(secondInputInt);
                let stringArray: [UInt8] = Array(inputString.utf8);
                let outputArray = stringArray + [uInputInt] + [secondUInputInt];
                let outputData = NSData(bytes: outputArray, length: outputArray.count)
                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
            }
            else
            {
                let uInputInt: UInt8 = UInt8(inputInt);
                let stringArray: [UInt8] = Array(inputString.utf8);
                let outputArray = stringArray + [uInputInt];
                let outputData = NSData(bytes: outputArray, length: outputArray.count)
                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
            }
        }
        else
        {
            let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
            // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
            BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: inputNSString! as NSData, sendToMimicDevices: false);
        }
    }
    
        // saves the Device after loading
    private func saveDevice()
    {
            // never save the demo device
        if (Device.connectedDevice!.isDemoDevice)
        {
            print("Demo device, not caching");
            return;
        }
        
        if !(Device.connectedDevice?.modes.count == Device.connectedDevice?.maxNumModes && Device.connectedDevice?.thumbnails.count == Device.connectedDevice?.maxBitmaps)
        {
            print("Not a full cache, not caching");
            return;
        }
        var cachedDevices: [Device] = loadDevices() ?? [Device]();
            // if there aren't any saved devices, save them now
        
            // if there's an old save with the same NSUUID, override it
        if let indexOfDevice = cachedDevices.firstIndex(where: {$0.UUID == Device.connectedDevice?.peripheral.identifier as NSUUID?})
        {
            cachedDevices[indexOfDevice] = Device.connectedDevice!
            print("Just updated the cache for \(Device.connectedDevice!.name)");
                // clearing out duplicates
//            var j = (cachedDevices.count - 1);
//
//            for i in indexOfDevice...(cachedDevices.count - 1)
//            {
//                if (cachedDevices[j].name == Device.connectedDevice?.name)
//                {
//                    cachedDevices.remove(at: j);
//                }
//
//                j -= 1;
//            }
        }
            // otherwise add it
        else
        {
            cachedDevices += [Device.connectedDevice!];
            print("Caching a completely new device");
        }
        
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(cachedDevices, toFile: Device.ArchiveURL.path);
        if isSuccessfulSave {
            os_log("Devices successfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save devices...", log: OSLog.default, type: .error)
        }
    }
    
    private func loadDevices() -> [Device]?
    {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Device.ArchiveURL.path) as? [Device];
    }
    
    
        // loads placeholder modes, up till the max mode count from getLimits (no longer necessary with "Get Mode")
    private func loadSampleModes(_ numberOfModes: Int)
    {
        // colors for certain modes
        let colorArray1 = [UIColor.green, UIColor.yellow];
        let colorArray2 = [UIColor.cyan, UIColor.blue];
        let bitmap1 = UIImage(named: "Bitmap1");
        let bitmap2 = UIImage(named: "Bitmap2");
        
        if (numberOfModes >= 1)
        {
            guard let mode1 = Mode(name:"SLOW TWINKLE", index: 1, usesBitmap: false, bitmap: nil, colors: colorArray1) else
            {
                fatalError("unable to instantiate mode1");
            }
            modes += [mode1];
        }
        
        if (numberOfModes >= 2)
        {
            guard let mode2 = Mode(name:"MEDIUM TWINKLE", index: 2, usesBitmap: false, bitmap: nil, colors: colorArray2) else
            {
                fatalError("unable to instantiate mode2");
            }
            modes += [mode2];
        }
        
        if (numberOfModes >= 3)
        {
            guard let mode3 = Mode(name:"FAST TWINKLE", index: 3, usesBitmap: true, bitmap: bitmap1, colors: [nil]) else
            {
                fatalError("unable to instantiate mode3");
            }
            modes += [mode3];
        }
        
        
        if (numberOfModes >= 4)
        {
            guard let mode4 = Mode(name:"EXTREMELY LONG TEST NAME (2 Lines)", index: 4, usesBitmap: true, bitmap: bitmap2, colors: [nil]) else
            {
                fatalError("unable to instantiate mode4");
            }
            modes += [mode4];
        }
        
        if (numberOfModes > 4)
        {
            for index in 5...numberOfModes
            {
                //let colorArray = [UIColor.black, UIColor.white];
                guard let mode = Mode(name: "mode\(index)", index: index, usesBitmap: true, bitmap: bitmap2, colors: [nil]) else
                {
                    fatalError("unable to instantiate mode\(index)");
                }
                modes += [mode];
            }
        }
        
        //4modes += [mode1, mode2, mode3, mode4];
        
    }

}

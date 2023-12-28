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
    
    var thumbnailCount: Int = 0;
    
        // list of modes
    var modes = [Mode]();
    
        // timer to set up mode table
    var timer = Timer();
    
        // timer to check BLE timeout, especially when fetching bitmaps
    var BLETimeoutTimer = Timer();
    
        // separate timer for querying the hardware version, as only the nRF51822 will respond
    var BLEVersionTimer = Timer();
    
        // seperate timer for querying the crossfade support, since only recent firmware will respond
    var BLECrossfadeTimer = Timer();
    
        // list of workItems for setting palettes so we can cancel any that we might not need
    var workItems = [DispatchWorkItem]();
    
    // A timer to introduce a delay for older hardware
    var delayTimer = Timer();
    
        // FIX-`ME: temporary variables for testing bad ascii characters on the nRF51822
//    var brightnessTestingTimer = Timer();
//    var brightnessCounter = 0;
//    var startedTimer = false;
    
        // used in timing how long reloading modes takes
    var reloadStopwatch = Date()
    
        // a timer to see how long the Thumbnails take to load
    var thumbnailStopwatch = Date();
    
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

            // making sure observers are only added once
        NotificationCenter.default.addObserver(self, selector: #selector(updateModeSettings), name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_MODE_VALUE), object: nil)
        
        //NotificationCenter.default.addObserver(self, selector: #selector(setSecondColorOnNRF51822), name: Notification.Name(rawValue: Constants.MESSAGES.CHANGED_FIRST_COLOR), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(prepareForSetup), name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_LIMITS_VALUE), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(restartBLERxTimeoutTimer), name: Notification.Name(rawValue: Constants.MESSAGES.RESTART_BLE_RX_TIMEOUT_TIMER), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(stopBLERxTimeoutTimer), name: Notification.Name(rawValue: Constants.MESSAGES.STOP_BLE_RX_TIMEOUT_TIMER), object: nil)
            // when we connect to a new device (like a mimic), send the current mode settings
        //NotificationCenter.default.addObserver(self, selector: #selector(updateModeOnHardware), name: Notification.Name(rawValue:  Constants.MESSAGES.DISCOVERED_MIMIC_CHARACTERISTICS), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(requestNextDataWithDelay), name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(saveDevice), name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil)
        
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
        
        // getLimits for this device, though not if it's a demo device
        if !(Device.connectedDevice!.isDemoDevice)
        {
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
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
        
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
        print("View will appear is called");
        
            // reset progress bar, and show
        progress = 0;
        loadingProgressView.setProgress(0, animated: false);
            // configuring the style of the progress bar
        loadingProgressView.progressViewStyle = UIProgressView.Style.bar;
        loadingProgressView.isHidden = false;
        
        if (Device.connectedDevice!.maxNumModes > 0)
        {
            //deviceHasModes = (Device.connectedDevice!.modes.count >= Device.connectedDevice!.maxNumModes) && (Device.connectedDevice!.thumbnails.count >= Device.connectedDevice!.maxBitmaps);
            
                // if we're reverting the modes
            //if (!(deviceHasModes) || Device.connectedDevice!.isDemoDevice)
            //{
            prepareForSetup();
            //}
        }
        
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
        
        print("preparing for setup");
        
        loadingLabel.text = "";
        loadingLabel.isHidden = false;
        
        
            // the total number of packets that must be received to fully load the mode table
        totalPacketsForSetup = 0;
        
        
        // making sure the main timer isn't running
        self.timer.invalidate();
        
        
        // if we have all the modes and thumbnails, we're ready to display them
        deviceHasModes = (Device.connectedDevice!.modes.count >= Device.connectedDevice!.maxNumModes) && (Device.connectedDevice!.thumbnails.count >= Device.connectedDevice!.maxBitmaps);
        
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
            totalPacketsForSetup += Constants.BLE_PACKETS_PER_BITMAP * (Device.connectedDevice!.maxBitmaps - Device.connectedDevice!.thumbnails.count);
            
                // and if we still need to get modes, we also want to add those
            totalPacketsForSetup += Constants.BLE_PACKETS_PER_MODE * (Device.connectedDevice!.maxNumModes - Device.connectedDevice!.modes.count);
            
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
        
            // if we haven't yet got the battery, brightness, or crossfade (it's still at its default -1), we need to add those packets too
        if (Device.connectedDevice!.batteryPercentage < 0)
        {
            totalPacketsForSetup += 1;
        }
        if (Device.connectedDevice!.brightness < 0)
        {
            totalPacketsForSetup += 1;
        }
        if (Device.connectedDevice!.crossfade < 0)
        {
            totalPacketsForSetup += 1;
        }
            // same with the hardware version
        
        if (Device.connectedDevice!.hardwareVersion == Constants.HARDWARE_VERSION.UNKNOWN)
        {
            totalPacketsForSetup += 1;
        }
        
        
        
        // clearing table data
        //print("Wasn't ready to show modes, restarting getting data");
        
        modes = [Mode]();
        modeTableView.reloadData();
        
        
        if (Device.connectedDevice!.isDemoDevice)
        {
                // since it's a demo device, we have to fake getBattery and getBrightness, and skip all of those "get" steps
            Device.connectedDevice?.batteryPercentage = 100;
            Device.connectedDevice?.brightness = Constants.DEFAULT_BRIGHTNESS;
            Device.connectedDevice?.crossfade = Constants.DEFAULT_CROSSFADE;
            
            Device.connectedDevice?.readyToShowModes = true;
        }
        else
        {
            // reset the flags, so we get all items
            Device.connectedDevice!.expectedPacketType = "";
            
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
        
        requestNextData();
        
        //print("Setting timer");
        reloadStopwatch = Date();
        
            // MARK: Starting profiling / BLE Log stopwatch
        if (Device.profiling && !deviceHasModes && !Device.currentlyProfiling)
        {
            Device.fileTimeStamp = (Date());
            
            
            Device.mainProfilerFileName = "main_\(Device.formatFilenameTimestamp(Device.fileTimeStamp)).csv";
            Device.mainProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Device.mainProfilerFileName);
            
            Device.rxProfilerFileName = "rx_\(Device.formatFilenameTimestamp(Device.fileTimeStamp)).csv";
            Device.rxProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Device.rxProfilerFileName);
            
            Device.txProfilerFileName = "tx_\(Device.formatFilenameTimestamp(Device.fileTimeStamp)).csv";
            Device.txProfilerPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Device.txProfilerFileName);
            
            Device.lastTimestamp = 0.0;
            Device.lastTxTimestamp = 0.0;
            Device.numTimeouts = 0;
            Device.profilerStopwatch = Date();
            Device.currentlyProfiling = true;
        }
        // Set the timer that governs the setup of the mode table
            // FIXME: trying to see what went wrong on the nRF8001
        //self.timer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.setUpTable), userInfo: nil, repeats: true);
    }
    
    @objc func requestNextData()
    {
            // update progress
        loadingProgressView.setProgress(progress, animated: true);
        
            // if it's ready to show modes, do so
        if ((Device.connectedDevice?.readyToShowModes)!)
        {
                // once loading of modes/thumbnails is done, save that Device
            saveDevice();
            
                // deactivate the timeout timer
            BLETimeoutTimer.invalidate();
            
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
            
            
                // load up the modes stored on the device object
            modes = (Device.connectedDevice?.modes)!;
            
                // setting the inital mode of the Device
            Device.connectedDevice?.mode = modes[(Device.connectedDevice?.currentModeIndex)! - 1];
            
                // displaying how long it took to reload the modes
            let diff = Date().timeIntervalSince(reloadStopwatch);
            print("");
            print("");
            print("*********************              Reloading the modes took \(diff) seconds.");
            print("");
            print("");
            print("Current status of emptyPalettes is: ", Device.connectedDevice?.emptyPalettes ?? [69]);
            
            // MARK: profiling: completing file
            if (Device.profiling && Device.currentlyProfiling)
            {
                if (ModeTableViewController.saveBLELog())
                {
                    let vc = UIActivityViewController(activityItems: [Device.mainProfilerPath!, Device.rxProfilerPath!, Device.txProfilerPath!], applicationActivities: []);
                    present(vc, animated: true, completion: nil);
                }
            }
            
            let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
            
            modeTableView.reloadData();
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
            
                // re-enabling user interaction with the TableView since loading is complete
            modeTableView.isUserInteractionEnabled = true;
            
                // re-enabling sleeping since loading is complete
            UIApplication.shared.isIdleTimerDisabled = false;
            
        }
            // otherwise do preparatory steps, as long as a multi-message response isn't currently happening
        else if (Device.connectedDevice!.expectedPacketType.elementsEqual("") && Device.connectedDevice?.requestWithoutResponse == false)
        {
            // FIX-ME: debugging bad ASCII characters for the nRF51822
//            if Device.connectedDevice!.brightness >= 255
//            {
//                    // set brightness to 0
//                getValue(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInt: 0)
//            }
//            else if Device.connectedDevice!.brightness < 255
//            {
//                if (!startedTimer)
//                {
//                    brightnessCounter = 0;
//                    brightnessTestingTimer.invalidate();
//                    brightnessTestingTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.testBrightness), userInfo: nil, repeats: true);
//                    startedTimer = true
//                }
//
//            }
//            return;
            // FIX-ME: Remove up to here for actual app
                // if getLimits hasn't received a value yet
            if ((Device.connectedDevice?.currentModeIndex)! < 0)
            {
                    // if we haven't already, getLimits for this device, so that we'll know it when we change it on the settings screen;  This should already be done, however, in viewDidLoad().  This is just in case that wasn't called somehow.
                if (!(Device.connectedDevice?.requestedLimits)!)
                {
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
                    Device.connectedDevice?.requestedLimits = true;
                    //progress += 0.4;
                }
                    // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
                // MARK: Hardware Version
            else if (((Device.connectedDevice?.hardwareVersion)! == .UNKNOWN))
            {
                // if we haven't already, get the hardware version for this device
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_VERSION)))
                {
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_VERSION);
                    //Device.connectedDevice?.requestedVersion = true;
                    progress += 1 / Float(totalPacketsForSetup);
                    BLEVersionTimer.invalidate();
                    BLEVersionTimer = Timer.scheduledTimer(timeInterval: Constants.VERSION_TIMEOUT_TIME, target: self, selector: #selector(versionTimeout), userInfo: nil, repeats: false);
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
            else if (((Device.connectedDevice?.brightness)! < 0))
            {
                // if we haven't already, getBrightness for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS)))
                {
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS);
                    //Device.connectedDevice?.requestedBrightness = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
            else if (((Device.connectedDevice?.crossfade)! < 0) && !(Device.connectedDevice!.checkedCrossfade))
            {
                // same for crossfade value
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE)) && !(Device.connectedDevice!.checkedCrossfade))
                {
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE);
                    progress += 1 / Float(totalPacketsForSetup);
                    BLECrossfadeTimer.invalidate();
                    BLECrossfadeTimer = Timer.scheduledTimer(timeInterval: Constants.CROSSFADE_TIMEOUT_TIME, target: self, selector: #selector(crossfadeTimeout), userInfo: nil, repeats: false);
                }
                
                return;
            }
            else if (Constants.USE_STANDBY_BRIGHTNESS && !deviceHasModes && !(Device.connectedDevice?.dimmedBrightnessForStandby)!)
            {
                if (!(Device.connectedDevice?.requestedBrightnessChange)!)
                {
                    // storing away the current brightness, so that we can re-apply it when the standby mode is over
                    Device.connectedDevice?.storedBrightness = (Device.connectedDevice?.brightness)!;
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInts: [Constants.STANDBY_BRIGHTNESS], digitsPerInput: 3)
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
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_STANDBY, inputInts: [1], digitsPerInput: 1);
                    Device.connectedDevice?.requestedStandbyActivated = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
            
            else if ((Device.connectedDevice?.batteryPercentage)! < 0)
            {
                // if we haven't already, getBatteryLevel for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL)))
                {
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL);
                    //Device.connectedDevice?.requestedBattery = true;
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
                
                // FIXME: Debugging nRF51822, skipping "!GN10"
//                if (Device.connectedDevice?.hardwareVersion == .NRF51822 && ((Device.connectedDevice?.modes.count)! + 1 == 10 || (Device.connectedDevice?.modes.count)! + 1 == 13))
//                {
//                    let currentIndex = (Device.connectedDevice?.modes.count)! + 1;
//
//                    Device.connectedDevice?.modes += [Mode(name: "ERROR", index: currentIndex, usesBitmap: true, bitmapIndex: 1, colors: [nil])!];
//                    progress += 3 / Float(totalPacketsForSetup);
//
//                        // if this would complete our set of modes, return
//                    if ((Device.connectedDevice?.modes.count)! >= (Device.connectedDevice?.maxNumModes)!)
//                    {
//                        return;
//                    }
//                }
                
                    // if we're done getting the name but have not yet asked for the mode
                if ((Device.connectedDevice?.receivedName)! && (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_MODE))))
                {
                                    // getting the details about the next Mode
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_MODE, inputInts: [(Device.connectedDevice?.modes.count)! + 1]);
                    Device.connectedDevice?.receivedName = false;
                    
                    //Device.connectedDevice?.requestedMode = true;
                    progress += 1 / Float(totalPacketsForSetup);
                }
                    // if we haven't yet, request the name of the first mode we need
                else if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_NAME)))
                {
                        // getting the name of the next Mode
                    loadingLabel.text = "Reading Mode \((Device.connectedDevice?.modes.count)! + 1) of \(Device.connectedDevice!.maxNumModes) from hardware";
                    
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_NAME, inputInts: [(Device.connectedDevice?.modes.count)! + 1]);
                    //Device.connectedDevice?.requestedName = true;
                    //Device.connectedDevice?.receivedName = false;
                    progress += progressValue;
                    //print("increasing progress by \(progressValue)");
                }
                
                return;
            }
                // getting the thumbnails;
            else if ((Device.connectedDevice?.thumbnails.count)! < (Device.connectedDevice?.maxBitmaps)!)
            {
                Device.connectedDevice?.currentlyBuildingThumbnails = true;
                
                    // 4 packets per row
                let progressValue: Float = 4 / Float(totalPacketsForSetup);
                
                    // FIXME: nRF51822-specific bug, skipping thumbnails 10 and 13
//                if (Device.connectedDevice?.hardwareVersion == .NRF51822 && ((Device.connectedDevice?.thumbnails.count)! + 1 == 10 || (Device.connectedDevice?.thumbnails.count)! + 1 == 13))
//                {
//                    let errorBitmap = UIImage(named: "Bitmap2")!;
//                    Device.connectedDevice?.thumbnails.append(errorBitmap);
//                    progress += progressValue * 20;
//                    if ((Device.connectedDevice?.thumbnails.count)! >= (Device.connectedDevice?.maxBitmaps)!)
//                    {
//                        return;
//                    }
//                }
                
                    // if we haven't already
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL)))
                {
                    // if it's past the max, reset
                    if ((Device.connectedDevice?.thumbnailRowIndex)! >= 20)
                    {
                        thumbnailStopwatch = Date();
                        Device.connectedDevice?.thumbnailRowIndex = 0;
                    }
                    
                    // if we've loaded an entire thumbnail, reset the thumbnail stopwatch
                    if (((Device.connectedDevice?.thumbnails.count)!) > thumbnailCount)
                    {
                        thumbnailCount = (Device.connectedDevice?.thumbnails.count)!;
                        thumbnailStopwatch = Date();
                    }
                    
                    let diff = Date().timeIntervalSince(thumbnailStopwatch);
                    print("Loading one full thumbnail: \(diff) seconds")
                    
                    loadingLabel.text = "Reading Bitmap \((Device.connectedDevice?.thumbnails.count)! + 1) of \(Device.connectedDevice!.maxBitmaps) from hardware";
                    
                    //thumbnailStopwatch = Date();
                    
                    if(Device.connectedDevice?.hardwareVersion == .FASTNRF51822)
                    {
                        print("DETECTED FAST NRF51822");
                        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_TOTAL_THUMBNAIL, inputInts:
                            [(Device.connectedDevice?.thumbnails.count)! + 1]);
                        progress += progressValue * 20;
                    }
                    else
                    {
                        // request the current thumbnail at the current row
                        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL, inputInts:  [(Device.connectedDevice?.thumbnails.count)! + 1, (Device.connectedDevice?.thumbnailRowIndex)!]);
                            progress += progressValue;
                        //Device.connectedDevice?.requestedThumbnail = true;
                    }
                    thumbnailCount = (Device.connectedDevice?.thumbnails.count)!;
                    
                    //progress += progressValue;
                    //print("increasing progress by \(progressValue)");
                    
                    
                }
                return;
            }
            // getting the palettes
            else if ((Device.connectedDevice?.emptyPalettes.count)! > 0)
            {
                print("we have empty palettes");
                print("looking for palettes - expected packet type is: ", Device.connectedDevice!.expectedPacketType);
                //bookmark
                // if we aren't already asking for a palette
                if (!(Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_PALETTE)))
                {
                    // get the first palette from the list of ones we need - since we need a reference to the index number when parsing the palette out, we'll deal with removing those indexes from the array in the parsing phase
                    print("asking for a palette");
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_PALETTE, inputInts: [(Device.connectedDevice?.emptyPalettes[0])!]);
                }
                // if we're already asking, return and wait for the reponse
                return;
            }
                // if the Device is still dimmed, we want to set it back to its original brightness
            else if (Constants.USE_STANDBY_BRIGHTNESS && ((Device.connectedDevice?.dimmedBrightnessForStandby)!))
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
                    
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInts: [brightness], digitsPerInput: 3);
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
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_STANDBY, inputInts: [0], digitsPerInput: 1);
                    Device.connectedDevice?.requestedStandbyDeactivated = true;
                    
                    progress += 1 / Float(totalPacketsForSetup);
                }
                
                return;
            }
                // once all setup is done, we are ready to show the modes
            else
            {
                Device.connectedDevice?.readyToShowModes = true;
                requestNextData();
            }
        }
//        else
//        {
//            //print("We're mid-parse of something, so don't request anything else;  requestedThumbnail?: \(Device.connectedDevice?.requestedThumbnail) currentlyParsingName?: \(Device.connectedDevice?.currentlyParsingName) requestWithoutResponse?: \(Device.connectedDevice?.requestWithoutResponse) ");
//        }
        
    }
    
    @objc func bleMessageTimeout()
    {
        Device.reportError(Constants.TIMEOUT_BEFORE_RECEIVING_COMPLETE_MESSAGE);
        
            // MARK: logging timeouts
        if (Device.profiling && Device.currentlyProfiling)
        {
            var commandString = "TIMEOUT";
            let duration = (Date().timeIntervalSince(Device.profilerStopwatch) - Device.lastTimestamp) * 1000;
            let messageDuration = (Date().timeIntervalSince(Device.profilerStopwatch) - Device.lastTxTimestamp) * 1000;
            //Device.lastTimestamp = Date().timeIntervalSince(Device.profilerStopwatch);
            //commandString += (inputInts.map { String($0) }.joined(separator: " "));
            let newMainLine = "\(commandString),\(Date().timeIntervalSince(Device.profilerStopwatch)),\(4),\(duration),\(messageDuration)\n";
            //let newTxLine = "\(commandString),\(duration)\n";
            Device.mainCsvText.append(contentsOf: newMainLine);
            Device.numTimeouts += 1;
            //Device.txCsvText.append(contentsOf: newTxLine);
        }
        
            // if we were loading a bitmap row (the most common time this occurs)
        if (Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL))
        {
            print(" ")
            print(" ^   ^   ^   ^   ^   ^   ^   ^   ^   ^   ^   ^   ^")
            print("********** Thumbnail request timed out ***********")
            print(" ")
            let progressValue: Float = 4 / Float(totalPacketsForSetup);
            progress -= progressValue;
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RESEND_THUMBNAIL_ROW), object: nil);
        }
            // otherwise, if we were loading modes/bitmaps
        else if (!Device.connectedDevice!.readyToShowModes && Device.connectedDevice!.maxNumModes > 0)
        {
            print("Last request timed out.")
                // decrementing the progress bar
            let progressValue: Float = 1 / Float(totalPacketsForSetup);
            
                // since a name is worth two "packets" in the eyes of the progress bar, we have to set it back an additional packet
            if (Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_NAME))
            {
                progress -= progressValue;
            }
            progress -= progressValue;
            Device.connectedDevice!.requestWithoutResponse = false;
            
            Device.connectedDevice!.expectedPacketType = "";
            
            if (Device.connectedDevice!.isConnected)
            {
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
            }
            else
            {
                print("Since the device is disconnected, we won't ask it for anything anymore");
            }
            
            
        }
    }
    
        // the version query will not receive a response if it's the nRF8001 ("v1") hardware, so we will act accordingly
    @objc func versionTimeout()
    {
        //print("Reached version timeout function, and currently the version has been requested: \((Device.connectedDevice?.requestedVersion)!) and the hardware is unknown: \(Device.connectedDevice!.hardwareVersion == .UNKNOWN)")
        if ((Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_VERSION)) && Device.connectedDevice!.hardwareVersion == .UNKNOWN)
        {
            Device.connectedDevice?.hardwareVersion = .NRF8001;
            Device.connectedDevice?.requestWithoutResponse = false;
            Device.connectedDevice!.expectedPacketType = "";
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
            //print("Changed device's hardware version variable to \(String(describing: Device.connectedDevice?.hardwareVersion))")
        }
    }
    
    @objc func crossfadeTimeout()
    {
        if ((Device.connectedDevice!.expectedPacketType.elementsEqual(EnlightedBLEProtocol.ENL_BLE_GET_CROSSFADE)) && Device.connectedDevice!.checkedCrossfade == false)
        {
            print("No Crossfade Support Found");
            Device.connectedDevice!.supportsCrossfade = false;
            Device.connectedDevice!.requestWithoutResponse = false;
            Device.connectedDevice!.expectedPacketType = "";
            Device.connectedDevice!.checkedCrossfade = true;
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET), object: nil);
        }
    }
    
    @objc func requestNextDataWithDelay()
    {

            // resetting the timeout timer so it doesn't count the delay time
        BLETimeoutTimer.invalidate();
        
        if (Device.connectedDevice!.hardwareVersion == .NRF8001)
        {
            delayTimer.invalidate();
            //os_log("Since we're using older hardware, delaying message", log: OSLog.default, type: .debug);
            delayTimer = Timer.scheduledTimer(withTimeInterval: Constants.NRF8001_DELAY_TIME, repeats: false)
            { timer in
                //os_log("Sending message", log: OSLog.default, type: .debug);
                self.requestNextData();
            }
        }
        else
        {
            print("requesting next data");
            requestNextData();
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
        return (min(Device.connectedDevice!.modes.count, Device.connectedDevice!.maxNumModes));
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ModeTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ModeTableViewCell else
        {
            Device.reportError(Constants.FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MODE_TABLE);
            fatalError("The dequeued cell is not an instance of ModeTableViewCell");
        }

        
        // in case the mode has an illegal bitmap index, set it to 1
        if ((Device.connectedDevice?.modes[indexPath.row].usesBitmap)!)
        {
            //print("Checking each bitmap mode for bitmap index legality")
            //print("Mode \(Device.connectedDevice!.modes[indexPath.row].name), at index \(indexPath.row), has bitmap index \(Device.connectedDevice!.modes[indexPath.row].bitmapIndex) compared to max \(Device.connectedDevice!.maxBitmaps)")
            if ((Device.connectedDevice?.modes[indexPath.row].bitmapIndex)! > Device.connectedDevice!.maxBitmaps)
            {
                //print("Found a mode named \(Device.connectedDevice?.modes[indexPath.row].name) with an illegal bitmap index, setting to 1");
                Device.connectedDevice?.modes[indexPath.row].bitmapIndex = 1;
            }
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
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_MODE, inputInts: [Device.connectedDevice!.currentModeIndex], sendToMimicDevices: true)
        
    }
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
//            // converting to an unsigned byte integer
//        let modeIndexUInt: UInt8 = UInt8(Device.connectedDevice!.currentModeIndex);
//
//        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_MODE;// + "\(modeIndexUInt)";
//        //print(valueString);
//        let stringArray: [UInt8] = Array(valueString.utf8);
//        let valueArray = stringArray + [modeIndexUInt]
//            // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
//        let valueData = NSData(bytes: valueArray, length: valueArray.count)
//
//        //print("\(String(describing: valueNSString))");
//        //let valueNSData = valueNSString! + modeIndexUInt;
//        //if let Device.connectedDevice!.txCharacteristic = txCharacteristic
//        //{
//        //print("sending " + valueString, Device.connectedDevice!.currentModeIndex, valueData, "to primary peripheral");
//
//
//
//            // setting "active request" flag
//        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
//        Device.connectedDevice?.requestedModeChange = true;
//
//        //var mimicDevice: Device;
//
//
//
//        //Device.connectedDevice!.peripheral.writeValue(valueNSString!, for: Device.connectedDevice!.txCharacteristic!, type:CBCharacteristicWriteType.withoutResponse)
//        //}
//    }
    
        // because changes like bitmaps aren't saved to the hardware, we have to re-set them from our memory once the mode has changed
    @objc func updateModeSettings(_ notification: Notification)
    {
        if let data = notification.userInfo as? [Int: NSUUID]
        {
            print("Received peripheral data from NotificationCenter");
            let id = data[0];
            for mimicDevice in Device.connectedDevice!.connectedMimicDevices
            {
                if mimicDevice.peripheral.identifier as NSUUID == id
                {
                    if ((Device.connectedDevice?.mode?.usesBitmap)!)
                    {
                        setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!, toSingleDevice: mimicDevice);
                    }
                    else if ((Device.connectedDevice?.mode?.usesPalette)!)
                    {
                        setAllPaletteColors();
                    }
                    else
                    {
                        setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!, toSingleDevice: mimicDevice);
                    }
                    return;
                }
            }
            
                // otherwise if it's the primary device
            if (Device.connectedDevice!.peripheral.identifier as NSUUID == id)
            {
                if ((Device.connectedDevice?.mode?.usesBitmap)!)
                {
                    setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!, toSingleDevice: Device.connectedDevice!);
                }
                else if ((Device.connectedDevice?.mode?.usesPalette)!)
                {
                    setAllPaletteColors();
                }
                else
                {
                    setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!, toSingleDevice: Device.connectedDevice!)
                }
            }
        }
        else
        {
            if ((Device.connectedDevice?.mode?.usesBitmap)!)
            {
                setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
            }
            else if ((Device.connectedDevice?.mode?.usesPalette)!)
            {
                setAllPaletteColors();
            }
            else
            {
                setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!)
            }
        }
    }
    
        // since "Set Colors" has to be sent in two packets on the nRF51822 (as of 1.0.33, no longer necessary)
//    @objc func setSecondColorOnNRF51822()
//    {
//        if (!Device.connectedDevice!.mode!.usesBitmap)
//        {
//            setColor(colorIndex: 2, color: (Device.connectedDevice?.mode?.color2)!)
//
//            saveDevice();
//        }
//    }
    
        // needs to be done on selection so that it can match the phone
    func setBitmap(_ bitmapIndex: Int, toSingleDevice: Device? = nil)
    {
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_BITMAP, inputInts: [bitmapIndex], sendToMimicDevices: false, toSingleDevice: toSingleDevice)
    }
        
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
//            return;
//        }
//
//        let bitmapIndexUInt: UInt8 = UInt8(bitmapIndex);
//
//        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BITMAP;// + "\(modeIndexUInt)";
//
//        let stringArray: [UInt8] = Array(valueString.utf8);
//        let valueArray = stringArray + [bitmapIndexUInt]
//        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
//        let valueData = NSData(bytes: valueArray, length: valueArray.count)
//
//        //print("sending: " + valueString, bitmapIndexUInt);
//
//        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
//
//    }
        // the setColor command for the nRF51822, which can only set one at a time
//    func setColor(colorIndex: Int, color: UIColor, setBothColors: Bool = false)
//    {
//        if (setBothColors)
//        {
//            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: [1] + convertUIColorToIntArray(color), digitsPerInput: 3, sendToMimicDevices: true)
//                // setting flag
//            Device.connectedDevice?.requestedFirstOfTwoColorsChanged = true;
//        }
//        else
//        {
//            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: [colorIndex] + convertUIColorToIntArray(color), digitsPerInput: 3, sendToMimicDevices: true)
//        }
//
//    }
    
        // the setColors command for the nRF8001, which can set both simultaneously
    func setColors(color1: UIColor, color2: UIColor, toSingleDevice: Device? = nil)
    {
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: convertUIColorToIntArray(color1) + convertUIColorToIntArray(color2), digitsPerInput: 3, sendToMimicDevices: false, toSingleDevice: toSingleDevice)
        
    }
    
    private func setAllPaletteColors()
    {
        var colorInts = [Int]();
        var outputs = [[Int]]();
        //cancel any remaining work items before clearing the array
        for workItem in workItems {
            workItem.cancel();
        }
        var delay = 0.0;
        workItems = [DispatchWorkItem]();
        for i in 0...15
        {
            colorInts += Device.convertUIColorToIntArray((Device.connectedDevice?.mode?.paletteColors![i])!);
            if ((i+1) % 4 == 0)
            {
                outputs += [colorInts];
                colorInts = [Int]();
                switch i
                {
                case 3:
                    formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE1, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                case 7:
                    let workItemRow2: DispatchWorkItem = DispatchWorkItem(block: {
                        self.formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE2, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    })
                    workItems.append(workItemRow2);
                    if ((Device.connectedDevice?.requestWithoutResponse)! || ((Device.connectedDevice?.connectedMimicDevices.count)! > 0))
                    {
                        delay += 0.2
                        print(delay);
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItemRow2);
                    }
                    else
                    {
                        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE2, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    }
                    
                case 11:
                    let workItemRow3: DispatchWorkItem = DispatchWorkItem(block: {
                        self.formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE3, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    })
                    workItems.append(workItemRow3);
                    if ((Device.connectedDevice?.requestWithoutResponse)!)
                    {
                        delay += 0.2
                        print(delay);
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItemRow3);
                    }
                    else
                    {
                        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE3, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    }
                case 15:
                    let workItemRow4: DispatchWorkItem = DispatchWorkItem(block: {
                        self.formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE4, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    })
                    workItems.append(workItemRow4);
                    if ((Device.connectedDevice?.requestWithoutResponse)!)
                    {
                        delay += 0.2
                        print(delay);
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItemRow4);
                    }
                    else
                    {
                        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE4, inputInts: outputs[Int(i/4)], digitsPerInput: 1, sendToMimicDevices: true);
                    }
                default:
                    print("Found index out of setPalette targets");
                }
            }
        }
        
        
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
        
    }
//
//        // checking for disconnection before using a BLE command
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
//            return;
//        }
//
//        // creating variables for RGB values of color
//        var red: CGFloat = 0;
//        var green: CGFloat = 0;
//        var blue: CGFloat = 0;
//        var alpha: CGFloat = 0;
//
//        // getting color1's RGB values (from 0 to 1.0)
//        color1.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
//
//        // scaling up to 255
//        red *= 255;
//        green *= 255;
//        blue *= 255;
//
//        // removing decimal places, removing signs, and making them UInt8s
//        let red1 = convertToLegalUInt8(Int(red));
//        let green1 = convertToLegalUInt8(Int(green));
//        let blue1 = convertToLegalUInt8(Int(blue));
//
//        // getting color2's RGB values
//        color2.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
//
//        // scaling up to 255
//        red *= 255;
//        green *= 255;
//        blue *= 255;
//
//        // removing decimal places, removing signs, and making them UInt8s
//        let red2 = convertToLegalUInt8(Int(red));
//        let green2 = convertToLegalUInt8(Int(green));
//        let blue2 = convertToLegalUInt8(Int(blue));
//
//        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_COLOR;
//
//        let stringArray: [UInt8] = Array(valueString.utf8);
//        var valueArray = stringArray;
//        valueArray += [red1];
//        valueArray += [green1];
//        valueArray += [blue1];
//        valueArray += [red2];
//        valueArray += [green2];
//        valueArray += [blue2];
//        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
//        let valueData = NSData(bytes: valueArray, length: valueArray.count)
//
//        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
//    }
//
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

    public static func saveBLELog() -> Bool
    {
        Device.currentlyProfiling = false;
        do
        {
                // adding a summary to the main BLE log
            var newTitleLine = "Hardware:,nRf8001 Delay (ms):,Total Duration (s):,Number Of Timeouts:\n";
            Device.mainCsvText.append(newTitleLine);
            var newSummaryLine = "\(Device.connectedDevice!.hardwareVersion),\(Constants.NRF8001_DELAY_TIME * 1000),\(Date().timeIntervalSince(Device.profilerStopwatch)),\(Device.numTimeouts)\n"
            Device.mainCsvText.append(newSummaryLine)
            
                // adding details like software version
            newTitleLine = "Hardware Name:,Nickname:,Software Version:,iOS Version:\n";
            Device.mainCsvText.append(newTitleLine);
            newSummaryLine = "\(Device.connectedDevice!.name),\(Device.connectedDevice!.nickname),\((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String?) ?? "unknown"), \(UIDevice.current.systemVersion)\n";
            Device.mainCsvText.append(newSummaryLine);
            
            try Device.mainCsvText.write(to: Device.mainProfilerPath!, atomically: true, encoding: String.Encoding.utf8);
            try Device.rxCsvText.write(to: Device.rxProfilerPath!, atomically: true, encoding: String.Encoding.utf8);
            try Device.txCsvText.write(to: Device.txProfilerPath!, atomically: true, encoding: String.Encoding.utf8);
            
            
                // resetting BLE log contents for the next log
            Device.mainCsvText = "Action,Timestamp,Type,Duration,Complete Message Duration\n";
            Device.rxCsvText = "Rx Action,Rx Duration,Complete Message Duration\n";
            Device.txCsvText = "Tx Action,Tx Duration\n";
            
            return true;
        }
        catch
        {
            Device.reportError(Constants.FAILED_TO_SAVE_PROFILER_CSV_FILES, additionalInfo: "\(error)");
            //print("Failed to create file")
            //print("\(error)")
            
            return false;
        }
    }
    
    // MARK: Private Methods
        // FIX-ME: brightness test
//    @objc func testBrightness()
//    {
//        getValue(EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS, inputInt: brightnessCounter);
//        Device.connectedDevice?.brightness = brightnessCounter;
//        brightnessCounter += 1;
//        if (brightnessCounter > 255)
//        {
//            self.timer.invalidate();
//            brightnessTestingTimer.invalidate();
//        }
//    }
    
        // takes an Int and makes sure it will fit in an unsigned Int8 (including calling abs())
    private func convertToLegalUInt8(_ value: Int) -> UInt8
    {
            // absolute value
        var output = abs(value);
        
        output = min(Int(UInt8.max), max(value, Int(UInt8.min)));
        
        return UInt8(output);
    }
    
    // takes an Int and makes sure it will fit in an unsigned Int8 (including calling abs())
    private func convertToLegalInt(_ value: Int) -> Int
    {
            // absolute value
        var output = abs(value);
        
        output = min(Int(UInt8.max), max(value, Int(UInt8.min)));
        
        return output;
    }
    
    private func convertUIColorToIntArray(_ color: UIColor) -> [Int]
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
        let redInt = convertToLegalInt(Int(red));
        let greenInt = convertToLegalInt(Int(green));
        let blueInt = convertToLegalInt(Int(blue));
        
        return [redInt] + [greenInt] + [blueInt];
    }
    
        // sends commands to the hardware, using the protocol as the inputString (and an optional few ints at the end, for certain commands)
    private func formatAndSendPacket(_ inputString: String, inputInts: [Int] = [Int](), digitsPerInput: Int = 2, sendToMimicDevices: Bool = false, toSingleDevice: Device? = nil)
    {
        print(" ");
        print(" ");
        print("About to send BLE command \(inputString) with arguments \(inputInts)")
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
        
            // formatting data
        let outputData = Device.formatPacket(inputString, inputInts: inputInts, digitsPerInput: digitsPerInput)
        
            // if we're getting the modes, and if we've asked for this same info too many times, stop
        
        if (Device.connectedDevice!.lastFewMessages.count >= Constants.NUM_ALLOWED_RETRIES_PER_PACKET && !Device.connectedDevice!.readyToShowModes && Device.connectedDevice!.maxNumModes > 0)
        {
            var hasTriedPacketTooManyTimes = true;
            for oldData in Device.connectedDevice!.lastFewMessages
            {
                    // if we asked for a different packet in the last few packets, we're fine to ask for this one
                if (oldData != outputData[0])
                {
                    hasTriedPacketTooManyTimes = false;
                }
            }
                // don't send the packet again if we already have a bunch of times without response
            if (hasTriedPacketTooManyTimes)
            {
                Device.reportError(Constants.REQUESTED_DATA_WITH_NO_RESPONSE_TOO_MANY_TIMES);
                alertUserToMoveCloserToHardware()
                return;
            }
        }
        
        
            // if we're getting data from hardware, we want look for timeouts
        if (!Device.connectedDevice!.readyToShowModes && Device.connectedDevice!.maxNumModes > 0)
        {
            restartBLERxTimeoutTimer();
        }
        
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: sendToMimicDevices, settingMode: inputString.elementsEqual(EnlightedBLEProtocol.ENL_BLE_SET_MODE), toSingleDevice: toSingleDevice);
        
            // filling up "last few messages"
        if (!Device.connectedDevice!.readyToShowModes && Device.connectedDevice!.maxNumModes > 0)
        {
                // if we have a full history, remove the last item
            if (Device.connectedDevice!.lastFewMessages.count >= Constants.NUM_ALLOWED_RETRIES_PER_PACKET)
            {
                Device.connectedDevice!.lastFewMessages.remove(at: 0);
            }
            Device.connectedDevice!.lastFewMessages.append(outputData[0]);
            
        }
        
    }
    
    func alertUserToMoveCloserToHardware()
    {
        // error popup
        let dialogMessage = UIAlertController(title:"Low connection strength", message: "The app is having trouble receiving data from the BLE device.  Please move closer to your device, and then press \"OK\"", preferredStyle: .alert);
        let ok = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:
        {(action) -> Void in
            
            if (!Device.connectedDevice!.isConnected)
            {
                print("We disconnected from the peripheral, so we should go to the Connect Screen at this point");
                _ = self.navigationController?.popToRootViewController(animated: true);
            }
                // otherwise, resume loading load data
            else
            {
                self.requestNextDataWithDelay();
            }

            
        })
        
        dialogMessage.addAction(ok);
        
            // presenting this view controller over the current screen, whatever that may be
        self.navigationController?.topViewController?.present(dialogMessage, animated: true, completion: nil);
        
    }
    
    @objc func stopBLERxTimeoutTimer()
    {
        BLETimeoutTimer.invalidate();
    }
    
    @objc func restartBLERxTimeoutTimer()
    {
            // setting timeout timer
        BLETimeoutTimer.invalidate();
        var timeoutTime = 0.0;
        if (Device.connectedDevice!.hardwareVersion == .NRF51822)
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_NRF51822;
        }
        else if (Device.connectedDevice!.hardwareVersion == .FASTNRF51822)
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_FASTNRF51822;
        }
        else
        {
            timeoutTime = Constants.BLE_MESSAGE_TIMEOUT_TIME_NRF8001;
        }
        
        BLETimeoutTimer = Timer.scheduledTimer(timeInterval: timeoutTime, target: self, selector: #selector(bleMessageTimeout), userInfo: nil, repeats: false);

    }
//            // formatting the string part of the packet
//        var intsToParse = inputInts;
//        let stringArray: [UInt8] = Array(inputString.utf8);
//        var uInt8Array = [UInt8]();
//            // formatting ints, if any
//        if (intsToParse.count > 0)
//        {
//            while (intsToParse.count > 0)
//            {
//                    // the nRF51822 protocol requires special formatting
//                    // FIX-ME: temporary exception for nRF51822's Set Standby, as that doesn't take a char currently
//                if (Device.connectedDevice!.hardwareVersion == .NRF51822 && !inputString.elementsEqual(EnlightedBLEProtocol.ENL_BLE_SET_STANDBY))
//                {
//                    uInt8Array += (formatForNRF51822(intsToParse[0], numExpectedDigits: digitsPerInput));
//                }
//                else
//                {
//                    uInt8Array.append(UInt8(intsToParse[0]));
//                }
//
//                intsToParse.remove(at: 0);
//            }
//        }
//
//            // formatting as data
//        let outputArray = stringArray + uInt8Array;
//        let outputData = NSData(bytes: outputArray, length: outputArray.count);
            // sending to peripheral(s)

//
//            // if an input value was specified, especially for the getName/getMode commands, add it to the package
//        if (inputInt != -1)
//        {
//            if (secondInputInt != -1)
//            {
//
//                let uInputInt: UInt8 = UInt8(inputInt);
//                let secondUInputInt: UInt8 = UInt8(secondInputInt);
//                let stringArray: [UInt8] = Array(inputString.utf8);
//
//                var outputArray = [UInt8]();
//
//                    // the nRF51822 protocol requires special formatting
//                if (Device.connectedDevice!.hardwareVersion == .NRF51822)
//                {
//                    outputArray = stringArray + formatForNRF51822(inputInt, numExpectedDigits: digitsPerInput) + formatForNRF51822(secondInputInt, numExpectedDigits: digitsPerInput);
//                }
//                else
//                {
//                    outputArray = stringArray + [uInputInt] + [secondUInputInt];
//                }
//
//                let outputData = NSData(bytes: outputArray, length: outputArray.count)
//                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
//            }
//            else
//            {
//                let uInputInt: UInt8 = UInt8(inputInt);
//                let stringArray: [UInt8] = Array(inputString.utf8);
//
//                var outputArray = [UInt8]();
//
//                    // the nRF51822 protocol requires special formatting
//                if (Device.connectedDevice!.hardwareVersion == .NRF51822)
//                {
//                    outputArray = stringArray + formatForNRF51822(inputInt, numExpectedDigits: digitsPerInput);
//                }
//                else
//                {
//                    outputArray = stringArray + [uInputInt];
//                }
//
//                //let outputArray = stringArray + [uInputInt];
//                print(outputArray);
//                let outputData = NSData(bytes: outputArray, length: outputArray.count)
//                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
//            }
//        }
//        else
//        {
//            let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
//            // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
//            BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: inputNSString! as NSData, sendToMimicDevices: false);
//        }
//    }
    
        // because the new protocol for the nRF51822 is to send each digit of a number as its own ASCII digit, we have to separate them (and add leading zeroes if necessary)
    private func formatForNRF51822(_ input: Int, numExpectedDigits: Int = 2) -> [UInt8]
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
//            // hundreds place (if necessary)
//        if (numExpectedDigits > 2)
//        {
//            if (input > 99)
//            {
//                output.append(UInt8(String((input / 100) % 10)));
//            }
//            else
//            {
//                output.append(UInt8(0));
//            }
//        }
//            // tens place (if necessary)
//        if (numExpectedDigits > 1)
//        {
//            if (input > 9)
//            {
//                output.append(UInt8((input / 10) % 10))
//            }
//            else
//            {
//                output.append(UInt8(0));
//            }
//        }
//
//            // ones place
//        output.append(UInt8((input % 10)));
        
        //return output;
    //}
    
        // saves the Device after loading
    @objc private func saveDevice()
    {
            // never save the demo device
        if (Device.connectedDevice!.isDemoDevice)
        {
            print("Demo device, not caching");
            return;
        }
        
        if !(Device.connectedDevice!.modes.count >= Device.connectedDevice!.maxNumModes && Device.connectedDevice!.thumbnails.count >= Device.connectedDevice!.maxBitmaps)
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
        if isSuccessfulSave
        {
            //os_log("Devices successfully saved.", log: OSLog.default, type: .debug)
        }
        else
        {
            Device.reportError(Constants.FAILED_TO_SAVE_DEVICES_IN_CACHE);
            //os_log("Failed to save devices...", log: OSLog.default, type: .error)
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
            guard let mode1 = Mode(name:"SLOW TWINKLE", index: 1, usesPalette: false, usesBitmap: false, bitmap: nil, colors: colorArray1) else
            {
                fatalError("unable to instantiate mode1");
            }
            modes += [mode1];
        }
        
        if (numberOfModes >= 2)
        {
            guard let mode2 = Mode(name:"MEDIUM TWINKLE", index: 2, usesPalette: false, usesBitmap: false, bitmap: nil, colors: colorArray2) else
            {
                fatalError("unable to instantiate mode2");
            }
            modes += [mode2];
        }
        
        if (numberOfModes >= 3)
        {
            guard let mode3 = Mode(name:"FAST TWINKLE", index: 3, usesPalette: false, usesBitmap: true, bitmap: bitmap1, colors: [nil]) else
            {
                fatalError("unable to instantiate mode3");
            }
            modes += [mode3];
        }
        
        
        if (numberOfModes >= 4)
        {
            guard let mode4 = Mode(name:"EXTREMELY LONG TEST NAME (2 Lines)", index: 4, usesPalette: false,  usesBitmap: true, bitmap: bitmap2, colors: [nil]) else
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
                guard let mode = Mode(name: "mode\(index)", index: index, usesPalette: false, usesBitmap: true, bitmap: bitmap2, colors: [nil]) else
                {
                    fatalError("unable to instantiate mode\(index)");
                }
                modes += [mode];
            }
        }
        
        //4modes += [mode1, mode2, mode3, mode4];
        
    }

}

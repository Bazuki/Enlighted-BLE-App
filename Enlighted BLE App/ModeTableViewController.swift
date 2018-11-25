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
    
    var progress: Float = 0;
    
        // sample list of modes, since they can't be retrieved from the hardware right now
    var modes = [Mode]();
    
    var timer = Timer();
    var BLETimeoutTimer = Timer();
        // whether or not the currently selected mode has to be initialized
    var initialModeSelected = false;
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();

        // getLimits for this device
        getValue(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
        Device.connectedDevice?.requestedLimits = true;
        progress += 0.04
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateModeSettings), name: Notification.Name(rawValue: "changedMode"), object: nil)
        
            // setting this as the delegate of the table view
        tableView.delegate = self;
        
            // setting this as the delegate of the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil);
        //Device.connectedDevice!.peripheral.delegate = self as! CBPeripheralDelegate;
        
            // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated);
        
            // making sure the main timer isn't running
        timer.invalidate();
            // if we have all the modes and thumbnails, we're ready to display them
        Device.connectedDevice?.readyToShowModes = (Device.connectedDevice?.modes.count == Device.connectedDevice?.maxNumModes && Device.connectedDevice?.thumbnails.count == Device.connectedDevice?.maxBitmaps);
        
            // configuring the style of the progress bar
        loadingProgressView.progressViewStyle = UIProgressView.Style.bar;
        
            // if we didn't completely get the mode list (i.e. aren't totally ready to show modes)
        if (!(Device.connectedDevice?.readyToShowModes)!)
        {
                // disabling the settings button when getting info
            self.navigationItem.rightBarButtonItem?.isEnabled = false;
            
                // clearing table data
            print("Wasn't ready to show modes, restarting getting data");
            modes = [Mode]();
            modeTableView.reloadData();
            
                // reset progress bar, and show
            progress = 0;
            loadingProgressView.setProgress(0, animated: false);
            loadingProgressView.isHidden = false;
            
                // reset the variables, so we get all of them
            Device.connectedDevice?.requestedName = false;
            Device.connectedDevice?.currentlyBuildingThumbnails = false;
            //Device.connectedDevice?.modes = [Mode]();
            Device.connectedDevice?.requestedMode = false;
            Device.connectedDevice?.readyToShowModes = false;
        }
        else
        {
            loadingProgressView.setProgress(1, animated: true);
            loadingProgressView.isHidden = true;
        }
       
        print("Setting timer");
            // Set the timer that governs the setup of the mode table
        timer = Timer.scheduledTimer(timeInterval: 0.04, target: self, selector: #selector(self.setUpTable), userInfo: nil, repeats: true);
        
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
            
                // enabling the settings button when showing modes
            self.navigationItem.rightBarButtonItem?.isEnabled = true;
            
            self.timer.invalidate();
            print("Showing modes");
            loadingProgressView.setProgress(1, animated: true)
            loadingProgressView.isHidden = true;
            
            //loadSampleModes(Device.connectedDevice?.maxNumModes ?? 4);
                // load up the modes stored on the device object
            modes = (Device.connectedDevice?.modes)!;
            let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
            
            modeTableView.reloadData();
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
        }
            // otherwise do preparatory steps, as long as a multi-message response isn't currently happening
        else if (Device.connectedDevice?.requestedThumbnail == false && Device.connectedDevice?.currentlyParsingName == false && Device.connectedDevice?.requestWithoutResponse == false)
        {
                // if getLimits hasn't received a value yet
            if ((Device.connectedDevice?.currentModeIndex)! < 0)
            {
                    // if we haven't already, getLimits for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice?.requestedLimits)!)
                {
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_LIMITS);
                    Device.connectedDevice?.requestedLimits = true;
                    progress += 0.4;
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
                    progress += 0.03;
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
            else if ((Device.connectedDevice?.batteryPercentage)! < 0)
            {
                // if we haven't already, getBatteryLevel for this device, so that we'll know it when we change it on the settings screen
                if (!(Device.connectedDevice?.requestedBattery)!)
                {
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL);
                    Device.connectedDevice?.requestedBattery = true;
                    progress += 0.03;
                }
                // if we've already requested it, we have to keep waiting for a response before sending something else on the txCharacteristic
                return;
            }
                    // if we haven't gotten all the modes, keep chugging
            else if ((Device.connectedDevice?.modes.count)! < (Device.connectedDevice?.maxNumModes)!)
            {
                    // how much progress each Get Name / Get Mode is worth
                let progressValue: Float = 0.3 / (Float((Device.connectedDevice?.maxNumModes)!) * 2)
                
                    // if we haven't yet, request the name of the first mode we need
                if (!(Device.connectedDevice?.requestedName)!)
                {
                        // getting the name of the next Mode
                    //print("Getting details about mode #\((Device.connectedDevice?.modes.count)! + 1)");
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
                    progress += progressValue;
                }
                
                return;
            }
                // getting the thumbnails;
            else if ((Device.connectedDevice?.thumbnails.count)! < (Device.connectedDevice?.maxBitmaps)!)
            {
                Device.connectedDevice?.currentlyBuildingThumbnails = true;
                let progressValue: Float = 0.6 / (Float((Device.connectedDevice?.maxBitmaps)!) * 20);
                    // if we haven't already
                if (!(Device.connectedDevice?.requestedThumbnail)!)
                {
                    // if it's past the max, reset
                    if ((Device.connectedDevice?.thumbnailRowIndex)! >= 20)
                    {
                        Device.connectedDevice?.thumbnailRowIndex = 0;
                    }
                        // request the current thumbnail at the current row
                    getValue(EnlightedBLEProtocol.ENL_BLE_GET_THUMBNAIL, inputInt:  (Device.connectedDevice?.thumbnails.count)! + 1, secondInputInt: (Device.connectedDevice?.thumbnailRowIndex)!);
                    Device.connectedDevice?.requestedThumbnail = true;
                    
                    progress += progressValue;
                    //print("increasing progress by \(progressValue)");
                    
                    BLETimeoutTimer.invalidate();
                    BLETimeoutTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(thumbnailTimeout), userInfo: nil, repeats: false);
                }
                return;
            }
                // once all setup is done, we are ready to show the modes
            else
            {
                    // we want to make sure we don't have thumbnail remnants if the "Get Thumbnail" process is interrupted
                Device.connectedDevice?.currentlyBuildingThumbnails = false;
                
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
            let progressValue: Float = 0.6 / (Float((Device.connectedDevice?.maxBitmaps)!) * 20);
            progress -= progressValue;
            NotificationCenter.default.post(name: Notification.Name(rawValue: "resendRow"), object: nil);
        }
    }
    
    
    override func didReceiveMemoryWarning() {
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
        updateModeOnHardware();
    }
    
        // MARK: - BLE TX Methods
    
    func updateModeOnHardware()
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
        let valueData = NSData(bytes: valueArray, length: 4)
        
        //print("\(String(describing: valueNSString))");
        //let valueNSData = valueNSString! + modeIndexUInt;
        //if let Device.connectedDevice!.txCharacteristic = txCharacteristic
        //{
        print("sending " + valueString, Device.connectedDevice!.currentModeIndex, valueArray);
        
            // checking to see if we're disconnected (will have to do from every command)
        
        
        
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            // setting "active request" flag
        Device.connectedDevice!.requestWithoutResponse = true;
        Device.connectedDevice?.requestedModeChange = true;
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
        let valueData = NSData(bytes: valueArray, length: 4)
        
        print("sending: " + valueString, bitmapIndexUInt);
        
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        // "active request" flag
        Device.connectedDevice?.requestWithoutResponse = true;
        
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
        let valueData = NSData(bytes: valueArray, length: 9)
        
        print("sending: " + valueString, valueArray);
        
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        // "active request" flag
        Device.connectedDevice?.requestWithoutResponse = true;
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
    
    // TODO: before going to connection screen, disconnect from current peripheral
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
//    {
//        if (segue.identifier == "Connect BLE Device")
//        {
//            BLEConnectionTableViewController.disconnectFromDevice(BLEConnectionTableViewController);
//        }
//    }
//
    
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
                let outputData = NSData(bytes: outputArray, length: 5)
                print("Sending: " + inputString, inputInt, secondInputInt, outputArray);
                Device.connectedDevice!.peripheral.writeValue(outputData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            }
            else
            {
                let uInputInt: UInt8 = UInt8(inputInt);
                let stringArray: [UInt8] = Array(inputString.utf8);
                let outputArray = stringArray + [uInputInt];
                let outputData = NSData(bytes: outputArray, length: 4)
                print("Sending: " + inputString, inputInt, outputArray);
                Device.connectedDevice!.peripheral.writeValue(outputData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            }
        }
        else
        {
            let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
            // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
            print("Sending: " + inputString, inputNSString! as NSData);
            Device.connectedDevice!.peripheral.writeValue(inputNSString!, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
        }
        
        
            // "active request" flag
        Device.connectedDevice!.requestWithoutResponse = true;
    }
    
        // saves the Device after loading
    private func saveDevice()
    {
        if !(Device.connectedDevice?.modes.count == Device.connectedDevice?.maxNumModes && Device.connectedDevice?.thumbnails.count == Device.connectedDevice?.maxBitmaps)
        {
            print("Not a full cache, not caching");
            return;
        }
        var cachedDevices: [Device] = loadDevices() ?? [Device]();
            // if there aren't any saved devices, save them now
        //TODO: overwrite old saves that have the same name
        
            // if there's an old save with the same NSUUID, override it
        if let indexOfDevice = cachedDevices.firstIndex(where: {$0.UUID == Device.connectedDevice?.peripheral.identifier as NSUUID?})
        {
            cachedDevices[indexOfDevice] = Device.connectedDevice!
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

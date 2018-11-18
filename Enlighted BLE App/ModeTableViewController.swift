//
//  ModeTableViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import CoreBluetooth;

class ModeTableViewController: UITableViewController, CBPeripheralManagerDelegate
{
        // MARK: - Properties
    @IBOutlet weak var modeTableView: UITableView!
    
        // sample list of modes, since they can't be retrieved from the hardware right now
    var modes = [Mode]();
    
    var timer = Timer();
        // whether or not the currently selected mode has to be initialized
    var initialModeSelected = false;
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();

            // getLimits for this device
        getLimits();
        
        
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
        
            // If the currentModeIndex (and by extension, the max number of modes) has been found, load the sample modes.
        if ((Device.connectedDevice?.currentModeIndex)! > 0)
        {
            loadSampleModes(Device.connectedDevice?.maxNumModes ?? 4);
            let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
            self.tableView.selectRow(at: indexPath, animated: animated, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
            
                // getBrightness for this device, so that we'll know it when we change it on the settings screen
            getBrightness()
        }
        else
        {
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setUpTable), userInfo: nil, repeats: false);
        }
    }
    
    @objc func setUpTable()
    {
        if ((Device.connectedDevice?.currentModeIndex)! > 0)
        {
            timer.invalidate();
            loadSampleModes(Device.connectedDevice?.maxNumModes ?? 4);
            let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
            
            modeTableView.reloadData();
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
                // getBrightness for this device, so that we'll know it when we change it on the settings screen
            getBrightness()
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
        return modes.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ModeTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ModeTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of ModeTableViewCell");
        }

        let currentMode = modes[indexPath.row]
        
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
    
        // TODO:
    func updateModeOnHardware()
    {
            // converting to an unsigned byte integer
        let modeIndexUInt: UInt8 = UInt8(bitPattern: Int8(Device.connectedDevice!.currentModeIndex));
        
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
        print("sending " + valueString, Device.connectedDevice!.currentModeIndex);
        
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        
        //Device.connectedDevice!.peripheral.writeValue(valueNSString!, for: Device.connectedDevice!.txCharacteristic!, type:CBCharacteristicWriteType.withoutResponse)
        //}
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
    
        // sends getLimits to the hardware
    private func getLimits()
    {
        //print("Requesting current mode on Tx Characteristic");
        let inputString = EnlightedBLEProtocol.ENL_BLE_GET_LIMITS;
        print("Sending: " + inputString);
        let inputNSString = (inputString as NSString).data(using: String.Encoding.utf8.rawValue);
        Device.connectedDevice!.peripheral.writeValue(inputNSString!, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
    }
    
    private func getBrightness()
    {
        let inputString = EnlightedBLEProtocol.ENL_BLE_GET_BRIGHTNESS;
        print("Sending: " + inputString);
        let inputNSString = (inputString as NSString).data(using: String.Encoding.utf8.rawValue);
        Device.connectedDevice!.peripheral.writeValue(inputNSString!, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
    }
    
        // loads placeholder modes, up till the max mode count from getLimits
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

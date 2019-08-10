//
//  MimicTableViewController.swift
//  Enlighted BLE App
//
//  Created by Bryce Suzuki on 8/4/19.
//  Copyright © 2019 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class MimicTableViewController: UITableViewController
{
    
    // MARK: Properties
    
        // the devices we're currently displaying
    var visibleDevices = [Device]();
    
    var devicesToDisplay = [Device]();
    
        // the devices we have stored in memory, which we will recognize by UUID
    var cachedDevices = [Device]();
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
        cachedDevices = BLEConnectionTableViewController.loadDevices() ?? [Device]();
        
        BLEConnectionTableViewController.CBCentralState = .SCANNING_FOR_MIMICS_TO_DISPLAY;
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.START_SCAN), object: nil);
        print(BLEConnectionTableViewController.CBCentralState);
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateMimicDisplay), name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_NEW_PERIPHERALS), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated);
        print("Removing MimicTableViewController's observers (in viewWillDisappear)");
        NotificationCenter.default.removeObserver(self);
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.UPDATE_CBCENTRAL_STATE), object: nil);
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return devicesToDisplay.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "MimicTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? MimicTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of MimicTableViewCell.");
        }

            // a reference to the peripheral that's represented in this cell
        let peripheral = devicesToDisplay[indexPath.row].peripheral;
        
        cell.deviceNameLabel.text = "\(devicesToDisplay[indexPath.row].name)\(devicesToDisplay[indexPath.row].nickname)";
        if (devicesToDisplay[indexPath.row].RSSI == -2)
        {
            cell.RSSIValueLabel.text = "Connected";
        }
        else
        {
            cell.RSSIValueLabel.text = "RSSI: \(devicesToDisplay[indexPath.row].RSSI)";
        }
        //\( )";
        cell.peripheral = peripheral;
        
            // if the device is currently set as a mimic, show it as on
        cell.mimicStatusSwitch.isOn = (Device.connectedDevice!.mimicList.contains(peripheral?.identifier as! NSUUID));
        
        
        
        // Configure the cell...

        return cell
    }
    
    @objc func updateMimicDisplay()
    {
        
        visibleDevices = Device.connectedDevice!.connectedMimicDevices;
        
        var newDevices = [Device]();
        
        //var devicesOnMimicList = [Device]();
        
        //var devicesNotOnMimicList = [Device]();
        
        if (BLEConnectionTableViewController.advertisingPeripherals.count > 0)
        {
            for i in 0...BLEConnectionTableViewController.advertisingPeripherals.count - 1
            {
                var newDevice: Device = Device(mimicDevicePeripheral: BLEConnectionTableViewController.advertisingPeripherals[i]);
                
                    // setting the RSSI
                newDevice.RSSI = Int(truncating: BLEConnectionTableViewController.advertisingRSSIs[i]);
                
                    // setting the UUID
                newDevice.UUID = newDevice.peripheral.identifier as NSUUID;
                //newDevice.nickname = BLEConnectionTableViewController.nicknames[i];
                
                
                newDevices += [newDevice]
            }
        }
        
        visibleDevices += newDevices;
        
        
        if (visibleDevices.count > 0)
        {
            
            // discovering nicknames
            for i in 0...(visibleDevices.count - 1)
            {
                if (cachedDevices.count > 0)
                {
                    // by default, there's no nickname
                    visibleDevices[i].nickname = "";
                    
                    let backwardsIndex = cachedDevices.count - 1;
                    // going through cache to see if we can match the name
                    for j in 0...(cachedDevices.count - 1)
                    {
                        // if we recognize it in the cache, save the nickname
                        if (cachedDevices[backwardsIndex - j].UUID! as UUID == visibleDevices[i].peripheral.identifier)
                        {
                            visibleDevices[i].nickname = " – \(cachedDevices[backwardsIndex - j].nickname)";
                            
                            print("We recognized it from our cache at index \(backwardsIndex - j) (out of \(backwardsIndex + 1) total), adding nickname to visible device list");
                        }
                    }
                }
            }
            
//                // separating into lists of devices on and not on the mimic list
//            for i in 0...(visibleDevices.count - 1)
//            {
//                if (visibleDevices[i].hasDiscoveredCharacteristics)
//                {
//                    visibleDevices[i].RSSI = -2;
//                }
//
//                if Device.connectedDevice!.mimicList.contains(visibleDevices[i].peripheral?.identifier as! NSUUID)
//                {
//                    devicesOnMimicList += [visibleDevices[i]];
//                }
//                else
//                {
//                    devicesNotOnMimicList += [visibleDevices[i]];
//                }
//            }
        }
        
            // sort by whatever's higher up on the mimic list
//        devicesOnMimicList.sort
//            {
//                Device.connectedDevice!.mimicList.index(of: $0.UUID as! NSUUID)! < Device.connectedDevice!.mimicList.index(of: $1.UUID as! NSUUID)!;
//        }
//
//        devicesNotOnMimicList.sort
//            {
//                $0.nickname > $1.nickname;
//        }
        
            // sort by NSUUID
        visibleDevices.sort
            {
                $0.UUID!.uuidString < $1.UUID!.uuidString;
        }
        
        devicesToDisplay = visibleDevices;//devicesOnMimicList + devicesNotOnMimicList;
        
        self.tableView.reloadData();
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
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
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

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        // update the CBCentralState, depending on the length/status of the mimic list
        
        
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
 
    
}

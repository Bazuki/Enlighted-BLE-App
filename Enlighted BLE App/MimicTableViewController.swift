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
            Device.reportError(Constants.FAILED_TO_DEQUEUE_TABLE_CELLS_FOR_MIMIC_TABLE);
            fatalError("The dequeued cell is not an instance of MimicTableViewCell.");
        }

        var cellRepresentsAdvertisingOrConnectedDevice = true;
            // a reference to the peripheral that's represented in this cell
        let peripheral = devicesToDisplay[indexPath.row].peripheral;
        
        cell.deviceNameLabel.text = "\(devicesToDisplay[indexPath.row].name)\(devicesToDisplay[indexPath.row].nickname)";
        
        if (devicesToDisplay[indexPath.row].RSSI == -3)
        {
            cellRepresentsAdvertisingOrConnectedDevice = false;
        }
        
        cell.isOn = cellRepresentsAdvertisingOrConnectedDevice;
        
        cell.updateRSSIValue(devicesToDisplay[indexPath.row].RSSI)
        //\( )";
        cell.peripheral = peripheral;
        cell.NSUUID = devicesToDisplay[indexPath.row].UUID;
        // if the device is currently set as a mimic, show it as on
        cell.mimicStatusSwitch.isOn = (Device.connectedDevice!.mimicList.contains(devicesToDisplay[indexPath.row].UUID));
        
        
        
        
        

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
                
                    // only add the device if it's in the cache (i.e. previously connected)
                //if (cacheContainsUUID(identifier: newDevice.peripheral.identifier))
                //{
                    newDevices += [newDevice]
                //}
            }
        }
        
        visibleDevices += newDevices;
        
        // finding out what devices are on the mimic list but not currently advertising
        var remainingMimicDevices = Device.connectedDevice!.mimicList;
        
        for peripheral in BLEConnectionTableViewController.advertisingPeripherals
        {
            if let indexOfUUID = remainingMimicDevices.firstIndex(of: peripheral.identifier as NSUUID)
            {
                remainingMimicDevices.remove(at: indexOfUUID);
            }
        }
        
        for device in Device.connectedDevice!.connectedMimicDevices
        {
            if let indexOfUUID = remainingMimicDevices.firstIndex(of: device.peripheral.identifier as NSUUID)
            {
                remainingMimicDevices.remove(at: indexOfUUID);
            }
        }
        
        for NSUUID in remainingMimicDevices
        {
                // if we find a cached primary name, use that, otherwise use the cached mimic/secondary name
            var newDevice = Device(mimicDeviceName: getNameForUUID(NSUUID as UUID) ??  Device.connectedDevice!.mimicListNames[Device.connectedDevice!.mimicList.firstIndex(of: NSUUID)!]);
            if newDevice != nil
            {
                newDevice.RSSI = -3;
                newDevice.UUID = NSUUID;
                visibleDevices += [newDevice];
            }
        }
        
        if (visibleDevices.count > 0)
        {
            
            // discovering nicknames
            for i in 0...(visibleDevices.count - 1)
            {
                visibleDevices[i].nickname = getNicknameForUUID(visibleDevices[i].UUID as UUID);
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
    
    // MARK: - Private Methods
    
    func getNicknameForUUID(_ identifier: UUID) -> String
    {
        var nickname = "";
        
        if (cachedDevices.count > 0)
        {
            
            //visibleDevices[i].nickname = "";
            
            let backwardsIndex = cachedDevices.count - 1;
            // going through cache to see if we can match the name
            for j in 0...(cachedDevices.count - 1)
            {
                // if we recognize it in the cache, save the nickname
                if (cachedDevices[backwardsIndex - j].UUID! as UUID == identifier)
                {
                    if (cachedDevices[backwardsIndex - j].nickname != "")
                    {
                        nickname = " – \(cachedDevices[backwardsIndex - j].nickname)";
                        print("We recognized it from our cache at index \(backwardsIndex - j) (out of \(backwardsIndex + 1) total)");
                    }
                    else
                    {
                        print("We recognized it from our cache at index \(backwardsIndex - j) (out of \(backwardsIndex + 1) total), but didn't find a suitable nickname");
                    }
                }
            }
        }
        
        return nickname;
    }
    
    func getNameForUUID(_ identifier: UUID) -> String?
    {
        
        if (cachedDevices.count > 0)
        {
            
            //visibleDevices[i].nickname = "";
            
            let backwardsIndex = cachedDevices.count - 1;
            // going through cache to see if we can match the name
            for j in 0...(cachedDevices.count - 1)
            {
                // if we recognize it in the cache, save the nickname
                if (cachedDevices[backwardsIndex - j].UUID! as UUID == identifier)
                {
                    return cachedDevices[backwardsIndex - j].name;
                    
                    print("We recognized it from our cache at index \(backwardsIndex - j) (out of \(backwardsIndex + 1) total)");
                    
                    //return cachedDevices[backwardsIndex - j];
                }
            }
        }
        
        return nil;
    }
    
    
    // if the cache contains an item with the given UUID, it will return true; if there's no cache, or no such item in the cache, it'll return false.
    func cacheContainsUUID(identifier: UUID) -> Bool
    {
        if (cachedDevices.count > 0)
        {
            
            //visibleDevices[i].nickname = "";
            
            let backwardsIndex = cachedDevices.count - 1;
            // going through cache to see if we can match the name
            for j in 0...(cachedDevices.count - 1)
            {
                // if we recognize it in the cache, save the nickname
                if (cachedDevices[backwardsIndex - j].UUID! as UUID == identifier)
                {
                    return true;
                }
            }
        }
        
        return false;
    }
 
    
}

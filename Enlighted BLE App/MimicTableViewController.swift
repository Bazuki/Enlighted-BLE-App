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
    
    var visiblePeripherals = [CBPeripheral]();
    
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
        
        BLEConnectionTableViewController.CBCentralState = .SCANNING_FOR_MIMICS_TO_DISPLAY;
        NotificationCenter.default.post(name: Notification.Name(rawValue: "startScanning"), object: nil);
        print(BLEConnectionTableViewController.CBCentralState);
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateMimicDisplay), name: Notification.Name(rawValue: "discoveredNewPeripherals"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated);
        print("Removing MimicTableViewController's observers (in viewWillDisappear)");
        NotificationCenter.default.removeObserver(self);
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "updateCBCentralState"), object: nil);
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return visiblePeripherals.count;
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
        var peripheral = visiblePeripherals[indexPath.row];
        
        cell.deviceNameLabel.text = peripheral.name;
        cell.RSSIValueLabel.text = "RSSI: -1"//\( )";
        cell.peripheral = peripheral;
        
            // if the device is currently set as a mimic, show it as on
        cell.mimicStatusSwitch.isOn = (Device.connectedDevice!.mimicList.contains(peripheral.identifier as NSUUID));
        
        
        
        // Configure the cell...

        return cell
    }
    
    @objc func updateMimicDisplay()
    {
        visiblePeripherals = BLEConnectionTableViewController.advertisingPeripherals;
        for device in Device.connectedDevice!.connectedMimicDevices
        {
            visiblePeripherals += [device.peripheral];
        }
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

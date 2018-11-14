//
//  BLEConnectionTableViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth

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
    
        // The bluetooth CentralManager object controlling the connection to peripherals
    var centralManager : CBCentralManager!;
        // A timer object to help in searching
    var timer = Timer();
    var scanTimer = Timer();
    
    var scanTimeInterval: Double = 20;
    
        // list of peripherals, and their associated RSSI values
    var peripherals: [CBPeripheral] = [];
    var RSSIs = [NSNumber]();
    var data = NSMutableData();
    
    
    
    @IBOutlet weak var deviceTableView: UITableView!
    
    
        // MARK: Bluetooth
    
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        if central.state == CBManagerState.poweredOn
        {
            print("Bluetooth Enabled")
            startScan();
            
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
        self.RSSIs.append(RSSI);
        
            // adding a new device to the list, to be displayed
        self.visibleDevices.append(Device(name: peripheral.name!, RSSI: RSSI.intValue, peripheral: peripheral));
        
        peripheral.delegate = self;
            // discovering Bluefruit GATT services
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
    @objc func startScan()
    {
        print("Now scanning...");
        self.timer.invalidate();
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: 17, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false);
    }
    
        // cancelling the scan for peripherals
    @objc func cancelScan()
    {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
//        if (!Device.connectedDevice!.isConnected)
//        {
//                // if the device hasn't connected, keep scanning
//            //startScan();
//
//        }
        
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
    
        // called automatically after characteristics we've subscribed to are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
            // parsing/dealing with the info read from the firmware
        if characteristic == rxCharacteristic
        {
            
                // if there's an error, it shouldn'y keep going
            if let e = error
            {
                print("ERROR didUpdateValueFor \(e)");
                return;
            }
            
//            guard let failableValue = characteristic.value else
//            {
//
//            }
            
            let rxValue = [UInt8](characteristic.value!);
            
            
            
            let rxString = String(bytes: rxValue, encoding: .utf8);
            
            print("Value Recieved: " + rxString!, Int(rxValue[1]), Int(rxValue[2]), Int(rxValue[3]));
            
            
                // if the first letter is "L", we're getting the current mode, lower-, and upper-mode count limits.
            if (rxString?[(rxString?.startIndex)!] == "L")
            {
                //print(Int(rxValue[1]));
                Device.connectedDevice?.currentModeIndex = Int(rxValue[1]);
                Device.connectedDevice?.maxNumModes = Int(rxValue[3]);
                
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
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue);
            // if the blePeripheral variable is set
        if let blePeripheral = blePeripheral
        {
            // and the txCharacteristic variable is set
            if let txCharacteristic = txCharacteristic
            {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse);
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
        
            // stop scanning
        centralManager?.stopScan();
        print("Scan stopped");
        
            // erase data we might have
        data.length = 0;
        
        Device.connectedDevice?.isConnected = true;
        
        
            // Discovery callback
        peripheral.delegate = self;
            // Only look for services that match the transmit UUID (and the battery service UUID)
        peripheral.discoverServices([BLEService_UUID]);
        //peripheral.discoverServices([BLEBatteryService_UUID]);
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
            print("Error discovering services: \(error!.localizedDescription)");
            return;
        }
        
        guard let characteristics = service.characteristics else
        {
            return;
        }
        
        print("Found \(characteristics.count) characteristics!");
        
        for characteristic in characteristics
        {
            
                // looks for the transmission characteristic
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
            
                // looks for the read characteristic
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx)
            {
                txCharacteristic = characteristic;
                    // set a reference to this characteristic in the device
                Device.connectedDevice!.setTXCharacteristic(characteristic);
                print("Tx Characteristic: \(characteristic.uuid)");
            }
            
                // looks for the battery level characteristic
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_batteryValue)
            {
                batteryCharacteristic = characteristic;
                
                    // once found, subscribe to this characteristic to update the battery level
                peripheral.setNotifyValue(true, for: batteryCharacteristic!);
                
                peripheral.readValue(for: characteristic);
                print("Battery characteristic: \(characteristic.uuid)");
            }
            
            peripheral.discoverDescriptors(for: characteristic);
        }
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
    
    func disconnectFromDevice()
    {
        if Device.connectedDevice!.peripheral != nil
        {
            centralManager?.cancelPeripheralConnection(Device.connectedDevice!.peripheral);
            Device.connectedDevice!.isConnected = false;
        }
    }
    
    

        // MARK: - UIViewController Methods
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        //loadSampleDevices();
        
        centralManager = CBCentralManager(delegate:self, queue: nil);
        
        
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    
    // MARK: - UITableDelegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
            // set the connected device and connect to that device
        Device.setConnectedDevice(newDevice: visibleDevices[indexPath.row]);
        
        connectToDevice();
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

    // changing the "back button" text to show that it will disconnect the device, and so that it will fit
    // credit to https://stackoverflow.com/questions/28471164/how-to-set-back-button-text-in-swift
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let backItem = UIBarButtonItem();
        backItem.title = "Disconnect";
        navigationItem.backBarButtonItem = backItem;
    }
    
    
    // MARK: Private Methods
    
        // making fake devices to showcase the UI
    private func loadSampleDevices()
    {
        
        // Initializing some sample devices
        let device1 = Device(name: "ENL1");
        let device2 = Device(name: "ENL2");
        let device3 = Device(name: "ENL3");
        let device4 = Device(name: "ENL4");
        
        visibleDevices += [device1, device2, device3, device4];
        
    }
}

//
//  DeviceManagementViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceManagementViewController: UIViewController, CBPeripheralManagerDelegate
{
    
    //MARK: Properties

    @IBOutlet weak var deviceNameLabel: UILabel!
    
    @IBOutlet weak var batteryStatusImage: UIImageView!
    @IBOutlet weak var batteryPercentageLabel: UILabel!
    
    @IBOutlet weak var brightnessSlider: UISlider!
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
            // setting the device name
        deviceNameLabel.text = Device.connectedDevice?.name;
        
        
        
        
            // formatting the battery image to allow it to be tinted
        batteryStatusImage.image = batteryStatusImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        
            // setting this as the delegate of the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil);
        
            // updating the battery percentage to display the percentage (temporarily).  200 means the battery value isn't readable
        //batteryPercentageLabel.text = "\(Device.connectedDevice?.batteryPercentage ?? 200)%";
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        getValue(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL);
        
        // getting and updating the slider with the device's brightness
        brightnessSlider.value = Float((Device.connectedDevice?.brightness)!);
        //batteryPercentageLabel.text = String((Device.connectedDevice?.batteryPercentage)!);
        
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func dismissPopup(_ sender: UIButton)
    {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func changeBrightness(_ sender: UISlider)
    {
        print("New slider value: \(sender.value)");
        Device.connectedDevice?.brightness = Int(sender.value);
        
            // converting to an unsigned byte integer, to be passed to the hardware
        var brightnessIndexUInt: UInt8 = UInt8(Device.connectedDevice!.brightness);
        
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS;// + "\(modeIndexUInt)";
        //print(valueString);
        let stringArray: [UInt8] = Array(valueString.utf8);
        let valueArray = stringArray + [brightnessIndexUInt]
        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: 4)
        
        print("sending: " + valueString, (Device.connectedDevice!.brightness));
        //print("\(String(describing: valueNSString))");
        //let valueNSData = valueNSString! + modeIndexUInt;
        //if let Device.connectedDevice!.txCharacteristic = txCharacteristic
        //{
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        Device.connectedDevice!.requestWithoutResponse = true;
    }
    
    
    
    
    
    // MARK: Actions
    
    @IBAction func RevertToOriginalSettings(_ sender: UIButton)
    {
        // creating the dialog message
        let dialogMessage = UIAlertController(title:"Confirm", message: "Are you sure you want to revert settings?  Your changes will be lost.", preferredStyle: .alert);
        
        // defining the confirm / revert button
        let revert = UIAlertAction(title: "Revert", style: .default, handler: {(action) -> Void in
            print("Reverted to default settings");
        })
        
        // defining the cancel button
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
            print("Cancelled");
        }
        
        // add the buttons to the message
        dialogMessage.addAction(revert);
        dialogMessage.addAction(cancel);
        
        self.present(dialogMessage, animated: true, completion: nil);
        
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    //Mark: Private Methods
    
    // sends get commands to the hardware, using the protocol as the inputString
    private func getValue(_ inputString: String)
    {
        let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
        // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
        print("Sending: " + inputString, inputNSString! as NSData);
        Device.connectedDevice!.peripheral.writeValue(inputNSString!, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse);
            // "active request" flag
        Device.connectedDevice!.requestWithoutResponse = true;
        
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

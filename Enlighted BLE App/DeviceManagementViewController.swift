//
//  DeviceManagementViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceManagementViewController: UIViewController, CBPeripheralManagerDelegate, UITextFieldDelegate
{
    
    //MARK: Properties

    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var nicknameField: UITextField!
    
    @IBOutlet weak var batteryStatusImage: UIImageView!
    @IBOutlet weak var batteryPercentageLabel: UILabel!
    @IBOutlet weak var batteryPercentage: UILabel!
    
    @IBOutlet weak var brightnessSlider: UISlider!
    
    @IBOutlet weak var revertSettingsButton: UIButton!
    
    // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    var batteryIcons = [UIImage]();
    
    var batteryRefreshTimer = Timer();
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // from: https://stackoverflow.com/questions/17209468/how-to-disable-back-swipe-gesture-in-uinavigationcontroller-on-ios-7
        
        // disabling the "swipe back" hand control
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
            // setting the device name
        deviceNameLabel.text = Device.connectedDevice?.name;
        
            // setting the nickname editor delegate
        nicknameField.delegate = self;
        
            // creating references to the battery images
        batteryIcons.append(UIImage(named: "BatteryEmpty")!);
        batteryIcons.append(UIImage(named: "Battery1")!);
        batteryIcons.append(UIImage(named: "Battery2")!);
        batteryIcons.append(UIImage(named: "Battery3")!);
        batteryIcons.append(UIImage(named: "Battery4")!);
        
        
            // formatting the battery image to allow it to be tinted
        batteryStatusImage.image = batteryStatusImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        
            // setting this as the delegate of the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil);
        
            // updating the battery percentage to display the percentage (temporarily).  200 means the battery value isn't readable
        batteryPercentage.text = String((Device.connectedDevice?.batteryPercentage)!) + "%";
        
            // updating the battery image to match the percentage
        let batteryInt = (Device.connectedDevice?.batteryPercentage)!;
        batteryStatusImage.image = getBatteryImageForPercentage(batteryInt);
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateBrightnessValue), name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BRIGHTNESS_VALUE), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateBatteryPercentage), name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_BATTERY_VALUE), object: nil)
        
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        requestBatteryPercentage();
        
        nicknameField.text = Device.connectedDevice?.nickname;
        
        // getting and updating the slider with the device's brightness
        brightnessSlider.value = Float((Device.connectedDevice?.brightness)!);
        batteryPercentage.text = String((Device.connectedDevice?.batteryPercentage)!) + "%";
        
            // revert settings button is hidden if it's a demo device, since it would be tricky and useless to implement separately (No longer in 1.0.5)
        //revertSettingsButton.isHidden = Device.connectedDevice!.isDemoDevice;
        
            // creating a timer to scan and update battery level (as of 1.0.2, we don't do this anymore)
        //batteryRefreshTimer = Timer.scheduledTimer(timeInterval: Constants.BATTERY_SCAN_INTERVAL, target: self, selector: #selector(requestBatteryPercentage), userInfo: nil, repeats: true);
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
            // stop the timer before we leave this screen
        //self.batteryRefreshTimer.invalidate();
        print("Removing DeviceManagementViewController's observers (in viewWillDisappear)");
        NotificationCenter.default.removeObserver(self);
        
        super.viewWillDisappear(animated);
    }
    
    @IBAction func dismissPopup(_ sender: UIButton)
    {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func changeBrightness(_ sender: UISlider)
    {
            // don't send a BLE request if it's a demo device
        if (Device.connectedDevice!.isDemoDevice)
        {
            return;
        }
        else if (!(Device.connectedDevice?.isConnected)!)
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
        
        print("New slider value: \(sender.value)");
        Device.connectedDevice?.brightness = Int(sender.value);
        
            // converting to an unsigned byte integer, to be passed to the hardware
        var brightnessIndexUInt: UInt8 = UInt8(Device.connectedDevice!.brightness);
        
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BRIGHTNESS;// + "\(modeIndexUInt)";
        //print(valueString);
        let stringArray: [UInt8] = Array(valueString.utf8);
        let valueArray = stringArray + [brightnessIndexUInt]
        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: valueArray.count)
        
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
        
    }
    
    
    
    
    
    // MARK: Actions
    
        // hide the keyboard when the "done" key is pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        nicknameField.resignFirstResponder();
        return true;
    }
    
    @IBAction func changedDeviceNickname(_ sender: UITextField)
    {
        Device.connectedDevice?.nickname = sender.text ?? "";
    }
    
    @IBAction func RevertToOriginalSettings(_ sender: UIButton)
    {
        // creating the dialog message
        let dialogMessage = UIAlertController(title:"Confirm", message: "Are you sure you want to reload hardware settings?  Your changes will be lost.", preferredStyle: .alert);
        
        // defining the confirm / revert button
        let revert = UIAlertAction(title: "Reload", style: .default, handler:
        {(action) -> Void in
            
                // if it's the demo mode, we don't want to be messing with caches
            if (Device.connectedDevice!.isDemoDevice)
            {
                    // basically, creating a new demo device without any user changes
                Device.setConnectedDevice(newDevice: Device.createDemoDevice());
            }
                // otherwise, clear everything and let the app get it all back from the hardware
            else
            {
                // clear mode list
                Device.connectedDevice?.modes = [Mode]();
                // clear thumbnail list
                Device.connectedDevice?.thumbnails = [UIImage]();
                // clear current thumbnail row
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RESEND_THUMBNAIL_ROW), object: nil);
                
            }
                // credit to https://stackoverflow.com/questions/28190070/swift-poptoviewcontroller for navigating to a specific viewController
            
                // finding the index of the "Choose Mode" screen on the navigation stack
            let modeTableVCIndex = self.navigationController?.viewControllers.firstIndex(where:
            {(viewController) -> Bool in
                if let _ = viewController as? ModeTableViewController
                {
                    return true;
                }
                return false;
            })
            
                // getting a reference to that specific screen using the index we just found
            let modeTableVC = self.navigationController?.viewControllers[modeTableVCIndex!] as! ModeTableViewController;
            
                // navigating back to that screen (at which point SetUpTable() should re-read values from the hardware)
            _ = self.navigationController?.popToViewController(modeTableVC, animated: true)
            
            print("Reverted to default settings");
        })
        
        // defining the cancel button
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        { (action) -> Void in
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
    
        // getting the battery value from the hardware
    @objc private func requestBatteryPercentage()
    {
        getValue(EnlightedBLEProtocol.ENL_BLE_GET_BATTERY_LEVEL);
    }
    
        // updating the battery percentage to what we read from hardware
    @objc private func updateBatteryPercentage()
    {
        batteryPercentage.text = String((Device.connectedDevice?.batteryPercentage)!) + "%";
            // updating the battery image to match the percentage
        let batteryInt = (Device.connectedDevice?.batteryPercentage)!;
        batteryStatusImage.image = getBatteryImageForPercentage(batteryInt);
    }
    
        // updating the brightness slider based on new values from hardware
    @objc private func updateBrightnessValue()
    {
        brightnessSlider.value = Float((Device.connectedDevice?.brightness)!);
        
        requestBatteryPercentage();
    }
    
        // sends get commands to the hardware, using the protocol as the inputString
    private func getValue(_ inputString: String)
    {
            // don't use BLE commands if it's a demo device
        if (Device.connectedDevice!.isDemoDevice)
        {
            return;
        }
        else if (Device.connectedDevice?.requestWithoutResponse ?? false)
        {
            print("Currently pending request, delaying new request");
            return;
        }
        else if (!(Device.connectedDevice?.isConnected)!)
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
        
        let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
        // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: inputNSString! as NSData, sendToMimicDevices: false)
        
    }
    
    private func getBatteryImageForPercentage(_ batteryInt: Int) -> UIImage
    {
        var batteryImage: UIImage;
        
        if (batteryInt <= 10)
        {
            batteryImage = batteryIcons[0];
        }
            // the icon shows 25%, + 5% buffer
        else if (batteryInt <= 30)
        {
            batteryImage = batteryIcons[1];
        }
            // the icon shows 50%, + 5% buffer
        else if (batteryInt <= 55)
        {
            batteryImage = batteryIcons[2];
        }
            // the icon shows 75%, + 5% buffer
        else if (batteryInt <= 80)
        {
            batteryImage = batteryIcons[3];
        }
        else //(batteryInt <= 100)
        {
            batteryImage = batteryIcons[4];
        }
        
            // allowing the image to be recolored
        batteryImage = batteryImage.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        
        return batteryImage;
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

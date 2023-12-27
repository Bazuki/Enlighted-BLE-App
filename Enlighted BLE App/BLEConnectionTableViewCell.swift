//
//  BLEConnectionTableViewCell.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class BLEConnectionTableViewCell: UITableViewCell
{

    // MARK: Properties
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var nicknameLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var RSSIValue: UILabel!
    @IBOutlet weak var RSSILabel: UILabel!
    @IBOutlet weak var connectionImage: UIImageView!
    @IBOutlet weak var connectButton: UIButton!
    
    var device: Device!;
    
    var cellIsSelected = false;
    
    var isDemoDevice = false;
    
    var timer = Timer();
    var connectTime = 1;
    
    var connectionIcons = [UIImage]();
    
    //selected history variables
    private var wasSelected = false;
    private var wasWasSelected = false;
    private var oldDevice: Device? = nil;
    
    public static var gHideCarrots = false;
    
    override func awakeFromNib()
    {
        super.awakeFromNib();
        // Initialization code
        
        // creating references to the connection images
        connectionIcons.append(UIImage(named: "Signal0")!);
        connectionIcons.append(UIImage(named: "Signal1")!);
        connectionIcons.append(UIImage(named: "Signal2")!);
        connectionIcons.append(UIImage(named: "Signal3")!);
        connectionIcons.append(UIImage(named: "NoSignal")!);
        
            // allowing it to be recolored
        connectionIcons[4] = connectionIcons[4].withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        
        
        self.wasSelected = false;
        BLEConnectionTableViewCell.gHideCarrots = false;
        
        //connectButton.isEnabled = false;
        
            // Formatting the images to allow for recoloration
        connectionImage.image = connectionImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
            //recoloring doesn't allow for enabling/disabling graphics
        //connectButton.imageView?.image = connectButton.imageView?.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        NotificationCenter.default.addObserver(self, selector: #selector(enableButton), name: Notification.Name(rawValue: Constants.MESSAGES.DISCOVERED_PRIMARY_CHARACTERISTICS), object: nil)
    }
    
    func setDisconnectPressed(_ pressed: Bool)
    {
        BLEConnectionTableViewCell.gHideCarrots = pressed;
    }
    
    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)
        //print("setSelected(\(selected)) called");
        let isSelected = selected;
        //self.wasSelected = false;
        //self.wasWasSelected = false;
        
        
        if (isDemoDevice)
        {
            connectButton.isEnabled = true;
            //connectButton.tintColor = UIColor.white;
        }
        
        
            // button is disabled by default until the device is connected
//        else if (selected && !wasSelected)// && Device.connectedDevice?.isConnecting ?? false)
//        {
//
//            connectButton.isEnabled = Device.connectedDevice?.isConnected ?? false;
//            //timer = Timer.scheduledTimer(timeInterval: TimeInterval(connectTime), target: self, selector: #selector(self.enableButton), userInfo: nil, repeats: true);
//        }
        /*
         Logic Table for wasWasSelected, wasSelected, and isSelected
         WWS    WS     IS
         -----------------
         0      0       0   -not selected
         0      0       1   -selected for the first time(TURN ON CARROT AFTER DELAY)
         0      1       0   -alternating OR unselected for the first time
         0      1       1   -SHOULD NEVER HAPPEN
         1      0       0   -unselected for the first time(TURN OFF CARROT; THIS CAUSES LATENCY)
         1      0       1   -alternating
         1      1       0   -SHOULD NEVER HAPPEN
         1      1       1   -SHOULD NEVER HAPPEN
         
         In addition, gHideCarrots will be set to true by the disconnect button or when a different peripheral is selected, reducing latency
         */
        
        
        //print("###" + String(wasWasSelected) + "," + String(wasSelected) + "," + String(selected) + "###");
        /*
         This part is being weird, this is what controls when the arrow shows up.  setSelected gets called by UIKit every time a cell is selected, so it seems like we just have to deal with it.  As of 3/6/23, I have it printing the cell device's name and the name of the connected device, and I'm trying to include that in the conditional so that it will only let the cell show it's arrow if that cell represents the device that's connected (using UUID not names), but thats also not working.
         
         
         */
        
        if(BLEConnectionTableViewCell.gHideCarrots){
            //isSelected = false;
            //wasSelected = false;
            self.connectButton.isHidden = true;
            BLEConnectionTableViewCell.gHideCarrots = false;
            //print("BUTTONSTATE: hiding button");
        }
        else if(!self.wasSelected && isSelected){
            BLEConnectionTableViewCell.gHideCarrots = false;
            if (((Device.connectedDevice?.isConnected) != nil) && Device.connectedDevice?.UUID == self.device.UUID){
                //Maybe TODO: make this delay slightly shorter
                if (self.oldDevice == Device.connectedDevice){
                    print("Old device reconnected");
                    self.connectButton.isHidden = false;
                    self.enableButton()
                }
                else{
                    print("Delaying Button");
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75){
                        self.connectButton.isHidden = false;
                        self.enableButton()
                        //print("cell: ", self.device.name, "Connected to:", Device.connectedDevice?.name ?? "name", " BUTTONSTATE: showing button");
                    }
                }
            }
        }
        else if(!self.wasSelected && isSelected) {
            //print("cell: ", self.device.name, "Connected to:", Device.connectedDevice?.name ?? "name", " BUTTONSTATE: alternating");
        }
        else if(!self.wasSelected && !isSelected){
            self.connectButton.isHidden = true;
            //print(self.deviceNameLabel.text ?? "name", "BUTTONSTATE: unselected");
            
        }
        self.wasWasSelected = wasSelected;
        self.wasSelected = isSelected;
        self.oldDevice = Device.connectedDevice;
        
        
        
        
            // Configure the view for the selected state
        
        if (selected)
        {
            backgroundColor = UIColor(named: "SelectedModeBackground");
            connectionImage.tintColor = UIColor(named: "Title");
            nicknameLabel.textColor = UIColor(named: "Subtitle");
            deviceNameLabel.textColor = UIColor(named: "SelectedText");
            RSSILabel.textColor = UIColor(named: "Title");
            RSSIValue.textColor = UIColor(named: "Title");
        }
        else
        {
            backgroundColor = UIColor.clear;
            connectionImage.tintColor = UIColor(named: "NonSelectedText");
            deviceNameLabel.textColor = UIColor(named: "Title");
            nicknameLabel.textColor = UIColor(named: "Subtitle");
            RSSILabel.textColor = UIColor(named: "NonSelectedText");
            RSSIValue.textColor = UIColor(named: "NonSelectedText");
        }
    }
    
    func setNickname(_ newNickname: String)
    {
        if (newNickname.elementsEqual(""))
        {
            nicknameLabelHeight.constant = 0;
        }
        else
        {
            nicknameLabelHeight.constant = 13;
        }
        nicknameLabel.text = newNickname;
    }
    
    func updateRSSIValue(_ newRSSI: Int)
    {
            // 127 is a sort of nil value, and so will be ignored (if the device is truly disconnected, it will be removed within half a second).
        if (newRSSI == 127)
        {
            return;
        }
        else
        {
            //self.device.RSSI = newRSSI;
                // if it's a demo device, there obviously isn't a real RSSI, so show a descriptive message instead
            if (isDemoDevice)
            {
                connectionImage.image = connectionIcons[4];
                RSSIValue.text = "No Enlighted device found";
                //RSSILabel.isHidden = true;
            }
            else
            {
                connectionImage.image = getImageForRSSI(newRSSI);
                RSSIValue.text = "RSSI: " + String(newRSSI);
                //RSSILabel.isHidden = false;
            }
            
        }
    }
    
    @objc func enableButton()
    {
        
        print("\(Device.connectedDevice!.name): ");
        print("     is connected: \((Device.connectedDevice?.isConnected)!)");
        print("     is the same as this cell's device, \(device.name): \(Device.connectedDevice == device)");
        print("     and has discovered its characteristics: \((Device.connectedDevice?.hasDiscoveredCharacteristics)!)");
        
            // if the device (that this cell is responsible for) is successfully connected, enable the button
        if ((Device.connectedDevice?.hasDiscoveredCharacteristics)! && (Device.connectedDevice?.isConnected)! && Device.connectedDevice == device)
        {
            //timer.invalidate();
            connectButton.isEnabled = true;
            print("Enabling button");
            
            //timer.invalidate();
        }
        else
        {
            connectButton.isEnabled = false;
            print("Not connected yet, keeping button disabled");
        }
        
    }
    
        // using the right connection image for the RSSI value (based on my measurement, ranges from about -40 close to -100 far before disconnecting?
    func getImageForRSSI(_ RSSI: Int) -> UIImage
    {
        var RSSIImage: UIImage;
        
        if (RSSI > -50)
        {
            RSSIImage = connectionIcons[3];
        }
        else if (RSSI > -60)
        {
            RSSIImage = connectionIcons[2];
        }
        else if (RSSI > -70)
        {
            RSSIImage = connectionIcons[1];
        }
        else
        {
            RSSIImage = connectionIcons[0];
        }
        
            // allowing for recoloring
        RSSIImage = RSSIImage.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        return RSSIImage;
    }
    
}

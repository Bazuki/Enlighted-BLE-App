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
    
    var wasSelected = false;
    
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
        
        
        wasSelected = false;
        
            // Formatting the images to allow for recoloration
        connectionImage.image = connectionImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
            //recoloring doesn't allow for enabling/disabling graphics
        //connectButton.imageView?.image = connectButton.imageView?.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        NotificationCenter.default.addObserver(self, selector: #selector(enableButton), name: Notification.Name(rawValue: "didDiscoverPeripheralCharacteristics"), object: nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)
        
        //print("setSelected(\(selected)) called");
        
        
        if (isDemoDevice)
        {
            connectButton.isEnabled = true;
        }
            // button is disabled by default until the device is connected
        else if (selected && !wasSelected)// && Device.connectedDevice?.isConnecting ?? false)
        {
            
            connectButton.isEnabled = Device.connectedDevice?.isConnected ?? false;
            //timer = Timer.scheduledTimer(timeInterval: TimeInterval(connectTime), target: self, selector: #selector(self.enableButton), userInfo: nil, repeats: true);
        }
        
        
        wasSelected = selected;
        
        connectButton.isHidden = !selected;
        
        
            // Configure the view for the selected state
        
        if (selected)
        {
            backgroundColor = UIColor(named: "SelectedModeBackground");
            connectionImage.tintColor = UIColor(named: "Title");
            deviceNameLabel.textColor = UIColor(named: "SelectedText");
            RSSILabel.textColor = UIColor(named: "Title");
            RSSIValue.textColor = UIColor(named: "Title");
        }
        else
        {
            backgroundColor = UIColor.clear;
            connectionImage.tintColor = UIColor(named: "NonSelectedText");
            deviceNameLabel.textColor = UIColor(named: "Title");
            RSSILabel.textColor = UIColor(named: "NonSelectedText");
            RSSIValue.textColor = UIColor(named: "NonSelectedText");
        }
        
        
        
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
                RSSIValue.text = "No Enlighted hardware found";
                //RSSILabel.isHidden = true;
            }
            else
            {
                connectionImage.image = getImageForRSSI(newRSSI);
                RSSIValue.text = String(newRSSI);
                //RSSILabel.isHidden = false;
            }
            
        }
    }
    
    @objc func enableButton()
    {
            // if the device is successfully connected, enable the button
        if ((Device.connectedDevice?.hasDiscoveredCharacteristics)! && (Device.connectedDevice?.isConnected)!)
        {
            //timer.invalidate();
            connectButton.isEnabled = true;
            print("Enabling button");
            //timer.invalidate();
        }
        else
        {
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

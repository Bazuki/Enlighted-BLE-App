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
    
    var timer = Timer();
    var connectTime = 1;
    
    var wasSelected = false;
    
    override func awakeFromNib()
    {
        super.awakeFromNib();
        // Initialization code
        
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
        
        
        
            // button is disabled by default until the device is connected
        //print("Is the device connected? \(Device.connectedDevice?.isConnected ?? true)");
        if (selected && !wasSelected)// && Device.connectedDevice?.isConnecting ?? false)
        {
            
            connectButton.isEnabled = false;
            //timer = Timer.scheduledTimer(timeInterval: TimeInterval(connectTime), target: self, selector: #selector(self.enableButton), userInfo: nil, repeats: true);
        }
        
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
        
        wasSelected = selected;
        
    }
    
    @objc func enableButton()
    {
            // if the device is successfully connected, stop the timer and enable the button
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
    
}

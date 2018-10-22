//
//  BLEConnectionTableViewCell.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/24/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class BLEConnectionTableViewCell: UITableViewCell
{

    // MARK: Properties
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var RSSIValue: UILabel!
    @IBOutlet weak var RSSILabel: UILabel!
    @IBOutlet weak var connectionImage: UIImageView!
    @IBOutlet weak var connectButton: UIButton!
    
    var device: Device!;
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
            // Formatting the image to allow for recoloration
        connectionImage.image = connectionImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        connectButton.isHidden = !selected;
        
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
    
    @IBAction func setConnectedDevice(_ sender: UIButton)
    {
        //Device.setConnectedDevice(newDevice:self.device);
            // connect to this cell's device's peripheral, if it has one (should have one unless it's running on the simlulator without Bluetooth);
        //BLEConnectionTableViewController.connectToDevice(self.device.peripheral!);
    }
    
}

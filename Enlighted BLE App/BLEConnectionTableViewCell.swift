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
    
    var cellIsSelected = false;
    
    var timer = Timer();
    var connectTime = 2;
    
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
        
        cellIsSelected = selected;
        
        connectButton.isHidden = !selected;
            // button is disabled by default for a bit to allow the device to connect
        
        
        if (selected && !(Device.connectedDevice?.isConnected ?? false))
        {
            connectButton.isEnabled = false;
            timer = Timer.scheduledTimer(timeInterval: TimeInterval(connectTime), target: self, selector: #selector(enableButton), userInfo: nil, repeats: false)
        }
        
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
    
    @objc func enableButton()
    {
        connectButton.isEnabled = true;
    }
    
}

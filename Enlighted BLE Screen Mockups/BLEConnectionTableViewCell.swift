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
    
    var device = Device(name:"none");
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func setConnectedDevice(_ sender: UIButton)
    {
        Device.setConnectedDevice(newDevice:self.device);
    }
    
}

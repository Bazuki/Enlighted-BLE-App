//
//  MimicTableViewCell.swift
//  Enlighted BLE App
//
//  Created by Bryce Suzuki on 8/4/19.
//  Copyright © 2019 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth;


class MimicTableViewCell: UITableViewCell
{
    
    // properties

    @IBOutlet weak var connectionImage: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var RSSIValueLabel: UILabel!
    @IBOutlet weak var mimicStatusSwitch: UISwitch!
    
    var peripheral: CBPeripheral?;
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
            // disabling the switch
        mimicStatusSwitch.isOn = false;
    }

    @IBAction func mimicSwitchFlipped(_ sender: UISwitch)
    {
            // if the user switched the switch on
        if (sender.isOn)
        {
                // and the device's NSUUID isn't yet in the mimic list
            if (!Device.connectedDevice!.mimicList.contains(peripheral?.identifier as! NSUUID))
            {
                    // add it
                Device.connectedDevice!.mimicList.append(peripheral?.identifier as! NSUUID);
            }
        }
            // otherwise if they switched it off
        else
        {
                // and the device's NSUUID is currently in the mimic list
            if (Device.connectedDevice!.mimicList.contains(peripheral?.identifier as! NSUUID))
            {
                    // remove it
                Device.connectedDevice!.mimicList.remove(at: Device.connectedDevice!.mimicList.firstIndex(of: (peripheral?.identifier as! NSUUID))!);
            }
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

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
    var NSUUID: NSUUID?;
    var isOn = false;
    var connectionIcons = [UIImage]();
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
        
        // creating references to the connection images
        connectionIcons.append(UIImage(named: "Signal0")!);
        connectionIcons.append(UIImage(named: "Signal1")!);
        connectionIcons.append(UIImage(named: "Signal2")!);
        connectionIcons.append(UIImage(named: "Signal3")!);
        connectionIcons.append(UIImage(named: "NoSignal")!);
        
        // allowing it to be recolored
        connectionIcons[4] = connectionIcons[4].withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        connectionIcons[3] = connectionIcons[3].withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        
        // Formatting the images to allow for recoloration
        connectionImage.image = connectionImage.image?.withRenderingMode(UIImageRenderingMode.alwaysTemplate);
        
        if (isOn)
        {
            deviceNameLabel.textColor = UIColor(named: "SelectedText");
        }
        else
        {
            deviceNameLabel.textColor = UIColor(named: "NonSelectedText");
        }
        
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
                Device.connectedDevice!.mimicListNames.append((peripheral?.name)!);
            }
        }
            // otherwise if they switched it off
        else
        {
                // if this cell represents a currently enabled device
            if (isOn)
            {
                    // and the device's NSUUID is currently in the mimic list
                if (Device.connectedDevice!.mimicList.contains(peripheral?.identifier as! NSUUID))
                {
                        // remove it
                    Device.connectedDevice!.mimicListNames.remove(at: Device.connectedDevice!.mimicList.firstIndex(of: (peripheral?.identifier as! NSUUID))!)
                    Device.connectedDevice!.mimicList.remove(at: Device.connectedDevice!.mimicList.firstIndex(of: (peripheral?.identifier as! NSUUID))!);
                }
            }
            else
            {
                    // otherwise, remove it;  if it's being shown despite not being on, it must be on the mimic list
                Device.connectedDevice!.mimicListNames.remove(at: Device.connectedDevice!.mimicList.firstIndex(of: (self.NSUUID!))!);
                Device.connectedDevice!.mimicList.remove(at: Device.connectedDevice!.mimicList.firstIndex(of: (self.NSUUID!))!);
            }
            
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        if (isOn)
        {
            deviceNameLabel.textColor = UIColor(named: "SelectedText");
        }
        else
        {
            deviceNameLabel.textColor = UIColor(named: "NonSelectedText");
        }
        
        // Configure the view for the selected state
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
            if (!isOn)
            {
                connectionImage.image = connectionIcons[4];
                RSSIValueLabel.text = "Not found";
                //RSSIValueLabel.text = "No Enlighted device found";
                //RSSILabel.isHidden = true;
            }
                // special value for connected devices
            else if (newRSSI == -1)
            {
                RSSIValueLabel.text = "Connected";
                connectionImage.image = connectionIcons[3];
            }
            else
            {
                connectionImage.image = getImageForRSSI(newRSSI);
                RSSIValueLabel.text = "RSSI: " + String(newRSSI);
                //RSSILabel.isHidden = false;
            }
            
        }
    }
    
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

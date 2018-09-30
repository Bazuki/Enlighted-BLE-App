//
//  DeviceManagementViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class DeviceManagementViewController: UIViewController
{

    @IBOutlet weak var deviceNameLabel: UILabel!
    
    @IBOutlet weak var brightnessSlider: UISlider!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        deviceNameLabel.text = Device.connectedDevice?.name;
        brightnessSlider.value = Float((Device.connectedDevice?.brightness)!);
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
        Device.connectedDevice?.brightness = Int(sender.value);
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

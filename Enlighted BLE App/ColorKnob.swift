//
//  ColorKnob.swift
//  Enlighted BLE App
//
//  Created by Bryce Suzuki on 12/26/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class ColorKnob: UIView
{
    var ownerColorWheel: ColorWheel?
    
    override func draw(_ rect: CGRect)
    {
        layer.backgroundColor = (UIColor.clear as! CGColor);
        layer.borderColor = (UIColor.white as! CGColor);
        layer.borderWidth = 1;
    }
    
    public func setOwnerColorWheel(owner: ColorWheel)
    {
        ownerColorWheel = owner;
    }
}


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
    var ownerColorWheel: ColorWheel?;
    var strokeWidth: CGFloat = 1;
    
    override func draw(_ rect: CGRect)
    {
        let insetRect = rect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2);
        let path = UIBezierPath(ovalIn: insetRect)
        self.backgroundColor = UIColor.clear;
        
            // creating a border
        path.lineWidth = strokeWidth;
        UIColor.white.setStroke();
        path.stroke();
        //layer.borderColor = (UIColor.white as! CGColor);
        //layer.borderWidth = 1;
    }
    
    public func setOwnerColorWheel(owner: ColorWheel)
    {
        ownerColorWheel = owner;
    }
    
    override public init(frame: CGRect)
    {
        super.init(frame: frame);
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


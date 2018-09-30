//
//  ColorPreview.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

@IBDesignable
class ColorPreview: UIView
{
    
    // MARK: Properties
    
    var myColor = UIColor.clear;
    var highlighted = false;
    var strokeWidth = 4.0;
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect)
    {
            // defining a smaller rect to draw the oval in so that the stroke doesn't go out of the UIView's bounds
        let insetRect = rect.insetBy(dx: CGFloat(strokeWidth / 2), dy: CGFloat(strokeWidth / 2))
        
        backgroundColor = UIColor.clear;
        let path = UIBezierPath(ovalIn: insetRect)
        myColor.setFill();
        
        path.fill();
        
        // add a white outline if the preview is highlighted (which should only happen on the edit mode screen)
        if (highlighted)
        {
            path.lineWidth = CGFloat(strokeWidth);
            UIColor.white.setStroke();
            path.stroke();
        }
        
    }
 
    
    public func setBackgroundColor(newColor: UIColor)
    {
        myColor = newColor;
        backgroundColor = UIColor.clear;
        setNeedsDisplay();
    }
    
    public func setHighlighted(_ highlighted: Bool)
    {
        // set the highlight status
        self.highlighted = highlighted;
        
        // update the display
        setNeedsDisplay();
    }

}

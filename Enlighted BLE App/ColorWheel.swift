//
//  ColorWheel.swift
//  Enlighted BLE App
//
//  Created by Bryce Suzuki on 12/26/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;

@IBDesignable
class ColorWheel: UIView
{
    
    var radius: Float = 0.0;
    var knobRadius: Float = 0.0;
    
    var color = UIColor.white;
        // hue as an angle in radians across the color wheel from 0 to 2π
    var hue = 0.0;
    var saturation = 0.0;
    var brightness = 0.0;
    var centerPoint = CGPoint(x: 0, y: 0);
    var knobPosition = CGPoint(x: 0, y: 0);
    
    var knob: ColorKnob?;
    
    var viewController: EditScreenViewController?;
    
    override func draw(_ rect: CGRect)
    {
        

    }
    
    public func initializeColorWheel(radius: Float, color: UIColor, owner: EditScreenViewController, knob: ColorKnob, knobRadius: Float)
    {
        self.viewController = owner;
        self.radius = radius;
        centerPoint = CGPoint(x: CGFloat(radius), y: CGFloat(radius));
        self.knob = knob;
        self.knobRadius = knobRadius;
        
            // adding the knob as a subview of this view
        self.addSubview(knob);
    }
    
    public func setColor(newColor: UIColor)
    {
            // turning UIColor to HSB
        var hueCG: CGFloat = 0;
        var saturationCG: CGFloat = 0;
        var brightnessCG: CGFloat = 0;
        var alphaCG: CGFloat = 0;
        let _ = color.getHue(&hueCG, saturation: &saturationCG, brightness: &brightnessCG, alpha: &alphaCG);
        
        // converting to radians
        hueCG *= CGFloat.pi * 2;
        // multiplying for the radius
        saturationCG *= CGFloat(radius);
        
        knobPosition = CGPoint(x: centerPoint.x + (CGFloat(cosf(Float(hueCG))) * saturationCG), y: centerPoint.y + (CGFloat(sinf(Float(hueCG))) * saturationCG));
        
            // setting the knob's frame (including location)
        knob?.frame = CGRect(x: knobPosition.x, y: knobPosition.y, width: CGFloat(knobRadius) * 2, height: CGFloat(knobRadius) * 2);
        
            // update display
        setNeedsDisplay();
    }
    
        // generating a UIColor from the slider
    public func getColor() -> UIColor
    {
            // hue is the angle of the knob relative to the center of the view
        let newHue: Float = tanf(Float((knob?.frame.midY ?? 0 - centerPoint.y) / (knob?.frame.midX ?? 0 - centerPoint.x))) / (Float.pi * 2);
            // saturation is the magnitude of the vector from the center, found using pythagorean theorem
        let newSaturation: Float = sqrt(Float(pow((knob?.frame.midY ?? 0 - centerPoint.y), 2) + pow((knob?.frame.midX ?? 0 - centerPoint.x), 2)));
        return UIColor(hue: CGFloat(newHue), saturation: CGFloat(newSaturation), brightness: CGFloat(brightness), alpha: 1);
    }
    
}


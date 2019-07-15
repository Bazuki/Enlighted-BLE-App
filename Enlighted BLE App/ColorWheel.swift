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
        // hue from 0 to 1?   an angle in radians across the color wheel from 0 to 2π
    public var hue: CGFloat = 0.0;
    public var saturation: CGFloat = 0.0;
    var brightness: CGFloat = 0.0;
    var centerPoint = CGPoint(x: 0, y: 0);
    var knobPosition = CGPoint(x: 0, y: 0);
    
    var knob: ColorKnob?;
    
    var viewController: EditScreenViewController?;
    
    override func draw(_ rect: CGRect)
    {
            // updating the centerPoint
        var newCenter = rect.origin;
        newCenter.x = newCenter.x + rect.width / 2;
        newCenter.y = newCenter.y + rect.height / 2;
        centerPoint = newCenter;
        
        if (!self.isHidden)
        {
            let insetRect = rect.insetBy(dx: (rect.maxX / 2) - CGFloat(radius), dy: (rect.maxY / 2) - CGFloat(radius));
            let path = UIBezierPath(ovalIn: insetRect);
            //layer.backgroundColor = (UIColor.clear as! CGColor);

                // filling with black scaled to brightness to change wheel
            UIColor.black.setFill();
            
            guard let newBrightness = viewController?.brightness else
            {
                return;
            }
            path.fill(with: CGBlendMode.copy, alpha: (max(min(1.0 - newBrightness, 1), 0)));
        }
        // temporary outline
//        path.lineWidth = 2;
//        UIColor.white.setStroke();
//        path.stroke();
    }
    
    
    @objc func finishedDraggingKnob(_ recognizer: UIPanGestureRecognizer)
    {
        switch(recognizer.state)
        {
            
        case UIGestureRecognizerState.began:
            let newPosition = recognizer.location(in: self);
            let xDist = centerPoint.x - newPosition.x;
            let yDist = centerPoint.y - newPosition.y;
            let distance = sqrt(xDist * xDist + yDist * yDist);
            
            // if the tap was within the wheel (+ the knob's radius as buffer)
            if (distance < (CGFloat(radius + knobRadius)))
            {
                // move the knob there
                knobPosition = newPosition;
                moveKnob(goal: knobPosition);
                
                let newColor = getColor();
                
                if (viewController?.getCurrentColorIndex() == 1)
                {
                    viewController?.color1Selector.setBackgroundColor(newColor: newColor);
                }
                else
                {
                    viewController?.color2Selector.setBackgroundColor(newColor: newColor);
                }
                
                viewController?.brightnessSlider.minimumTrackTintColor = newColor;
                viewController?.brightnessSlider.maximumTrackTintColor = newColor;
            }
            break
            
        case UIGestureRecognizerState.changed:
            let knobPosition = recognizer.location(in: self);
            moveKnob(goal: knobPosition);
            
            let newColor = getColor();
            
            if (viewController?.getCurrentColorIndex() == 1)
            {
                viewController?.color1Selector.setBackgroundColor(newColor: newColor);
            }
            else
            {
                viewController?.color2Selector.setBackgroundColor(newColor: newColor);
            }
            
            viewController?.brightnessSlider.minimumTrackTintColor = newColor;
            viewController?.brightnessSlider.maximumTrackTintColor = newColor;
            
            //knob?.frame.midY = knobPosition.y;
            //getColor();
            break
            
        case UIGestureRecognizerState.ended:
                // updating the view controller upon release
            if (viewController?.getCurrentColorIndex() == 1)
            {
                viewController?.color1History += [getColor()];
            }
            else
            {
                viewController?.color2History += [getColor()];
            }
            viewController?.updateColorPicker(getColor(), fromPicker: true);
            break
            
        default:
            break
        }
    }
    
    @objc func tappedWheel(_ recognizer: UITapGestureRecognizer)
    {
        
        let newPosition = recognizer.location(in: self);
        let xDist = centerPoint.x - newPosition.x;
        let yDist = centerPoint.y - newPosition.y;
        let distance = sqrt(xDist * xDist + yDist * yDist);
        
            // if the tap was within the wheel (+ the knob's radius as buffer)
        if (distance < (CGFloat(radius + knobRadius)))
        {
            // move the knob there
            knobPosition = newPosition;
            moveKnob(goal: knobPosition);
            
            let newColor = getColor();
            
            if (viewController?.getCurrentColorIndex() == 1)
            {
                viewController?.color1Selector.setBackgroundColor(newColor: newColor);
            }
            else
            {
                viewController?.color2Selector.setBackgroundColor(newColor: newColor);
            }
            
            viewController?.brightnessSlider.minimumTrackTintColor = newColor;
            viewController?.brightnessSlider.maximumTrackTintColor = newColor;
            
            // updating the view controller upon release
            if (viewController?.getCurrentColorIndex() == 1)
            {
                viewController?.color1History += [getColor()];
            }
            else
            {
                viewController?.color2History += [getColor()];
            }
            viewController?.updateColorPicker(getColor(), fromPicker: true);
        }
        
    }
    
        // locking the control to be within the circle
    private func moveKnob(goal: CGPoint)
    {
        let xDist = centerPoint.x - goal.x;
        let yDist = centerPoint.y - goal.y;
        let distance = sqrt(xDist * xDist + yDist * yDist);
        
            // if the point is outside the zone
        if (distance > CGFloat(radius))
        {
                // angle of the knob relative to the center of the view
            let deltaX = Float(centerPoint.x - (goal.x));
            let deltaY = Float(centerPoint.y - (goal.y));
                // returns between -π and π
            var angle: Float = atan2f(deltaX, deltaY)
            
                // adjusting range
            angle += Float.pi / 2;
            if (angle < 0)
            {
                angle += Float.pi * 2;
            }
            
            let newGoal = CGPoint(x: centerPoint.x + (CGFloat(cosf(angle) * radius)), y: centerPoint.y - (CGFloat(sinf(angle) * radius)));
            
            knob?.center = newGoal;
        }
        else
        {
            knob?.center = goal;
        }
    }
    
    // MARK: - Public Methods
    
        // setting up the color wheel
    public func initializeColorWheel(radius: Float, color: UIColor, owner: EditScreenViewController, knobRadius: Float)
    {
        self.viewController = owner;
        self.radius = radius;
        
        let insetRect = self.frame.insetBy(dx: (self.frame.maxX / 2) - CGFloat(radius), dy: (self.frame.maxY / 2) - CGFloat(radius));
        
        centerPoint = CGPoint(x: insetRect.midX, y: insetRect.midY);//CGPoint(x: owner.colorImage.frame.midX, y: owner.colorImage.frame.midY); //self.center; //CGPoint(x: self.bounds.midX, y: self.bounds.midY);
        //self.knob = knob;
        self.knobRadius = knobRadius;
        knobPosition = centerPoint;
        
        knob = ColorKnob(frame: CGRect(x: knobPosition.x, y: knobPosition.y, width: CGFloat(knobRadius) * 2, height: CGFloat(knobRadius) * 2));
        knob?.isOpaque = false;
        
            // adding a touch recognizer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedWheel));
        self.addGestureRecognizer(tapRecognizer)
        
            // adding a pan recognizer
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(finishedDraggingKnob));
        self.addGestureRecognizer(panRecognizer);
        
        
        // adding the knob as a subview of this view
        self.addSubview(knob!);
        
        setNeedsDisplay();
    }
    
    public func setColor(newColor: UIColor)
    {
            // turning UIColor to HSB
        var hueCG: CGFloat = 0;
        var saturationCG: CGFloat = 0;
        var brightnessCG: CGFloat = 0;
        var alphaCG: CGFloat = 0;
        let _ = newColor.getHue(&hueCG, saturation: &saturationCG, brightness: &brightnessCG, alpha: &alphaCG);
        
        //print(hueCG);
        
            // clamping between 0 and 1.0
        saturationCG = min(saturationCG, 1);
        
        hue = hueCG;
        saturation = saturationCG;
        brightness = brightnessCG;
        
        // converting to radians
        hueCG *= CGFloat.pi * 2;
        
        print(saturationCG);
        
        // multiplying for the radius
        saturationCG *= CGFloat(radius);
        
        //print("angle: \(Int(hueCG * (180 / CGFloat.pi)))" + " distance: \(Int(saturationCG))");
        
        knobPosition = CGPoint(x: centerPoint.x + (CGFloat(cosf(Float(hueCG)) * Float(saturationCG))), y: centerPoint.y - (CGFloat(sinf(Float(hueCG)) * Float(saturationCG))));
        
            // setting the knob's frame (including location)
        moveKnob(goal: knobPosition);
        //knob?.frame.midY = knobPosition.y;
        
            // update display
        //setNeedsDisplay();
    }
    
        // generating a UIColor from the slider
    public func getColor() -> UIColor
    {
        
        
            // hue is the angle of the knob relative to the center of the view
        let deltaX = Float(centerPoint.x - (knob?.frame.midX)!);
        let deltaY = Float(centerPoint.y - (knob?.frame.midY)!);
            // returns between -π and π
        var angle: Float = atan2f(deltaX, deltaY)
        
            // adjusting range
        angle += Float.pi / 2;
        if (angle < 0)
        {
            angle += Float.pi * 2;
        }
        
        let newHue = angle / (Float.pi * 2);
        
        
        
            // saturation is the magnitude of the vector from the center, found using pythagorean theorem
        let newSaturation: Float = sqrt(
            Float(pow(
                (centerPoint.y - (knob?.frame.midY)!), 2)
                + pow(
                    (centerPoint.x - (knob?.frame.midX)!), 2)
        )) / radius;
        
        print("angle: \(Int(angle * (180 / Float.pi)))" + " distance: \(newSaturation * radius)");
        
            // brightness is from the view controller's brightness slider
        let newBrightness = viewController?.brightness;
        
            // setting public values
        hue = CGFloat(newHue);
        saturation = CGFloat(newSaturation);
        brightness = newBrightness ?? 0.5;
        
        return UIColor(hue: CGFloat(newHue), saturation: CGFloat(newSaturation), brightness: CGFloat(brightness), alpha: 1);
    }
    
    public func updateBrightness()
    {
        setNeedsDisplay();
    }
    
}


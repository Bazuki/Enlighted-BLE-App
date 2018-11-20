//
//  Mode.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;

class Mode
{
    // MARK: Properties
    
    
    // the name of the mode
    var name: String;
    
    // the index of the mode, which will eventually be read from the firmware
    var index: Int;
        
    // whether or not the mode uses a bitmap instead of colors
    var usesBitmap: Bool;
    
    // a reference to the current bitmap, but only necessary for a bitmap mode
    var bitmap: UIImage?;
    
    var bitmapIndex: Int?;
    
    // a reference to the colors used by the mode (if it isn't a bitmap mode)
    var color1: UIColor?;
    
    var color2: UIColor?;
    
    
    
    
    // MARK: Initialization
    
    init?(name:String, index:Int, usesBitmap: Bool, bitmap: UIImage?, colors: [UIColor?])
    {
            // check for empty references
        if name.isEmpty || index < 1
        {
            return nil;
        }
        
            // initializing stored variables
        self.name = name;
        self.index = index;
        self.usesBitmap = usesBitmap;
        
            // if it's a bitmap, assign the bitmap passed in the constructor
        if (usesBitmap)
        {
            self.bitmap = bitmap;
            self.bitmapIndex = 1;
        }
            // otherwise pass the two colors that make up the pattern
        else
        {
            self.color1 = colors[0];
            self.color2 = colors[1];
        }
    }
    
    init?(name:String, index:Int, usesBitmap: Bool, bitmapIndex: Int?, colors: [UIColor?])
    {
        // check for empty references
        if name.isEmpty || index < 1
        {
            return nil;
        }
        
        // initializing stored variables
        self.name = name;
        self.index = index;
        self.usesBitmap = usesBitmap;
        
        // if it's a bitmap, assign the bitmap passed in the constructor
        if (usesBitmap)
        {
                // sample bitmap until getBitmap works
            self.bitmap = UIImage(named: "Bitmap2");
            self.bitmapIndex = bitmapIndex;
        }
            // otherwise pass the two colors that make up the pattern
        else
        {
            self.color1 = colors[0];
            self.color2 = colors[1];
        }
    }
    
        //  Default initialization
    init?()
    {
        self.name = "Default";
        self.index = 1;
        self.usesBitmap = false;
        self.bitmapIndex = 1;
        color1 = UIColor.red
        color2 = UIColor.blue;
        
    }
    
    
}

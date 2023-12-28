//
//  Mode.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import os.log;

class Mode: NSObject, NSCoding
{
    
    // MARK: Properties
    
    struct PropertyKey
    {
        static let name = "name";
        static let usesBitmap = "usesBitmap";
        static let bitmapIndex = "bitmapIndex";
        static let usesPalette = "usesPalette";
        static let index = "index";
        static let colors = "colors";
        static let paletteColors = "paletteColors";
    }
    
    
    // the name of the mode
    var name: String;
    
    // the index of the mode, which will eventually be read from the firmware
    var index: Int;
        
    // whether or not the mode uses a bitmap instead of colors
    var usesBitmap: Bool;
    
    // a reference to the current bitmap, but only necessary for a bitmap mode
    var bitmap: UIImage?;
    
    var bitmapIndex: Int?;
    
    // whether or not the mode uses a palette of 16 colors
    var usesPalette: Bool;
    
    // reference to the palette of colors
    var paletteColors: [UIColor]?;
    
    // a reference to the colors used by the mode (if it isn't a bitmap mode)
    var color1: UIColor?;
    
    var color2: UIColor?;
    
    
    
    
    // MARK: Initialization
    
    init?(name:String, index:Int, usesPalette: Bool, usesBitmap: Bool, bitmap: UIImage?, colors: [UIColor?])
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
        self.usesPalette = usesPalette;
        
            // if it's a bitmap, assign the bitmap passed in the constructor
        if (usesBitmap)
        {
            self.bitmap = bitmap;
            self.bitmapIndex = 1;
        }
            // if it's a palette mode, initialize the paletteColors array
        else if (usesPalette)
        {
            self.paletteColors = [UIColor]();
            
        }
            // otherwise pass the two colors that make up the pattern
        else
        {
            self.color1 = colors[0];
            self.color2 = colors[1];
        }
    }
    
    init?(name:String, index:Int, usesPalette: Bool, usesBitmap: Bool, bitmapIndex: Int?, colors: [UIColor?])
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
        self.usesPalette = usesPalette;
        
        
        // if it's a bitmap, assign the bitmap passed in the constructor
        if (usesBitmap)
        {
                // sample bitmap until getBitmap works
            self.bitmap = UIImage(named: "Bitmap2");
            self.bitmapIndex = bitmapIndex;
        }
            // if it's a palette mode, initialize the paletteColors array
        else if (usesPalette)
        {
            self.paletteColors = [UIColor]();
            
        }
            // otherwise pass the two colors that make up the pattern
        else
        {
            self.color1 = colors[0];
            self.color2 = colors[1];
        }
    }
    
        //  Default initialization
    init?(default: Bool)
    {
        self.name = "Default";
        self.index = -1;
        self.usesBitmap = false;
        self.usesPalette = false;
        self.paletteColors = [UIColor]();
        self.bitmapIndex = 1;
        color1 = UIColor.red
        color2 = UIColor.blue;

    }
    
    public func setPalette(palette: [UIColor])
    {
            //when we reload all the modes, we loop through the palette info we got back and populate the paletteColors array
        for paletteCell in palette
        {
            self.paletteColors?.append(paletteCell);
        }
            // setting color1 and color2 to avoid nil unwrapping errors - MIGHT NOT BE NECESSARY ANYMORE
        self.color1 = self.paletteColors![0];
        self.color2 = self.paletteColors![1];

    }
    
    // MARK: NSCoding
    
        // encoding data
    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(name, forKey: PropertyKey.name);
        aCoder.encode(usesBitmap, forKey: PropertyKey.usesBitmap);
        aCoder.encode(usesPalette, forKey: PropertyKey.usesPalette);
        aCoder.encode(index, forKey: PropertyKey.index);
        if (usesBitmap)
        {
            let encodableBitmapIndex: Int = bitmapIndex!
            aCoder.encode(encodableBitmapIndex, forKey: PropertyKey.bitmapIndex);
        }
        else if (usesPalette)
        {
            aCoder.encode(paletteColors, forKey: PropertyKey.paletteColors);
        }
        else
        {
            aCoder.encode([color1!, color2!], forKey: PropertyKey.colors);
        }
    }
    
    required convenience init?(coder aDecoder: NSCoder)
    {
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            os_log("Unable to decode the name for the Mode object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let usesBitmap = aDecoder.decodeBool(forKey: PropertyKey.usesBitmap);
        let usesPalette = aDecoder.decodeBool(forKey: PropertyKey.usesPalette);
        
        let index = aDecoder.decodeInteger(forKey: PropertyKey.index);
        
        if (usesBitmap)
        {
            let bitmapIndex = aDecoder.decodeInteger(forKey: PropertyKey.bitmapIndex) ;
                // creating a Bitmap mode
            self.init(name: name, index: index, usesPalette: false, usesBitmap: usesBitmap, bitmapIndex: bitmapIndex, colors: [nil]);
        }
        else if (usesPalette)
        {
            let paletteColors = aDecoder.decodeObject(forKey: PropertyKey.paletteColors) as? [UIColor];
            self.init(name: name, index: index, usesPalette: usesPalette, usesBitmap: usesBitmap, bitmapIndex: nil, colors: [nil]);
            self.setPalette(palette: paletteColors!);
        }
        else
        {
            let colors = aDecoder.decodeObject(forKey: PropertyKey.colors) as? [UIColor];
            // creating a color mode
            self.init(name: name, index: index, usesPalette: false, usesBitmap: usesBitmap, bitmapIndex: nil, colors: colors!);
        }
        
        
    }
    
    
}

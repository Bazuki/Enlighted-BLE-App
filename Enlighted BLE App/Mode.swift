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
        static let index = "index";
        static let colors = "colors";
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
    init?(default: Bool)
    {
        self.name = "Default";
        self.index = 1;
        self.usesBitmap = false;
        self.bitmapIndex = 1;
        color1 = UIColor.red
        color2 = UIColor.blue;

    }
    
    // MARK: NSCoding
    
        // encoding data
    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(name, forKey: PropertyKey.name);
        aCoder.encode(usesBitmap, forKey: PropertyKey.usesBitmap);
        aCoder.encode(index, forKey: PropertyKey.index);
        if (usesBitmap)
        {
            let encodableBitmapIndex: Int = bitmapIndex!
            aCoder.encode(encodableBitmapIndex, forKey: PropertyKey.bitmapIndex);
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
        
        let index = aDecoder.decodeInteger(forKey: PropertyKey.index);
        
        if (usesBitmap)
        {
            let bitmapIndex = aDecoder.decodeInteger(forKey: PropertyKey.bitmapIndex) ;
                // creating a Bitmap mode
            self.init(name: name, index: index, usesBitmap: usesBitmap, bitmapIndex: bitmapIndex, colors: [nil]);
        }
        else
        {
            let colors = aDecoder.decodeObject(forKey: PropertyKey.colors) as? [UIColor];
            // creating a Bitmap mode
            self.init(name: name, index: index, usesBitmap: usesBitmap, bitmapIndex: nil, colors: colors!);
        }
        
        
    }
    
    
}

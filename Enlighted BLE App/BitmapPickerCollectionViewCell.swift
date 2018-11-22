//
//  BitmapPickerCollectionViewCell.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/29/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import QuartzCore

class BitmapPickerCollectionViewCell: UICollectionViewCell
{
    // MARK: Properties
    @IBOutlet weak var bitmapImage: UIImageView!
    
        // credit to https://stackoverflow.com/questions/16552072/how-do-i-draw-into-a-bitmap-without-antialiasing-interpolation-in-ios for anti-anti-aliasing
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
            // should disable anti-aliasing to some degree
        bitmapImage.layer.magnificationFilter = kCAFilterNearest;
        bitmapImage.layer.minificationFilter = kCAFilterNearest;
    }
    
    
        // credit to https://hackernoon.com/uicollectionviewcell-selection-made-easy-41dae148379d
    override var isSelected: Bool
    {
        didSet
        {
            if self.isSelected
            {
                backgroundColor = UIColor(named: "SelectedText");
            }
            else
            {
                backgroundColor = UIColor.clear;
            }
        }
    }
    
}

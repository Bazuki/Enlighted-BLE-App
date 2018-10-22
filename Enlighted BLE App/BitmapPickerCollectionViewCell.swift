//
//  BitmapPickerCollectionViewCell.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/29/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class BitmapPickerCollectionViewCell: UICollectionViewCell
{
    // MARK: Properties
    @IBOutlet weak var bitmapImage: UIImageView!
    
        // credit to https://hackernoon.com/uicollectionviewcell-selection-made-easy-41dae148379d
    override var isSelected: Bool
    {
        didSet
        {
            if self.isSelected
            {
                backgroundColor = UIColor(named: "SelectedModeBackground");
            }
            else
            {
                backgroundColor = UIColor.clear;
            }
        }
    }
    
}

//
//  ModeTableViewCell.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/27/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit;
import QuartzCore;
//import CoreBluetooth;

class ModeTableViewCell: UITableViewCell
{
    // MARK: Properties
    
    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var modeIndex: UILabel!
    @IBOutlet weak var modeBitmap: UIImageView!
    @IBOutlet weak var colorPreviewWrapper: UIView!
    @IBOutlet weak var color1View: ColorPreview!
    @IBOutlet weak var color2View: ColorPreview!
    @IBOutlet weak var editModeButton: UIButton!
    
    
    var mode = Mode();

    override func awakeFromNib()
    {
        super.awakeFromNib()
        backgroundColor = UIColor.white;
        updateImages();
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        
        
        
            // setting colors based on selection state
        if (selected)
        {
            backgroundColor = UIColor(named: "SelectedModeBackground");
            modeLabel.textColor = UIColor(named: "SelectedText");
            modeIndex.textColor = UIColor(named: "SelectedText");
            //layer.borderWidth = 1.0;
            //layer.borderColor = UIColor.lightGray.cgColor;
        }
        else
        {
            backgroundColor = UIColor.clear;
            modeLabel.textColor = UIColor(named: "NonSelectedText");
            modeIndex.textColor = UIColor(named: "NonSelectedText");
            //layer.borderColor = UIColor.clear.cgColor;
        }
            // only show the edit button for the selected mode
        editModeButton.isHidden = !selected;
        // Configure the view for the selected state
    }

    
    @IBAction func chooseModeAndEdit(_ sender: UIButton)
    {
        Device.connectedDevice?.currentModeIndex = (mode?.index)!;
        Device.connectedDevice?.mode = self.mode;
    }
    
    
    
    func updateImages()
    {
            // set button image render mode so that tinting takes effect
        let originalImage = editModeButton.currentImage;
        let tintedImage = originalImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        editModeButton.setImage(tintedImage, for: .normal)
        
        let errorBitmap = UIImage(named: "Bitmap2");
        
            // if we need to display a bitmap
        if ((mode?.usesBitmap)!)
        {
            colorPreviewWrapper.isHidden = true;
            modeBitmap.isHidden = false;
            if ((Device.connectedDevice?.thumbnails.count)! >= (mode?.bitmapIndex)!)
            {
                modeBitmap.image = Device.connectedDevice?.thumbnails[(mode?.bitmapIndex)! - 1]
            }
            else
            {
                modeBitmap.image = errorBitmap
            }
            
            // should disable anti-aliasing to some degree
            modeBitmap.layer.magnificationFilter = kCAFilterNearest;
            modeBitmap.layer.minificationFilter = kCAFilterNearest;
            
            color1View.isHidden = true;
            color2View.isHidden = true;
        }
            // if we need to display two colors
        else
        {
            colorPreviewWrapper.isHidden = false;
            modeBitmap.isHidden = true;
            
            color1View.setBackgroundColor(newColor: (mode?.color1)!)
            color2View.setBackgroundColor(newColor: (mode?.color2)!)
            
            color1View.isHidden = false;
            color2View.isHidden = false;
            
            color1View.setNeedsDisplay();
            color2View.setNeedsDisplay();
            
        }
    }
}

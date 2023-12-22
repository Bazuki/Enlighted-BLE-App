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
    
    // palette references
    @IBOutlet weak var palettePreviewWrapper: UIView!
    @IBOutlet weak var pColor1View: ColorPreview!
    @IBOutlet weak var pColor2View: ColorPreview!
    @IBOutlet weak var pColor3View: ColorPreview!
    @IBOutlet weak var pColor4View: ColorPreview!
    @IBOutlet weak var pColor5View: ColorPreview!
    @IBOutlet weak var pColor6View: ColorPreview!
    @IBOutlet weak var pColor7View: ColorPreview!
    @IBOutlet weak var pColor8View: ColorPreview!
    @IBOutlet weak var pColor9View: ColorPreview!
    @IBOutlet weak var pColor10View: ColorPreview!
    @IBOutlet weak var pColor11View: ColorPreview!
    @IBOutlet weak var pColor12View: ColorPreview!
    @IBOutlet weak var pColor13View: ColorPreview!
    @IBOutlet weak var pColor14View: ColorPreview!
    @IBOutlet weak var pColor15View: ColorPreview!
    @IBOutlet weak var pColor16View: ColorPreview!
    
    var mode = Mode(default: true);

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

    
//    @IBAction func chooseModeAndEdit(_ sender: UIButton)
//    {
//        Device.connectedDevice?.currentModeIndex = (mode?.index)!;
//        Device.connectedDevice?.mode = self.mode;
//    }
    
    
    
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
            palettePreviewWrapper.isHidden = true;
            modeBitmap.isHidden = false;
            
            let thumbnailCount = (Device.connectedDevice?.thumbnails.count)!
            
            if (thumbnailCount >= (mode?.bitmapIndex)!)
            {
                modeBitmap.image = Device.connectedDevice?.thumbnails[(mode?.bitmapIndex)! - 1]
            }
            else
            {
                Device.reportError(Constants.CURRENT_MODE_THUMBNAIL_INDEX_EXCEEDS_STORED_THUMBNAILS)
                modeBitmap.image = errorBitmap
            }
            
            // should disable anti-aliasing to some degree
            modeBitmap.layer.magnificationFilter = kCAFilterNearest;
            modeBitmap.layer.minificationFilter = kCAFilterNearest;
            
            color1View.isHidden = true;
            color2View.isHidden = true;
            
            pColor1View.isHidden = true;
            pColor2View.isHidden = true;
            pColor3View.isHidden = true;
            pColor4View.isHidden = true;
            pColor5View.isHidden = true;
            pColor6View.isHidden = true;
            pColor7View.isHidden = true;
            pColor8View.isHidden = true;
            pColor9View.isHidden = true;
            pColor10View.isHidden = true;
            pColor11View.isHidden = true;
            pColor12View.isHidden = true;
            pColor13View.isHidden = true;
            pColor14View.isHidden = true;
            pColor15View.isHidden = true;
            pColor16View.isHidden = true;
        }
        else if ((mode?.usesPalette)!)
        {
            colorPreviewWrapper.isHidden = true;
            palettePreviewWrapper.isHidden = false;
            modeBitmap.isHidden = true;
            
            color1View.isHidden = true;
            color2View.isHidden = true;
            
            pColor1View.setBackgroundColor(newColor: (mode?.paletteColors![0])!)
            pColor2View.setBackgroundColor(newColor: (mode?.paletteColors![1])!)
            pColor3View.setBackgroundColor(newColor: (mode?.paletteColors![2])!)
            pColor4View.setBackgroundColor(newColor: (mode?.paletteColors![3])!)
            pColor5View.setBackgroundColor(newColor: (mode?.paletteColors![4])!)
            pColor6View.setBackgroundColor(newColor: (mode?.paletteColors![5])!)
            pColor7View.setBackgroundColor(newColor: (mode?.paletteColors![6])!)
            pColor8View.setBackgroundColor(newColor: (mode?.paletteColors![7])!)
            pColor9View.setBackgroundColor(newColor: (mode?.paletteColors![8])!)
            pColor10View.setBackgroundColor(newColor: (mode?.paletteColors![9])!)
            pColor11View.setBackgroundColor(newColor: (mode?.paletteColors![10])!)
            pColor12View.setBackgroundColor(newColor: (mode?.paletteColors![11])!)
            pColor13View.setBackgroundColor(newColor: (mode?.paletteColors![12])!)
            pColor14View.setBackgroundColor(newColor: (mode?.paletteColors![13])!)
            pColor15View.setBackgroundColor(newColor: (mode?.paletteColors![14])!)
            pColor16View.setBackgroundColor(newColor: (mode?.paletteColors![15])!)
            
            
            pColor1View.isHidden = false;
            pColor2View.isHidden = false;
            pColor3View.isHidden = false;
            pColor4View.isHidden = false;
            pColor5View.isHidden = false;
            pColor6View.isHidden = false;
            pColor7View.isHidden = false;
            pColor8View.isHidden = false;
            pColor9View.isHidden = false;
            pColor10View.isHidden = false;
            pColor11View.isHidden = false;
            pColor12View.isHidden = false;
            pColor13View.isHidden = false;
            pColor14View.isHidden = false;
            pColor15View.isHidden = false;
            pColor16View.isHidden = false;
            
            pColor1View.setNeedsDisplay();
            pColor2View.setNeedsDisplay();
            pColor3View.setNeedsDisplay();
            pColor4View.setNeedsDisplay();
            pColor5View.setNeedsDisplay();
            pColor6View.setNeedsDisplay();
            pColor7View.setNeedsDisplay();
            pColor8View.setNeedsDisplay();
            pColor9View.setNeedsDisplay();
            pColor10View.setNeedsDisplay();
            pColor11View.setNeedsDisplay();
            pColor12View.setNeedsDisplay();
            pColor13View.setNeedsDisplay();
            pColor14View.setNeedsDisplay();
            pColor15View.setNeedsDisplay();
            pColor16View.setNeedsDisplay();
        }
            // if we need to display two colors
        else
        {
            colorPreviewWrapper.isHidden = false;
            palettePreviewWrapper.isHidden = true;
            modeBitmap.isHidden = true;
            
            color1View.setBackgroundColor(newColor: (mode?.color1)!)
            color2View.setBackgroundColor(newColor: (mode?.color2)!)
            
            color1View.isHidden = false;
            color2View.isHidden = false;
            
            pColor1View.isHidden = true;
            pColor2View.isHidden = true;
            pColor3View.isHidden = true;
            pColor4View.isHidden = true;
            pColor5View.isHidden = true;
            pColor6View.isHidden = true;
            pColor7View.isHidden = true;
            pColor8View.isHidden = true;
            pColor9View.isHidden = true;
            pColor10View.isHidden = true;
            pColor11View.isHidden = true;
            pColor12View.isHidden = true;
            pColor13View.isHidden = true;
            pColor14View.isHidden = true;
            pColor15View.isHidden = true;
            pColor16View.isHidden = true;
            
            color1View.setNeedsDisplay();
            color2View.setNeedsDisplay();
            
        }
    }
}

//
//  EditScreenViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class EditScreenViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, ISColorWheelDelegate
{
    
    
    
    // MARK: Properties

    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var modeNumberLabel: UILabel!
    @IBOutlet weak var bitmapUIImage: UIImageView!
    
    @IBOutlet weak var color1Selector: ColorPreview!
    @IBOutlet weak var color2Selector: ColorPreview!
    
    @IBOutlet weak var colorPickerPlaceholder: UIImageView!
    @IBOutlet weak var intensitySliderPlaceholder: UISlider!
    
    @IBOutlet weak var bitmapPicker: UICollectionView!
    
    @IBOutlet weak var colorUndoButton: UIButton!
    @IBOutlet weak var colorRevertButton: UIButton!
    @IBOutlet weak var bitmapUndoButton: UIButton!
    @IBOutlet weak var bitmapRevertButton: UIButton!
    
    @IBOutlet weak var color1Label: UILabel!
    @IBOutlet weak var color2Label: UILabel!
    @IBOutlet weak var color1RGB: UILabel!
    @IBOutlet weak var color2RGB: UILabel!
    
    @IBOutlet weak var saturationLabel: UILabel!
    
    //var delegate =
    var _colorWheel: ISColorWheel = ISColorWheel();
    
    // a list of the selectable bitmaps
    var bitmaps = [UIImage?]();
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        
        
        if (Device.connectedDevice?.mode?.usesBitmap)!
        {
            self.title = "Choose Bitmap";
        }
        else
        {
            self.title = "Choose Colors";
        }
        
        bitmapPicker.dataSource = self;
        bitmapPicker.delegate = self;
        
        let bitmap1 = UIImage(named: "Bitmap1");
        let bitmap2 = UIImage(named: "Bitmap2");
        let bitmap3 = UIImage(named: "Bitmap3");
        let bitmap4 = UIImage(named: "Bitmap4");
            // Add selectable bitmaps (with 20 values, so that it can be spaced correctly)
        for _ in 1...5
        {
            bitmaps += [bitmap1, bitmap2, bitmap3, bitmap4];
        }
        
        //TODO:
            //allow for the selection of bitmaps
        bitmapPicker.allowsSelection = true;
        
        
            // Set the name
        modeLabel.text = /* String((Device.connectedDevice?.mode?.index)!) + "   " + */ (Device.connectedDevice?.mode?.name)!;
        
            // Set the mode number
        modeNumberLabel.text = String((Device.connectedDevice?.mode?.index)!);
            // making different things show up depending on mode type
        if (Device.connectedDevice?.mode?.usesBitmap)!
        {
            bitmapUIImage.image = Device.connectedDevice?.mode?.bitmap;
            bitmapUIImage.isHidden = false;
            
            bitmapPicker.isHidden = false;
            
            colorPickerPlaceholder.isHidden = true;
            intensitySliderPlaceholder.isHidden = true;
            
            colorUndoButton.isHidden = true;
            colorRevertButton.isHidden = true;
            bitmapUndoButton.isHidden = false;
            bitmapRevertButton.isHidden = false;
            
            saturationLabel.isHidden = true
            
            color1Label.isHidden = true;
            color2Label.isHidden = true;
            color1RGB.isHidden = true;
            color2RGB.isHidden = true;
            
            color1Selector.isHidden = true;
            color2Selector.isHidden = true;
        }
        else if !(Device.connectedDevice?.mode?.usesBitmap)!
        {
            bitmapUIImage.isHidden = true;
            
            bitmapPicker.isHidden = true;
            
            colorPickerPlaceholder.isHidden = false;
            intensitySliderPlaceholder.isHidden = false;
            
            colorUndoButton.isHidden = false;
            colorRevertButton.isHidden = false;
            bitmapUndoButton.isHidden = true;
            bitmapRevertButton.isHidden = true;
            
            color1Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color1)!);
            color2Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color2)!);
            
            color1RGB.text = getRGBStringFromUIColor(color1Selector.myColor);
            color2RGB.text = getRGBStringFromUIColor(color2Selector.myColor);
            
            saturationLabel.isHidden = false;
            
            color1Label.isHidden = false;
            color2Label.isHidden = false;
            color1RGB.isHidden = false;
            color2RGB.isHidden = false;
            
            
            color1Selector.isHidden = false;
            color2Selector.isHidden = false;
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: CollectionViewDataSource functions
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return bitmaps.count;
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cellIdentifier = "BitmapPickerCollectionViewCell"
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? BitmapPickerCollectionViewCell else
        {
            fatalError("Unable to dequeue collectionViewCell as BitmapPickerCollectionViewCell");
        }
        
        cell.bitmapImage.image = bitmaps[indexPath.row];
        
        return cell;
    }
    
    func getRGBStringFromUIColor(_ color: UIColor) -> String
    {
        // getting RGB values of color
        var red: CGFloat = 0;
        var green: CGFloat = 0;
        var blue: CGFloat = 0;
        var alpha: CGFloat = 0;
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // scaling up to 255
        red *= 255;
        green *= 255;
        blue *= 255;
        
        // adding to string
        let output = String("R: " + red.description + " G: " + green.description + " B: " + blue.description);
        return output;
    }
    
    // MARK: Actions
    
    // marking a color as edit-able by the color wheel
    @IBAction func selectAndEditColor1(_ sender: UITapGestureRecognizer)
    {
        color1Selector.setHighlighted(true);
        color1Label.textColor = UIColor(named: "SelectedText");
        color1RGB.textColor = UIColor(named: "SelectedText");
        color2Selector.setHighlighted(false);
        color2Label.textColor = UIColor(named: "NonSelectedText");
        color2RGB.textColor = UIColor(named: "NonSelectedText");
    }
    
    @IBAction func selectAndEditColor2(_ sender: UITapGestureRecognizer)
    {
        color2Selector.setHighlighted(true);
        color2Label.textColor = UIColor(named: "SelectedText");
        color2RGB.textColor = UIColor(named: "SelectedText");
        color1Selector.setHighlighted(false);
        color1Label.textColor = UIColor(named: "NonSelectedText");
        color1RGB.textColor = UIColor(named: "NonSelectedText");
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

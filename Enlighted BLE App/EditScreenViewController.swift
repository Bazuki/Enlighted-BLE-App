//
//  EditScreenViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore
import AVFoundation

class EditScreenViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, CBPeripheralManagerDelegate//, ISColorWheelDelegate
{
    // MARK: Properties

    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var modeNumberLabel: UILabel!
    @IBOutlet weak var bitmapUIImage: UIImageView!
    
    @IBOutlet weak var color1Selector: ColorPreview!
    @IBOutlet weak var color2Selector: ColorPreview!
    
    @IBOutlet weak var colorPickerWrapper: UIView!
    
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
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    //var delegate =
    //var _colorWheel: ISColorWheel = ISColorWheel();
    
        // a list of the selectable bitmaps
    var bitmaps = [UIImage?]();
    
        // a history of bitmaps, so that we can use "undo"
    var bitmapHistory = [Int]();
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil);
        
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
        
        let errorBitmap = UIImage(named: "Bitmap2");
        //let bitmap2 = UIImage(named: "Bitmap2");
        //let bitmap3 = UIImage(named: "Bitmap3");
        //let bitmap4 = UIImage(named: "Bitmap4");
            // Add selectable bitmaps, up to the limit from getLimit()
        let maxNumBitmaps: Int = Device.connectedDevice?.maxBitmaps ?? 10; 
        
            // if Get Thumbnails worked, use those thumbnails
        if (Device.connectedDevice?.thumbnails.count == maxNumBitmaps)
        {
            bitmaps = (Device.connectedDevice?.thumbnails)!;
        }
            // otherwise use the error bitmap
        else
        {
            for _ in 0...maxNumBitmaps - 1
            {
                bitmaps += [errorBitmap];
            }
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
            bitmapUIImage.image = Device.connectedDevice?.thumbnails[(Device.connectedDevice?.mode?.bitmapIndex)! - 1];
            
            // should disable anti-aliasing to some degree
            bitmapUIImage.layer.magnificationFilter = kCAFilterNearest;
            bitmapUIImage.layer.minificationFilter = kCAFilterNearest;
            bitmapUIImage.isHidden = false;
            
            bitmapPicker.isHidden = false;
            
            colorPickerWrapper.isHidden = true;
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
            
            colorPickerWrapper.isHidden = false;
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

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
            // clearing history upon entry to the view screen
        bitmapHistory = [Int]();
        
            // should automatically pre-select the correct bitmap
        if ((Device.connectedDevice?.mode?.usesBitmap)!)
        {
            let indexPath = IndexPath(row: (Device.connectedDevice?.mode?.bitmapIndex)! - 1, section: 0);
            bitmapPicker.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition(rawValue: 0));
                // on loading in, enforce the stored bitmap
            setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: CBPeripheralDelegate functions
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        Device.connectedDevice?.mode?.bitmapIndex = indexPath.row + 1;
        setBitmap(indexPath.row + 1);
            // updating the header image
        bitmapUIImage.image = Device.connectedDevice?.thumbnails[(Device.connectedDevice?.mode?.bitmapIndex)! - 1];
        
            // adding to the history (if it isn't already the most recent mode)
        if (bitmapHistory.last != indexPath.row + 1)
        {
            bitmapHistory += [indexPath.row + 1];
        }
        
        print("Will set to bitmap: \(indexPath.row + 1) ");
    }
    
    func setBitmap(_ bitmapIndex: Int)
    {
        if (!(Device.connectedDevice?.isConnected)!)
        {
            print("Device is not connected");
            return;
        }
        else if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
        {
            print("Disconnected");
            
            // error popup
            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {(action) -> Void in
                print("Should go to the Connect Screen at this point");
                _ = self.navigationController?.popToRootViewController(animated: true);
            })
            
            dialogMessage.addAction(ok);
            
            self.present(dialogMessage, animated: true, completion: nil);
            // shows the Connection page (hopefully/eventually)
            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
            //self.show(newViewController, sender: self);
            return;
        }
        
        let bitmapIndexUInt: UInt8 = UInt8(bitmapIndex);
        
        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BITMAP;// + "\(modeIndexUInt)";
        
        let stringArray: [UInt8] = Array(valueString.utf8);
        let valueArray = stringArray + [bitmapIndexUInt]
        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
        let valueData = NSData(bytes: valueArray, length: 4)
        
        print("sending: " + valueString, bitmapIndexUInt);
        
        Device.connectedDevice!.peripheral.writeValue(valueData as Data, for: Device.connectedDevice!.txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        // "active request" flag
        Device.connectedDevice?.requestWithoutResponse = true;
        
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
        
            // making them ints so they fit in the text box
        let redString = String(Int(red));
        let greenString = String(Int(green));
        let blueString = String(Int(blue));
        
            // adding to string
        var output: String = "R: " + redString;
        output += " G: " + greenString;
        output += " B: " + blueString;
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
    
        // undoing bitmap selections
    @IBAction func pressedBitmapUndo(_ sender: UIButton)
    {
        if (bitmapHistory.count > 1)
        {
                // going back in history
            Device.connectedDevice?.mode?.bitmapIndex = bitmapHistory[bitmapHistory.count - 2];
            setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
                // updating the header image
            bitmapUIImage.image = Device.connectedDevice?.thumbnails[(Device.connectedDevice?.mode?.bitmapIndex)! - 1];
                // select the correct bitmap
            let indexPath = IndexPath(row: (Device.connectedDevice?.mode?.bitmapIndex)! - 1, section: 0);
            bitmapPicker.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition(rawValue: 0));
                // removing the last value
            bitmapHistory.removeLast();
        }
        else
        {
            print("No more history to undo");
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
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

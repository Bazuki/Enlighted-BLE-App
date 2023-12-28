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
    
    @IBOutlet weak var colorModeObjects: UIView!
    @IBOutlet weak var bitmapModeObjects: UIView!
    @IBOutlet weak var paletteModeObjects: UIView!
    
    @IBOutlet weak var bitmapUIImage: UIImageView!
    
    @IBOutlet weak var color1Selector: ColorPreview!
    @IBOutlet weak var color2Selector: ColorPreview!
    
    @IBOutlet weak var colorPickerWrapper: UIView!
    
    @IBOutlet weak var hueSlider: UISlider!
    @IBOutlet weak var saturationSlider: UISlider!
    @IBOutlet weak var brightnessSlider: UISlider!
    
    @IBOutlet weak var colorImage: UIImageView!
    @IBOutlet weak var bitmapPicker: UICollectionView!
    @IBOutlet weak var ColorWheel: ColorWheel!
    
    @IBOutlet weak var color1UndoButton: UIButton!
    @IBOutlet weak var color2UndoButton: UIButton!
    @IBOutlet weak var colorRevertButton: UIButton!
    @IBOutlet weak var bitmapUndoButton: UIButton!
    @IBOutlet weak var bitmapRevertButton: UIButton!
    
    @IBOutlet weak var color1Label: UILabel!
    @IBOutlet weak var color2Label: UILabel!
    @IBOutlet weak var color1RGB: UILabel!
    @IBOutlet weak var color2RGB: UILabel!
    
    @IBOutlet weak var saturationLabel: UILabel!
    
    @IBOutlet weak var pColorPickerWrapper: UIView!
    @IBOutlet weak var pColorWheel: ColorWheel!
    @IBOutlet weak var pColorImage: UIImageView!
    @IBOutlet weak var pHueSlider: UISlider!
    @IBOutlet weak var pSaturationSlider: UISlider!
    @IBOutlet weak var pBrightnessSlider: UISlider!

    @IBOutlet weak var paletteColorRGB: UILabel!
    @IBOutlet weak var paletteUndoButton: UIButton!
    
    @IBOutlet weak var pColor1Selector: ColorPreview!
    @IBOutlet weak var pColor2Selector: ColorPreview!
    @IBOutlet weak var pColor3Selector: ColorPreview!
    @IBOutlet weak var pColor4Selector: ColorPreview!
    @IBOutlet weak var pColor5Selector: ColorPreview!
    @IBOutlet weak var pColor6Selector: ColorPreview!
    @IBOutlet weak var pColor7Selector: ColorPreview!
    @IBOutlet weak var pColor8Selector: ColorPreview!
    @IBOutlet weak var pColor9Selector: ColorPreview!
    @IBOutlet weak var pColor10Selector: ColorPreview!
    @IBOutlet weak var pColor11Selector: ColorPreview!
    @IBOutlet weak var pColor12Selector: ColorPreview!
    @IBOutlet weak var pColor13Selector: ColorPreview!
    @IBOutlet weak var pColor14Selector: ColorPreview!
    @IBOutlet weak var pColor15Selector: ColorPreview!
    @IBOutlet weak var pColor16Selector: ColorPreview!
    
        // the peripheral manager
    var peripheralManager: CBPeripheralManager?;
    
    // list of palette color selectors
    var paletteColorSelectors = [ColorPreview?]();
    
    //var delegate =
    //var _colorWheel: ISColorWheel = ISColorWheel();
    
        // a list of the selectable bitmaps
    var bitmaps = [UIImage?]();
    
        // a history of bitmap (indices), so that we can use "undo"
    var bitmapHistory = [Int]();
    
        // the histories for each color, so that they can be undone as well
    public var color1History = [UIColor]();
    public var color2History = [UIColor]();
    
    public var paletteColorHistory = [[UIColor]]();
    
    var currentColor: UIColor = UIColor.clear;
    var currentColorIndex: Int = 1;
    
        // brightness of slider
    public var brightness: CGFloat = 1;
    public var pBrightness: CGFloat = 1;
    
        // don't let the user spam revert if the mode is already reverted
    //var hasReverted = false;
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // from: https://stackoverflow.com/questions/17209468/how-to-disable-back-swipe-gesture-in-uinavigationcontroller-on-ios-7
        
        // disabling the "swipe back" hand control
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
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
            // Add selectable bitmaps, up to the limit from getLimit()
        let maxNumBitmaps: Int = Device.connectedDevice?.maxBitmaps ?? 10; 
        
            // if Get Thumbnails worked, use those thumbnails
        if ((Device.connectedDevice?.thumbnails.count)! >= maxNumBitmaps)
        {
            bitmaps = (Device.connectedDevice?.thumbnails)!;
        }
            // otherwise use the error bitmap
        else
        {
            for _ in 0...maxNumBitmaps - 1
            {
                Device.reportError(Constants.NOT_ENOUGH_STORED_BITMAPS_FOUND)
                bitmaps += [errorBitmap];
            }
        }
        
        
        
            // allow for the selection of bitmaps
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
            
            bitmapModeObjects.isHidden = false;
            
            colorModeObjects.isHidden = true;
            
            colorPickerWrapper.isHidden = true;
            ColorWheel.isHidden = true;
            pColorWheel.isHidden = true;
            
            //intensitySliderPlaceholder.isHidden = true;
            
            color1UndoButton.isHidden = true;
            color2UndoButton.isHidden = true;
            colorRevertButton.isHidden = true;
            
            bitmapUndoButton.isHidden = false;
            bitmapRevertButton.isHidden = false;
            
            //saturationLabel.isHidden = true
            
            color1Label.isHidden = true;
            color2Label.isHidden = true;
            color1RGB.isHidden = true;
            color2RGB.isHidden = true;
            
            color1Selector.isHidden = true;
            color2Selector.isHidden = true;
            
            paletteModeObjects.isHidden = true;
            
            paletteColorRGB.isHidden = true;
            pColor1Selector.isHidden = true;
            pColor2Selector.isHidden = true;
            pColor3Selector.isHidden = true;
            pColor4Selector.isHidden = true;
            pColor5Selector.isHidden = true;
            pColor6Selector.isHidden = true;
            pColor7Selector.isHidden = true;
            pColor8Selector.isHidden = true;
            pColor9Selector.isHidden = true;
            pColor10Selector.isHidden = true;
            pColor11Selector.isHidden = true;
            pColor12Selector.isHidden = true;
            pColor13Selector.isHidden = true;
            pColor14Selector.isHidden = true;
            pColor15Selector.isHidden = true;
            pColor16Selector.isHidden = true;
        }
        else if (Device.connectedDevice?.mode?.usesPalette)!
        {
            bitmapUIImage.isHidden = true;
            
            bitmapPicker.isHidden = true;
            
            bitmapModeObjects.isHidden = true;
            colorModeObjects.isHidden = false;
            
            colorPickerWrapper.isHidden = true;
            ColorWheel.isHidden = true;
            
            color1UndoButton.isHidden = true;
            color2UndoButton.isHidden = true;
            colorRevertButton.isHidden = true;
            
            bitmapUndoButton.isHidden = true;
            bitmapRevertButton.isHidden = true;
            
            color1Label.isHidden = true;
            color2Label.isHidden = true;
            color1RGB.isHidden = true;
            color2RGB.isHidden = true;
            
            color1Selector.isHidden = true;
            color2Selector.isHidden = true;
            
            // unhide palette related objects
            
            paletteModeObjects.isHidden = false;
            pColorWheel.isHidden = false;
            pColorPickerWrapper.isHidden = false;
            paletteColorRGB.isHidden = false;
            
            // set the colors for the palette colors and then show them
            
            pColor1Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![0])!);
            pColor2Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![1])!);
            pColor3Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![2])!);
            pColor4Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![3])!);
            pColor5Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![4])!);
            pColor6Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![5])!);
            pColor7Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![6])!);
            pColor8Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![7])!);
            pColor9Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![8])!);
            pColor10Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![9])!);
            pColor11Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![10])!);
            pColor12Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![11])!);
            pColor13Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![12])!);
            pColor14Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![13])!);
            pColor15Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![14])!);
            pColor16Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.paletteColors![15])!);
            
            paletteColorSelectors = [pColor1Selector, pColor2Selector, pColor3Selector, pColor4Selector, pColor5Selector, pColor6Selector, pColor7Selector, pColor8Selector, pColor9Selector, pColor10Selector, pColor11Selector, pColor12Selector, pColor13Selector, pColor14Selector, pColor15Selector, pColor16Selector];
            
            paletteColorRGB.text = getThreeDigitRGBStringFromUIColor(pColor1Selector.myColor);
            
            pColor1Selector.isHidden = false;
            pColor2Selector.isHidden = false;
            pColor3Selector.isHidden = false;
            pColor4Selector.isHidden = false;
            pColor5Selector.isHidden = false;
            pColor6Selector.isHidden = false;
            pColor7Selector.isHidden = false;
            pColor8Selector.isHidden = false;
            pColor9Selector.isHidden = false;
            pColor10Selector.isHidden = false;
            pColor11Selector.isHidden = false;
            pColor12Selector.isHidden = false;
            pColor13Selector.isHidden = false;
            pColor14Selector.isHidden = false;
            pColor15Selector.isHidden = false;
            pColor16Selector.isHidden = false;
        }
        else if !(Device.connectedDevice?.mode?.usesBitmap)!
        {
            bitmapUIImage.isHidden = true;
            
            bitmapPicker.isHidden = true;
            
            bitmapModeObjects.isHidden = true;
            
            colorModeObjects.isHidden = false;
            
            colorPickerWrapper.isHidden = false;
            ColorWheel.isHidden = false;
            pColorWheel.isHidden = true;
            //intensitySliderPlaceholder.isHidden = false;
            
            color1UndoButton.isHidden = false;
            color2UndoButton.isHidden = false;
            colorRevertButton.isHidden = false;
            
            bitmapUndoButton.isHidden = true;
            bitmapRevertButton.isHidden = true;
            
            color1Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color1)!);
            color2Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color2)!);
            
            color1RGB.text = getRGBStringFromUIColor(color1Selector.myColor);
            color2RGB.text = getRGBStringFromUIColor(color2Selector.myColor);
            
            //saturationLabel.isHidden = false;
            
            color1Label.isHidden = false;
            color2Label.isHidden = false;
            color1RGB.isHidden = false;
            color2RGB.isHidden = false;
            
            
            color1Selector.isHidden = false;
            color2Selector.isHidden = false;
            
            paletteModeObjects.isHidden = true;
            
            paletteColorRGB.isHidden = true;
            pColor1Selector.isHidden = true;
            pColor2Selector.isHidden = true;
            pColor3Selector.isHidden = true;
            pColor4Selector.isHidden = true;
            pColor5Selector.isHidden = true;
            pColor6Selector.isHidden = true;
            pColor7Selector.isHidden = true;
            pColor8Selector.isHidden = true;
            pColor9Selector.isHidden = true;
            pColor10Selector.isHidden = true;
            pColor11Selector.isHidden = true;
            pColor12Selector.isHidden = true;
            pColor13Selector.isHidden = true;
            pColor14Selector.isHidden = true;
            pColor15Selector.isHidden = true;
            pColor16Selector.isHidden = true;
            
        }
        
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated);
        
        print("\(String(describing: self.navigationController?.viewControllers))");
        
        NotificationCenter.default.addObserver(self, selector: #selector(finishRevertingMode), name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_MODE_VALUE), object: nil)
        
            // clearing history upon entry to the view screen
        bitmapHistory = [Int]();
        
            // we're going to assume the user hasn't reverted (or has unique settings) upon entering the screen
        //hasReverted = false;
        
            // clearing history upon entry
        color1History = [UIColor]();
        color2History = [UIColor]();
        paletteColorHistory = [[UIColor]]();
        
            // should automatically pre-select the correct bitmap
        if ((Device.connectedDevice?.mode?.usesBitmap)!)
        {
            let indexPath = IndexPath(row: (Device.connectedDevice?.mode?.bitmapIndex)! - 1, section: 0);
            bitmapPicker.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition(rawValue: 0));
                // adding the first value to the history
            bitmapHistory += [indexPath.row + 1];
                // on loading in, enforce the stored bitmap
            setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
        }
        else if ((Device.connectedDevice?.mode?.usesPalette)!)
        {
            // if it's a palette mode, add all the first colors to the history
            for i in 0...15
            {
                paletteColorHistory += [[paletteColorSelectors[i]!.myColor]];
            }
            //print("paletteColorHistory: ", paletteColorHistory);
        }
        else
        {
//                // disable the color sliders until a color is chosen
//            hueSlider.isEnabled = false;
//            saturationSlider.isEnabled = false;
//            brightnessSlider.isEnabled = false;
            
                // adding initial values
            color1History += [color1Selector.myColor];
            color2History += [color2Selector.myColor];
            
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated);
        if ((Device.connectedDevice?.mode?.usesBitmap)!)
        {
            
        }
        else if ((Device.connectedDevice?.mode?.usesPalette)!)
        {
            // activate color 1 by default, initialize the color wheel, and then update it so that the knob and brightness sliders are accurate
            pColor1Selector.setHighlighted(true);
            pColorWheel.initializeColorWheel(radius: Float(pColorImage.frame.width / 2), color: pColor1Selector.myColor, owner: self, knobRadius: 15, paletteMode: true);
            updatePaletteColorPicker(pColor1Selector.myColor, fromPicker: false);
        }
        else
        {
                // activate color 1 by default
            setColorSelectorAsActive(isColor1: true);
            
            // radius is half of the image width
            ColorWheel.initializeColorWheel(radius: Float(colorImage.frame.width / 2), color: color1Selector.myColor, owner: self, knobRadius: 15);
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated);
        print("Removing \(modeLabel.text ?? "Default")'s observers (in viewWillDisappear)");
        NotificationCenter.default.removeObserver(self);
    }
    
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
    
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
        return min(bitmaps.count, Device.connectedDevice!.maxBitmaps);
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cellIdentifier = "BitmapPickerCollectionViewCell"
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? BitmapPickerCollectionViewCell else
        {
            Device.reportError(Constants.FAILED_TO_DEQUEUE_COLLECTION_CELLS_FOR_BITMAP_PICKER);
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
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_BITMAP, inputInts: [bitmapIndex], digitsPerInput: 2, sendToMimicDevices: true)
        
        // saving cache
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
    }
//            // don't send anything BLE if it's a demo device
//        if (Device.connectedDevice!.isDemoDevice)
//        {
//            return;
//        }
//            // if we're still waiting on something else, don't send another message
//        else if (Device.connectedDevice!.requestWithoutResponse)
//        {
//            return;
//        }
//        else if (!(Device.connectedDevice?.isConnected)!)
//        {
//            print("Device is not connected");
//            return;
//        }
//        else if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
//        {
//            print("Disconnected");
//
//            // error popup
//            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
//            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
//            {(action) -> Void in
//                print("Should go to the Connect Screen at this point");
//                _ = self.navigationController?.popToRootViewController(animated: true);
//            })
//
//            dialogMessage.addAction(ok);
//
//            self.present(dialogMessage, animated: true, completion: nil);
//            // shows the Connection page (hopefully/eventually)
//            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
//            //self.show(newViewController, sender: self);
//            return;
//        }
//
//            // saving cache
//        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
//
//        let bitmapIndexUInt: UInt8 = UInt8(bitmapIndex);
//
//        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_BITMAP;// + "\(modeIndexUInt)";
//
//        let stringArray: [UInt8] = Array(valueString.utf8);
//        let valueArray = stringArray + [bitmapIndexUInt]
//        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
//        let valueData = NSData(bytes: valueArray, length: valueArray.count)
//
//        print("sending: " + valueString, bitmapIndexUInt, valueArray);
//
//        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
//
//    }
//
            // FIXME: in order to have the
//    private func setColor(colorIndex: Int, color: UIColor, setBothColors: Bool = true)
//    {
//        if (setBothColors)
//        {
//            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: [1] + Device.convertUIColorToIntArray(color), digitsPerInput: 3, sendToMimicDevices: true)
//                // setting flag
//            Device.connectedDevice?.requestedFirstOfTwoColorsChanged = true;
//        }
//        else
//        {
//            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: [colorIndex] + Device.convertUIColorToIntArray(color), digitsPerInput: 3, sendToMimicDevices: true);
//        }
//
//            // saving cache
//        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
//    }
    
        // the setColors command for the nRF8001, which can set both simultaneously
    private func setColors(color1: UIColor, color2: UIColor)
    {
        formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_COLOR, inputInts: Device.convertUIColorToIntArray(color1) + Device.convertUIColorToIntArray(color2), digitsPerInput: 3, sendToMimicDevices: true);
            // saving cache
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
    }
    
    // function for setting the current row of the palette
    private func setPaletteColors()
    {
        let indexOffset = Int((currentColorIndex - 1)/4) * 4; //indexOffset is the first color of the row - color 0-3 = 0, color 4-7 = 4, etc.
        print(indexOffset);
        var colorInts = [Int]();
        // grab the RGB values for each of the colors in the row
        for i in 0...3
        {
            colorInts += Device.convertUIColorToIntArray((Device.connectedDevice?.mode?.paletteColors![indexOffset + i])!);
        }
        //print(colorInts);
        // send the row based on the indexOffset
        switch indexOffset
        {
        case 0:
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE1, inputInts: colorInts, digitsPerInput: 1, sendToMimicDevices: true);
        case 4:
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE2, inputInts: colorInts, digitsPerInput: 1, sendToMimicDevices: true);
        case 8:
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE3, inputInts: colorInts, digitsPerInput: 1, sendToMimicDevices: true);
        case 12:
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_SET_PALETTE4, inputInts: colorInts, digitsPerInput: 1, sendToMimicDevices: true);
        default:
            print("indexOffset out of bounds");
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
        
    }
    
//    func setColors(color1: UIColor, color2: UIColor)
//    {
//
//            // don't send anything BLE if it's a demo device
//        if (Device.connectedDevice!.isDemoDevice)
//        {
//            return;
//        }
//            // if we're still waiting on something else, don't send another message
//        else if (Device.connectedDevice!.requestWithoutResponse)
//        {
//            return;
//        }
//        else if (!(Device.connectedDevice?.isConnected)!)
//        {
//            print("Device is not connected");
//            return;
//        }
//            // checking for disconnection before using a BLE command
//        else if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
//        {
//            print("Disconnected");
//
//            // error popup
//            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
//            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
//            {(action) -> Void in
//                print("Should go to the Connect Screen at this point");
//                _ = self.navigationController?.popToRootViewController(animated: true);
//            })
//
//            dialogMessage.addAction(ok);
//
//            self.present(dialogMessage, animated: true, completion: nil);
//            // shows the Connection page (hopefully/eventually)
//            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
//            //self.show(newViewController, sender: self);
//            return;
//        }
//
//            // saving cache
//        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.SAVE_DEVICE_CACHE), object: nil);
//
//            // creating variables for RGB values of color
//        var red: CGFloat = 0;
//        var green: CGFloat = 0;
//        var blue: CGFloat = 0;
//        var alpha: CGFloat = 0;
//
//            // getting color1's RGB values (from 0 to 1.0)
//        color1.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
//
//            // scaling up to 255
//        red *= 255;
//        green *= 255;
//        blue *= 255;
//
//            // removing decimal places, removing signs, and making them UInt8s
//        let red1 = convertToLegalUInt8(Int(red));
//        let green1 = convertToLegalUInt8(Int(green));
//        let blue1 = convertToLegalUInt8(Int(blue));
//
//            // getting color2's RGB values
//        color2.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
//
//        // scaling up to 255
//        red *= 255;
//        green *= 255;
//        blue *= 255;
//
//        // removing decimal places, removing signs, and making them UInt8s
//        let red2 = convertToLegalUInt8(Int(red));
//        let green2 = convertToLegalUInt8(Int(green));
//        let blue2 = convertToLegalUInt8(Int(blue));
//
//        let valueString = EnlightedBLEProtocol.ENL_BLE_SET_COLOR;
//
//        let stringArray: [UInt8] = Array(valueString.utf8);
//        var valueArray = stringArray;
//        valueArray += [red1];
//        valueArray += [green1];
//        valueArray += [blue1];
//        valueArray += [red2];
//        valueArray += [green2];
//        valueArray += [blue2];
//        // credit to https://stackoverflow.com/questions/24039868/creating-nsdata-from-nsstring-in-swift
//        let valueData = NSData(bytes: valueArray, length: valueArray.count)
//
//        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: valueData, sendToMimicDevices: true)
//    }
    func getThreeDigitRGBStringFromUIColor(_ color: UIColor) -> String
    {
        // getting RGB values of color
        var red: CGFloat = 0;
        var green: CGFloat = 0;
        var blue: CGFloat = 0;
        var alpha: CGFloat = 0;
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // clamping within 0 and 1
        red = max(min(red, 1), 0);
        green = max(min(green, 1), 0);
        blue = max(min(blue, 1), 0);
        // scaling up to 255
        red *= 255;
        green *= 255;
        blue *= 255;
        
            // making them ints so they fit in the text box
        let redString = String(format: "%03d", Int(red));
        let greenString = String(format: "%03d", Int(green));
        let blueString = String(format: "%03d", Int(blue));
        
            // adding to string
        var output: String = "R: " + redString;
        output += " G: " + greenString;
        output += " B: " + blueString;
        return output;
    }
    
    func getRGBStringFromUIColor(_ color: UIColor) -> String
    {
        // getting RGB values of color
        var red: CGFloat = 0;
        var green: CGFloat = 0;
        var blue: CGFloat = 0;
        var alpha: CGFloat = 0;
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha);
        
        // clamping within 0 and 1
        red = max(min(red, 1), 0);
        green = max(min(green, 1), 0);
        blue = max(min(blue, 1), 0);
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
    
        // credit to https://stackoverflow.com/questions/10071756/is-there-function-to-convert-uicolor-to-hue-saturation-brightness for the conversion to HSV/HSB
    public func updateColorPicker(_ newColor: UIColor, fromPicker: Bool)
    {
        var hue: CGFloat = 0;
        var saturation: CGFloat = 0;
        var newBrightness: CGFloat = 0;
        var alpha: CGFloat = 0;
        let _ = newColor.getHue(&hue, saturation: &saturation, brightness: &newBrightness, alpha: &alpha);
       
        // scaling up for respective ranges
        hue *= 360;
        saturation *= 100;
        //newBrightness *= 100;
        
        // converting to Ints
        //let hueInt = Int(hue);
        //let saturationInt = Int(saturation);
        let sliderBrightness = Float(newBrightness * 100);
        
            // if this new color is from setting sliders, we want to set the currently selected Color that way
        if (fromPicker)
        {
            if (currentColorIndex == 1)
            {
                Device.connectedDevice?.mode?.color1 = newColor;
                color1Selector.setBackgroundColor(newColor: newColor);
                color1RGB.text = getRGBStringFromUIColor(color1Selector.myColor);
                
            }
            else
            {
                Device.connectedDevice?.mode?.color2 = newColor;
                color2Selector.setBackgroundColor(newColor: newColor);
                color2RGB.text = getRGBStringFromUIColor(color2Selector.myColor);
            }
            
            
                // update the colors on the hardware
            setColors(color1: (Device.connectedDevice?.mode?.color1) ?? UIColor.black, color2: (Device.connectedDevice?.mode?.color2) ?? UIColor.black);
            
        }
            // otherwise it's from selecting a color, and so we want to enable and set the sliders
        else
        {
            // updating slider background with new values, for some instant feedback
//            hueSlider.minimumTrackTintColor = newColor;
//            hueSlider.maximumTrackTintColor = newColor;
//
//            saturationSlider.minimumTrackTintColor = newColor;
//            saturationSlider.maximumTrackTintColor = newColor;
            
            brightnessSlider.minimumTrackTintColor = newColor;
            brightnessSlider.maximumTrackTintColor = newColor;
            
//            hueSlider.isEnabled = true;
//            saturationSlider.isEnabled = true;
            brightnessSlider.isEnabled = true;
            
//            hueSlider.setValue(Float(hueInt), animated: true);
//            saturationSlider.setValue(Float(saturationInt), animated: true);
            brightnessSlider.setValue(sliderBrightness, animated: true);
            brightness = newBrightness;
            ColorWheel.updateBrightness();
            
            ColorWheel.setColor(newColor: newColor);
        }
        
        
        
            // showing the gamut of colors
//        let minHueColor = UIColor(hue: 0, saturation: saturation, brightness: brightness, alpha: alpha);
//        let maxHueColor = UIColor(hue: 1, saturation: saturation, brightness: brightness, alpha: alpha);
//        hueSlider.minimumTrackTintColor = minHueColor;
//        hueSlider.maximumTrackTintColor = maxHueColor;
//
//        let minSaturationColor = UIColor(hue: hue, saturation: 0, brightness: brightness, alpha: alpha);
//        let maxSaturationColor = UIColor(hue: hue, saturation: 1, brightness: brightness, alpha: alpha);
//        saturationSlider.minimumTrackTintColor = minSaturationColor;
//        saturationSlider.maximumTrackTintColor = maxSaturationColor;
//
//        let minBrightnessColor = UIColor(hue: hue, saturation: saturation, brightness: 0, alpha: alpha);
//        let maxBrightnessColor = UIColor(hue: hue, saturation: saturation, brightness: 1, alpha: alpha);
//        brightnessSlider.minimumTrackTintColor = minBrightnessColor;
//        brightnessSlider.maximumTrackTintColor = maxBrightnessColor;

        
    }
    
    // function to update the color picker on the palette mode
    public func updatePaletteColorPicker(_ newColor: UIColor, fromPicker: Bool)
    {
        // getting HSB values
        var hue: CGFloat = 0;
        var saturation: CGFloat = 0;
        var newBrightness: CGFloat = 0;
        var alpha: CGFloat = 0;
        let _ = newColor.getHue(&hue, saturation: &saturation, brightness: &newBrightness, alpha: &alpha);
       
        // scaling up for respective ranges
        hue *= 360;
        saturation *= 100;
        let sliderBrightness = Float(newBrightness * 100);
        
            // if this new color is from setting sliders, we want to set the currently selected Color that way
        if (fromPicker)
        {
            // set the new color on the Device array, the color preview, and on the hardware
            Device.connectedDevice?.mode?.paletteColors![currentColorIndex - 1] = newColor;
            paletteColorSelectors[currentColorIndex - 1]!.setBackgroundColor(newColor: newColor);
            setPaletteColors();
            
        }
            // otherwise it's from selecting a color preview, and so we want to enable and set the sliders
        else
        {
            // make sure brightness is accurate and enabled
            pBrightnessSlider.minimumTrackTintColor = newColor;
            pBrightnessSlider.maximumTrackTintColor = newColor;
            pBrightnessSlider.isEnabled = true;
            
            pBrightnessSlider.setValue(sliderBrightness, animated: true);
            brightness = newBrightness;
            pColorWheel.updateBrightness();
            
            // make sure color wheel is accurate
            pColorWheel.setColor(newColor: newColor);
        }
        
        // regardless of who called the function, we want to update the RGB text
        paletteColorRGB.text = getThreeDigitRGBStringFromUIColor(paletteColorSelectors[currentColorIndex - 1]!.myColor);
    }
    
    func setColorSelectorAsActive(isColor1: Bool)
    {
        if (isColor1)
        {
            //print("Setting color 1 as active");
            currentColor = color1Selector.myColor;
            currentColorIndex = 1;
            updateColorPicker(currentColor, fromPicker: false);
            color1Selector.setHighlighted(true);
            color1Label.textColor = UIColor(named: "SelectedText");
            color1RGB.textColor = UIColor(named: "SelectedText");
            color2Selector.setHighlighted(false);
            color2Label.textColor = UIColor(named: "NonSelectedText");
            color2RGB.textColor = UIColor(named: "NonSelectedText");
        }
        else
        {
            //print("Setting color 2 as active");
            currentColor = color2Selector.myColor;
            currentColorIndex = 2;
            updateColorPicker(currentColor, fromPicker: false);
            color2Selector.setHighlighted(true);
            color2Label.textColor = UIColor(named: "SelectedText");
            color2RGB.textColor = UIColor(named: "SelectedText");
            color1Selector.setHighlighted(false);
            color1Label.textColor = UIColor(named: "NonSelectedText");
            color1RGB.textColor = UIColor(named: "NonSelectedText");
        }
    }
    
    // MARK: Actions
    
    // marking a color as edit-able by the color wheel
    @IBAction func selectAndEditColor1(_ sender: UITapGestureRecognizer)
    {
        setColorSelectorAsActive(isColor1: true);
    }
    
    @IBAction func selectAndEditColor2(_ sender: UITapGestureRecognizer)
    {
        setColorSelectorAsActive(isColor1: false);
    }
    
    @IBAction func testUITap(_ sender: UITapGestureRecognizer)
    {
        print("Selected", sender);
    }
    
    @IBAction func selectAndEditPaletteColor(_ sender: UITapGestureRecognizer)
    {
        print("selected new palette color");
        // get current color index based on who called the function
        switch sender.view{
        case pColor1Selector:
            currentColorIndex = 1;
        case pColor2Selector:
            currentColorIndex = 2;
        case pColor3Selector:
            currentColorIndex = 3;
        case pColor4Selector:
            currentColorIndex = 4;
        case pColor5Selector:
            currentColorIndex = 5;
        case pColor6Selector:
            currentColorIndex = 6;
        case pColor7Selector:
            currentColorIndex = 7;
        case pColor8Selector:
            currentColorIndex = 8;
        case pColor9Selector:
            currentColorIndex = 9;
        case pColor10Selector:
            currentColorIndex = 10;
        case pColor11Selector:
            currentColorIndex = 11;
        case pColor12Selector:
            currentColorIndex = 12;
        case pColor13Selector:
            currentColorIndex = 13;
        case pColor14Selector:
            currentColorIndex = 14;
        case pColor15Selector:
            currentColorIndex = 15;
        case pColor16Selector:
            currentColorIndex = 16;
        default:
            // cases are exhaustive already but xcode makes you include a default
            print("selected palette color that doesn't exist");
        }
        print("Currently Selected Palette Color: ", currentColorIndex);
        // make sure the correct selector is highlighted and active
        for selector in paletteColorSelectors
        {
            if (selector != paletteColorSelectors[currentColorIndex - 1])
            {
                selector!.setHighlighted(false);
            }
            else
            {
                selector!.setHighlighted(true);
                currentColor = paletteColorSelectors[currentColorIndex - 1]!.myColor;
            }
        }
        print("RGB Values: ", currentColor.cgColor.components!);
        print("Palette Values: ", (Device.connectedDevice?.mode?.paletteColors![currentColorIndex - 1].cgColor.components!)!);
        updatePaletteColorPicker(currentColor, fromPicker: false);
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
    
    // undo palette color
    @IBAction func pressedPaletteUndo(_ sender: UIButton)
    {
        // if we have history to go back to
        if (paletteColorHistory[currentColorIndex - 1].count > 1)
        {
            // set the color on the device, then remove the color from the history and update the palette color picker
            Device.connectedDevice?.mode?.paletteColors![currentColorIndex - 1] = paletteColorHistory[currentColorIndex - 1][paletteColorHistory[currentColorIndex - 1].count - 2];
            paletteColorHistory[currentColorIndex - 1].removeLast();
            updatePaletteColorPicker((Device.connectedDevice?.mode?.paletteColors![currentColorIndex - 1])!, fromPicker: false);
            updatePaletteColorPicker((Device.connectedDevice?.mode?.paletteColors![currentColorIndex - 1])!, fromPicker: true);
        }
        else
        {
            // if the history array is empty, buzz
            print("No more history to undo");
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
    }
    
    @IBAction func pressedColorUndo(_ sender: UIButton)
    {
            // whether it's color 1 or color 2's undo button
        if (sender == color1UndoButton)
        {
            if (color1History.count > 1)
            {
                // setting color 1 as the active color selector
                setColorSelectorAsActive(isColor1: true)
                
                    // going back in history
                Device.connectedDevice?.mode?.color1 = color1History[color1History.count - 2];
                    // removing history
                color1History.removeLast();
                    // updating colors on the hardware (unneccesary because it's done in updateColorPicker(fromPicker: true))
                // setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!);
                
                
                    // have to do both, because it isn't coming from the picker or the preview
                updateColorPicker((Device.connectedDevice?.mode?.color1)!, fromPicker: false);
                updateColorPicker((Device.connectedDevice?.mode?.color1)!, fromPicker: true);
                
            }
            else
            {
                print("No more history to undo");
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
        }
        else
        {
            if (color2History.count > 1)
            {
                // setting color 1 as the active color selector
                setColorSelectorAsActive(isColor1: false)
                
                // going back in history
                Device.connectedDevice?.mode?.color2 = color2History[color2History.count - 2];
                // removing history
                color2History.removeLast();
                // updating colors on the hardware (no longer necessary - see above)
                //setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!);
                
                
                // have to do both, because it isn't coming from the picker or the preview
                updateColorPicker((Device.connectedDevice?.mode?.color2)!, fromPicker: false);
                updateColorPicker((Device.connectedDevice?.mode?.color2)!, fromPicker: true);
                
            }
            else
            {
                print("No more history to undo");
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
        }
    }
    
    @IBAction func changedColor(_ sender: UISlider)
    {
        // if we're on a palette mode, make sure we set the correct color picker and brightness slider
        if ((Device.connectedDevice?.mode?.usesPalette)!)
        {
            let newHue: CGFloat = pColorWheel.hue;
            let newSaturation: CGFloat = pColorWheel.saturation;
            let newBrightness: CGFloat = CGFloat(pBrightnessSlider.value / pBrightnessSlider.maximumValue);
            let newColor = UIColor(hue: newHue, saturation: newSaturation, brightness: newBrightness, alpha: 1);
            
            pBrightnessSlider.minimumTrackTintColor = newColor;
            pBrightnessSlider.maximumTrackTintColor = newColor;
            
            brightness = CGFloat(pBrightnessSlider.value / pBrightnessSlider.maximumValue);
            
            pColorWheel.updateBrightness();
            
            paletteColorSelectors[currentColorIndex - 1]!.setBackgroundColor(newColor: newColor);
        }
        else
        {
            let newHue: CGFloat = ColorWheel.hue;
            let newSaturation: CGFloat = ColorWheel.saturation;
            let newBrightness: CGFloat = CGFloat(brightnessSlider.value / brightnessSlider.maximumValue);
            let newColor = UIColor(hue: newHue, saturation: newSaturation, brightness: newBrightness, alpha: 1);
            //
            //            // updating slider background with new values, for some instant feedback
            //        hueSlider.minimumTrackTintColor = newColor;
            //        hueSlider.maximumTrackTintColor = newColor;
            //
            //        saturationSlider.minimumTrackTintColor = newColor;
            //        saturationSlider.maximumTrackTintColor = newColor;
            
            brightnessSlider.minimumTrackTintColor = newColor;
            brightnessSlider.maximumTrackTintColor = newColor;
            
            brightness = CGFloat(brightnessSlider.value / brightnessSlider.maximumValue);
            
            ColorWheel.updateBrightness();
            
            if (currentColorIndex == 1)
            {
                color1Selector.setBackgroundColor(newColor: newColor);
            }
            else
            {
                color2Selector.setBackgroundColor(newColor: newColor);
            }
        }
        
    }
    
    @IBAction func createdNewColor(_ sender: UISlider)
    {
        // if we're on a palette mode, make sure we set the correct color picker and brightness slider
        if ((Device.connectedDevice?.mode?.usesPalette)!)
        {
            let newHue: CGFloat = pColorWheel.hue;
            let newSaturation: CGFloat = pColorWheel.saturation;
            let newBrightness: CGFloat = CGFloat(pBrightnessSlider.value / pBrightnessSlider.maximumValue);
            let newColor = UIColor(hue: newHue, saturation: newSaturation, brightness: newBrightness, alpha: 1);

            pColorWheel.updateBrightness();
            
            updatePaletteColorPicker(newColor, fromPicker: true);
            paletteColorHistory[currentColorIndex - 1] += [newColor];
        }
        else{
            let newHue: CGFloat = ColorWheel.hue;
            let newSaturation: CGFloat = ColorWheel.saturation;
            let newBrightness: CGFloat = CGFloat(brightnessSlider.value / brightnessSlider.maximumValue);
            let newColor = UIColor(hue: newHue, saturation: newSaturation, brightness: newBrightness, alpha: 1);
            
            //print("new HSB: \(newHue), \(newSaturation), \(newBrightness)");
            if (currentColorIndex == 1)
            {
                color1History += [newColor];
            }
            else
            {
                color2History += [newColor];
            }
            
            ColorWheel.updateBrightness();
            
            updateColorPicker(newColor, fromPicker: true);
        }
    }
    
    @IBAction func revertMode(_ sender: UIButton)
    {
        print("Reverting mode, button was just pressed");
            // disabling the revert button until the action is done
        sender.isEnabled = false;
        
            // if it's a demo device, we can just create a new, unchanged demo device and read the mode values from there
        if (Device.connectedDevice!.isDemoDevice)
        {
                // creating a reference to the mode in its unchanged state
            let baseMode = Device.createDemoDevice().modes[Device.connectedDevice!.currentModeIndex - 1];
            
            if ((Device.connectedDevice?.mode?.usesBitmap)!)
            {
                Device.connectedDevice?.mode?.bitmapIndex = baseMode.bitmapIndex;
                
                    // clearing the history
                //bitmapHistory = [Int]();
            }
            else
            {
                Device.connectedDevice?.mode?.color1 = baseMode.color1;
                Device.connectedDevice?.mode?.color2 = baseMode.color2;
                
                    // clearing the history
                //color1History = [UIColor]();
                //color2History = [UIColor]();
            }
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.RECEIVED_MODE_VALUE), object: nil);
        }
        else
        {
            if ((Device.connectedDevice?.mode?.usesBitmap)!)
            {
                bitmapUndoButton.isEnabled = false;
                bitmapPicker.allowsSelection = false;
            }
            else
            {
                color1UndoButton.isEnabled = false;
                color2UndoButton.isEnabled = false;
                
                //hueSlider.isEnabled = false;
                //saturationSlider.isEnabled = false;
                brightnessSlider.isEnabled = false;
                
            }
            
            // setting flag to revert
            Device.connectedDevice?.currentlyRevertingMode = true;
            // calling "Get Mode" on this specific mode, with the special flag above set
            formatAndSendPacket(EnlightedBLEProtocol.ENL_BLE_GET_MODE, inputInts: [(Device.connectedDevice?.mode?.index)!]);
        }
        
    }
    
    
    // MARK: - Private Methods
    
        // basically viewWillAppear (after getting the "new" values from reverting)
    @objc private func finishRevertingMode()
    {
        print("Finished reverting mode \(modeLabel.text ?? "Default"), updating screen");
        if ((Device.connectedDevice?.mode?.usesBitmap)!)
        {
            bitmapUIImage.image = Device.connectedDevice?.thumbnails[(Device.connectedDevice?.mode?.bitmapIndex)! - 1];
            
            bitmapRevertButton.isEnabled = true;
            bitmapUndoButton.isEnabled = true;
            bitmapPicker.allowsSelection = true;
            
            let indexPath = IndexPath(row: (Device.connectedDevice?.mode?.bitmapIndex)! - 1, section: 0);
            bitmapPicker.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition(rawValue: 0));
            // adding the first value to the history
            bitmapHistory += [indexPath.row + 1];
                // on loading in, enforce the stored bitmap
            setBitmap((Device.connectedDevice?.mode?.bitmapIndex)!);
        }
        else
        {
            color1Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color1)!);
            color2Selector.setBackgroundColor(newColor: (Device.connectedDevice?.mode?.color2)!);
            
            color1RGB.text = getRGBStringFromUIColor(color1Selector.myColor);
            color2RGB.text = getRGBStringFromUIColor(color2Selector.myColor);
            
            colorRevertButton.isEnabled = true;
            color1UndoButton.isEnabled = true;
            color2UndoButton.isEnabled = true;
            
            //hueSlider.isEnabled = true;
            //saturationSlider.isEnabled = true;
            brightnessSlider.isEnabled = true;
            
                // re-activating the sliders for the current color
            setColorSelectorAsActive(isColor1: (currentColorIndex == 1))
            
                // setting it on the hardware
            setColors(color1: (Device.connectedDevice?.mode?.color1)!, color2: (Device.connectedDevice?.mode?.color2)!)
            
                // adding initial values
            color1History += [color1Selector.myColor];
            color2History += [color2Selector.myColor];
        }
    }
    
        // takes an Int and makes sure it will fit in an unsigned Int8 (including calling abs())
    private func convertToLegalUInt8(_ value: Int) -> UInt8
    {
        // absolute value
        var output = abs(value);
        
        output = min(Int(UInt8.max), max(value, Int(UInt8.min)));
        
        return UInt8(output);
    }
    
    private func formatAndSendPacket(_ inputString: String, inputInts: [Int] = [Int](), digitsPerInput: Int = 2, sendToMimicDevices: Bool = false)
    {
        print(" ");
        print(" ");
        print("About to send BLE command \(inputString) with arguments \(inputInts)")
        
        if (Device.connectedDevice!.isDemoDevice)
        {
            print("Not sending to demo devices");
            return;
        }
        else if (!(Device.connectedDevice?.isConnected)!)
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
        }
        
        let data = Device.formatPacket(inputString, inputInts: inputInts, digitsPerInput: digitsPerInput)
            // sending to peripheral(s)
        BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: data, sendToMimicDevices: sendToMimicDevices)
        
    }
    
//    // sends get commands to the hardware, using the protocol as the inputString (and an optional int or two at the end, for certain getters)
//    private func getValue(_ inputString: String, inputInt: Int = -1, secondInputInt: Int = -1)
//    {
//            // don't do BLE commands if it's a demo device
//        if (Device.connectedDevice!.isDemoDevice)
//        {
//            return;
//        }
//            // if we're still waiting on something else, don't send another message
//        else if (Device.connectedDevice!.requestWithoutResponse)
//        {
//            return;
//        }
//        else if (!(Device.connectedDevice?.isConnected)!)
//        {
//            print("Device is not connected");
//            return;
//        }
//
//        if (Device.connectedDevice!.peripheral.state == CBPeripheralState.disconnected)
//        {
//            print("Disconnected");
//            // error popup
//            let dialogMessage = UIAlertController(title:"Disconnected", message: "The BLE device is no longer connected. Return to the connection page and reconnect, or connect to a different device.", preferredStyle: .alert);
//            let ok = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
//            {(action) -> Void in
//                print("Should go to the Connect Screen at this point");
//                _ = self.navigationController?.popToRootViewController(animated: true);
//            })
//
//            dialogMessage.addAction(ok);
//
//            self.present(dialogMessage, animated: true, completion: nil);
//            // shows the Connection page (hopefully/eventually)
//            //let newViewController: BLEConnectionTableViewController = BLEConnectionTableViewController();
//            //self.show(newViewController, sender: self);
//            return;
//        }
//
//
//
//        // if an input value was specified, especially for the getName/getMode commands, add it to the package
//        if (inputInt != -1)
//        {
//            if (secondInputInt != -1)
//            {
//                let uInputInt: UInt8 = UInt8(inputInt);
//                let secondUInputInt: UInt8 = UInt8(secondInputInt);
//                let stringArray: [UInt8] = Array(inputString.utf8);
//                let outputArray = stringArray + [uInputInt] + [secondUInputInt];
//                let outputData = NSData(bytes: outputArray, length: outputArray.count)
//                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
//            }
//            else
//            {
//                let uInputInt: UInt8 = UInt8(inputInt);
//                let stringArray: [UInt8] = Array(inputString.utf8);
//                let outputArray = stringArray + [uInputInt];
//                let outputData = NSData(bytes: outputArray, length: outputArray.count)
//                BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: outputData, sendToMimicDevices: false)
//            }
//        }
//        else
//        {
//            let inputNSString = (inputString as NSString).data(using: String.Encoding.ascii.rawValue);
//            // https://stackoverflow.com/questions/40088253/how-can-i-print-the-content-of-a-variable-of-type-data-using-swift for printing NSString
//            BLEConnectionTableViewController.sendBLEPacketToConnectedPeripherals(valueData: inputNSString! as NSData, sendToMimicDevices: false)
//
//        }
//    }
    
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
//    {
//        print("removing observers");
//            // remove the notification observer before leaving
//        NotificationCenter.default.removeObserver(self);
//    }
    
    
    // MARK: - Public Methods
    
    public func getCurrentColorIndex() -> Int
    {
        return currentColorIndex;
    }

}

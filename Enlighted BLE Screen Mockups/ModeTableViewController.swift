//
//  ModeTableViewController.swift
//  Enlighted BLE Screen Mockups
//
//  Created by Bryce Suzuki on 9/28/18.
//  Copyright © 2018 Bryce Suzuki. All rights reserved.
//

import UIKit

class ModeTableViewController: UITableViewController
{
    
    // MARK: Properties
    
    // sample list of modes
    var modes = [Mode]();
    
    // whether or not the currently selected mode has to be initialized
    var initialModeSelected = false;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();

        // Load the sample modes.
        loadSampleModes();
        
        // setting this as the delegate of the viewController
        tableView.delegate = self;
        
        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated);
        let indexPath = IndexPath(row:(Device.connectedDevice?.currentModeIndex)! - 1, section:0);
        self.tableView.selectRow(at: indexPath, animated: animated, scrollPosition: UITableViewScrollPosition(rawValue: 0)!)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return modes.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ModeTableViewCell";
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ModeTableViewCell else
        {
            fatalError("The dequeued cell is not an instance of ModeTableViewCell");
        }

        let currentMode = modes[indexPath.row]
        
        cell.modeLabel.text = currentMode.name;
        cell.modeIndex.text = String(currentMode.index);
        cell.mode = currentMode;
        if (cell.mode?.index == Device.connectedDevice?.currentModeIndex)
        {
//            cell.setSelected(true, animated: true)
        }
        
        cell.updateImages();
        // Configure the cell...

        return cell
    }
    
    // MARK: UITableDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        // When selecting a mode,
        
        // set the device's mode to that mode and update the index.
        Device.connectedDevice?.mode = modes[indexPath.row];
        Device.connectedDevice?.currentModeIndex = (Device.connectedDevice?.mode?.index)!;
    }
    
    // #Warning: Doesn't select initial mode yet
    // doesn't work right now:
    func tableView(_tableView: UITableView, willDisplayCell: ModeTableViewCell, forRowAtIndexPath: IndexPath)
    {
        // if the page is loading for the first time, select the first mode by default.
        willDisplayCell.setSelected(true, animated: true);
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

        // credit to https://stackoverflow.com/questions/28471164/how-to-set-back-button-text-in-swift
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
//    {
//        let backItem
//        // Get the new view controller using segue.destinationViewController.
//        // Pass the selected object to the new view controller.
//    }
    
    
    // MARK: Private Methods
    
    private func loadSampleModes()
    {
        // colors for certain modes
        let colorArray1 = [UIColor.green, UIColor.yellow];
        let colorArray2 = [UIColor.cyan, UIColor.blue];
        let bitmap1 = UIImage(named: "Bitmap1");
        let bitmap2 = UIImage(named: "Bitmap2");
        
        guard let mode1 = Mode(name:"SLOW TWINKLE", index: 1, usesBitmap: false, bitmap: nil, colors: colorArray1) else
        {
            fatalError("unable to instantiate mode1");
        }
        
        guard let mode2 = Mode(name:"MEDIUM TWINKLE", index: 2, usesBitmap: false, bitmap: nil, colors: colorArray2) else
        {
            fatalError("unable to instantiate mode2");
        }
        
        guard let mode3 = Mode(name:"FAST TWINKLE", index: 3, usesBitmap: true, bitmap: bitmap1, colors: [nil]) else
        {
            fatalError("unable to instantiate mode3");
        }
        
        guard let mode4 = Mode(name:"EXTREMELY LONG TEST NAME (2 Lines)", index: 4, usesBitmap: true, bitmap: bitmap2, colors: [nil]) else
        {
            fatalError("unable to instantiate mode4");
        }
        
        modes += [mode1, mode2, mode3, mode4];
        
    }

}

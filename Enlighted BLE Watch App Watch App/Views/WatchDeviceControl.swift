//
//  WatchDeviceControl.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/21/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI

struct WatchDeviceControl: View {
    //BLE controller environment object that handles all communication with the WatchDevice
    @EnvironmentObject var BLE: BLEConnectionController
    //Main Device
    @ObservedObject var thisDevice: WatchDevice = WatchDevice.connectedDevice!
    
    //State variables to deal with UI elements
    @State var loading = true
    @State var currentMode = -1
    @State var brightnessSliderValue = 0.0
    
    //Event listeners for interrupt signals - Credit to: https://stackoverflow.com/questions/58818046/how-to-set-addobserver-in-swiftui
    let loadingListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.WATCH_READY_TO_SHOW))
    let brightnessListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS))
    
    //Helper function for the next and previous buttons
    func newMode(next: Bool){
        //Set the mode index depending on which button was pushed
        if(next){
            thisDevice.currentModeIndex = (thisDevice.currentModeIndex % thisDevice.maxNumModes) + 1
        } else{
            thisDevice.currentModeIndex -= 1
            if(thisDevice.currentModeIndex < 1){
                thisDevice.currentModeIndex = thisDevice.maxNumModes
            }
        }
        //Send the mode request
        BLE.setPrimaryMode(newModeIndex: thisDevice.currentModeIndex)
    }
    
    //Helper function for the brightness slider
    func BrightnessSliderChanged(){
        BLE.changeBrightness(newBrightness: brightnessSliderValue)
    }
    
    //Main body
    var body: some View {
        VStack{
            ZStack{ //Zstack so that we can layer the progressView (loading circle) over the main controls and restrict the user's interaction during loading
                VStack{ //Main vertical stack
                    //Basic device info
                    Text(thisDevice.name)
                    Text("Current Mode: \(String(thisDevice.currentModeIndex))")
                    HStack{ //Mode button horizontal stack
                        Button("<"){
                            print("Previous mode")
                            newMode(next: false)
                        }
                        Button(">"){
                            print("Next mode")
                            newMode(next: true)
                        }
                    }
                    Text("Brightness: \(Int(brightnessSliderValue))")
                    BrightnessSlider(value: $brightnessSliderValue)
                }.safeAreaPadding(.top, 80) //Credit to: https://swiftwithmajid.com/2021/11/03/managing-safe-area-in-swiftui/
                if(loading){ //Layer the progress view on top of the controls so that users can't interact with them while loading
                    ProgressView()
                }
            }
        }.onAppear(perform: { //When this view appears, connect to the selected device
            if (thisDevice.name != "emptyDevice"){
                WatchDevice.setConnectedDevice(newDevice: thisDevice)
                WatchDevice.connectedDevice!.isConnected = false
                WatchDevice.connectedDevice!.isConnecting = true
                print("     Attempting to connect to peripheral: ")
                print(WatchDevice.connectedDevice!.peripheral ?? "No Peripheral Found")
                BLE.connectToPrimaryDevice()
            } //After a second, setup the primary device
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                BLE.setupPrimaryDevice()
                print("Initiating device setup")
            })
        })
        .onDisappear(perform: { //When the user leaves the control page, disconnect from the corresponding device
            BLE.disconnectFromPrimaryDevice()
        })
        .onReceive(loadingListener, perform: {_ in //When we get the signal that loading is done, remove the progressView
            loading = false
            brightnessSliderValue = Double(thisDevice.brightness)
        })
        .onReceive(brightnessListener, perform: {_ in //When we get the signal that the brightness has changed, update it
            BrightnessSliderChanged()
        })
        
    }
}

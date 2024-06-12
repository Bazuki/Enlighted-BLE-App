//
//  WatchDeviceControl.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/21/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI
import AVFoundation
import AVKit

struct WatchDeviceControl: View {
    //BLE controller environment object that handles all communication with the WatchDevice
    @EnvironmentObject var BLE: BLEConnectionController
    //Main Device
    @ObservedObject var thisDevice: WatchDevice = WatchDevice.connectedDevice!
    
    //ScenePhase environment variable, which lets us tell when the app is inactive
    @Environment(\.scenePhase) var scenePhase
    //Dismiss environment variable, which lets us go back to the device list if we get disconnected
    @Environment(\.dismiss) var dismiss
    
    //State variables to deal with UI elements
        //Numerical slider or mode values
    @State var currentMode = -1
    @State var brightnessSliderValue = 0.0
    @State var crossfadeSliderValue = 0.0
    
        //State booleans for showing different screens
    @State var loading = true
    @State var deviceIsSetup = false
    @State var brightnessControlMode = false
    @State var crossfadeControlMode = false
    
    //Current screen being shown
    @State var selectedTab = 0
    
    
    //Event listeners for interrupt signals - Credit to: https://stackoverflow.com/questions/58818046/how-to-set-addobserver-in-swiftui
    let loadingListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.WATCH_READY_TO_SHOW))
    let brightnessChangeListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS))
    let crossfadeChangeListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_CROSSFADE))
    let deviceConnectionListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CONNECTED_TO_WATCH_DEVICE))
    let disconnectListener = NotificationCenter.default.publisher(for:  Notification.Name(rawValue: Constants.MESSAGES.DISCONNECTED_FROM_WATCH_DEVICE))
    
    //MARK: DIMMED STATE TESTER
    let brightnessToggleListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: "toggleBrightness"))
    
    //Setup non-attached timer for brightness ticks
    let brightnessTimer = Timer(timeInterval: 0.33, repeats: true){ timer in
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS), object: nil)
    }
    
    //Brightness toggle timer ONLY FOR TESTING IF BLE CONNECTIONS CAN BE MADE AND MAINTAINED WHEN THE APP IS IN THE FOREGROUND BUT DIMMED
    let brightnessToggleTimer = Timer(timeInterval: 5, repeats: true){timer in
        NotificationCenter.default.post(name: Notification.Name(rawValue: "toggleBrightness"), object: nil)
    }
    
    //VideoPlayerModel to keep the screen awake by playing a still shot of the enlighted logo in the background
    @ObservedObject var videoPlayerModel: VideoPlayerModel = VideoPlayerModel()
    
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
    
    //Helper function for the brightness slider/timer
    func BrightnessSliderChanged(){
        //print("Checking if we need to send brightness")
        if((Int(brightnessSliderValue) != WatchDevice.connectedDevice?.brightness) && !WatchDevice.connectedDevice!.requestWithoutResponse){ //Send a new brightness if it's different from what we have stored and if we aren't waiting for a response (so that we don't spam the fifo if it's caught up already)
            BLE.changeBrightness(newBrightness: brightnessSliderValue)
        } else {
            if(!(WatchDevice.connectedDevice?.checkedLastBrightnessChange)!){ //this flag will be set by the callback when we receive a success response from the hardware.  If there's a failure, it will retry the request
                print("Double checking the brightness: \(thisDevice.brightness)")
                BLE.getPrimaryBrightness()
                WatchDevice.connectedDevice?.checkedLastBrightnessChange = true
            }
            //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHECK_BRIGHTNESS), object: nil)
        }
    }
    
    //MARK: Main body
    var body: some View {
        VStack{
            ZStack{ //Zstack so that we can layer the progressView (loading circle) over the main controls and restrict the user's interaction during loading
                
                //Underlying Video Player to keep the watch alive
                VideoPlayerView()
                    .ignoresSafeArea()
                    .opacity(0.75)
                TabView(selection: $selectedTab){
                    VStack{ //Main vertical stack
                        //Basic device info
                        //Text(thisDevice.name)
                        Text("\(loading ? String("Loading...") : "\(String(thisDevice.currentModeIndex )): \(thisDevice.modeNames[thisDevice.currentModeIndex])")")
                            .fixedSize(horizontal: false, vertical: true)
                        //TODO: Change this to "#: *Mode Name*"
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
                        //Text("Brightness: \(loading ? String("Loading...") : String(Int(brightnessSliderValue)))")
                        //BrightnessSlider(value: $brightnessSliderValue, orientation: false)
                        Spacer()
                    }.tag(0)
                    //.safeAreaPadding(.top, 80) //Credit to: https://swiftwithmajid.com/2021/11/03/managing-safe-area-in-swiftui/
                    VStack{ // Extra control VStack
                        Spacer()
                        if (!brightnessControlMode && !crossfadeControlMode){
                            Button{
                                print("Switching to brightness control")
                                withAnimation{
                                    brightnessControlMode = true
                                }
                            } label: {
                                DynamicSliderValueButtonLabelView(value: $brightnessSliderValue, title: "Brightness", minValue: 0, maxValue: 255)
                            }
                            Button(){
                                print("Switching to crossfade control")
                                withAnimation{
                                    crossfadeControlMode = true
                                }
                            } label: {
                                DynamicSliderValueButtonLabelView(value: $crossfadeSliderValue, title: "Crossfade", minValue: 0, maxValue: 100)
                            }
                        } else if (brightnessControlMode){
                            HStack{
                                Button("Back"){
                                    withAnimation{
                                        brightnessControlMode = false
                                    }
                                }
                                BrightnessSlider(value: $brightnessSliderValue, orientation: true)
                            }
                        } else if (crossfadeControlMode){
                            HStack{
                                Button("Back"){
                                    withAnimation{
                                        crossfadeControlMode = false
                                    }
                                }
                                CrossfadeSlider(value: $crossfadeSliderValue, orientation: true)
                            }
                        }
                        Spacer()
                    }
                    //.ignoresSafeArea()
                    .safeAreaPadding(.bottom, 10)
                    .tag(1)
                }.tabViewStyle(.carousel)
                if(loading){ //Layer the progress view on top of the controls so that users can't interact with them while loading
                    ProgressView()
                }
            }
            //MARK: Appear, disappear, and custom message listeners
        }.onAppear(perform: {
            
            //When this view appears, connect to the selected device if it's a real device
            if (thisDevice.name != "emptyDevice"){
                loading = true
                WatchDevice.setConnectedDevice(newDevice: thisDevice)
                WatchDevice.connectedDevice!.isConnected = false
                WatchDevice.connectedDevice!.isConnecting = true
                print("     Attempting to connect to peripheral: ")
                print(WatchDevice.connectedDevice!.peripheral ?? "No Peripheral Found")
                BLE.connectToPrimaryDevice()
            }
            
            
        })
        .onDisappear(perform: { //When the user leaves the control page, disconnect from the corresponding device
            deviceIsSetup = false
            //videoPlayerModel.handleDisappear()
            BLE.disconnectFromPrimaryDevice()
        })
        .onReceive(deviceConnectionListener, perform: {_ in //When the BLE controller tells us that we've connected, initiate the device setup phase
            if(!deviceIsSetup){
                print("Got the connection message, initiating device setup")
                BLE.setupPrimaryDevice()
                deviceIsSetup = true
            } else{
                print("Already setting up")
            }
        })
        .onReceive(loadingListener, perform: {_ in //When we get the signal that loading is done, remove the progressView and start the brightness timer
            loading = false
            brightnessSliderValue = Double(thisDevice.brightness)
            crossfadeSliderValue = Double(thisDevice.crossfade)
            RunLoop.main.add(brightnessTimer, forMode: .common)
            //RunLoop.main.add(brightnessToggleTimer, forMode: .common)
        })
        .onReceive(brightnessChangeListener, perform: {_ in //When we get the signal that the brightness has changed, update it
            BrightnessSliderChanged()
        })
        .onReceive(crossfadeChangeListener, perform: {_ in
            BLE.changeCrossfade(newCrossfade: crossfadeSliderValue)
        })
        .onReceive(disconnectListener, perform: {_ in //If we've disconnected, reset the deviceIsSetup flag and leave the control screen
            deviceIsSetup = false
            dismiss()
        })
        .onReceive(brightnessToggleListener, perform: {_ in //For testing purposes so that there's a visible indicator on the hardware that the app hasn't fallen asleep
            if(thisDevice.brightness > 10){
                BLE.changeBrightness(newBrightness: 10)
            } else {
                BLE.changeBrightness(newBrightness: 127)
            }
        })
        .toolbar((selectedTab == 1) ? .hidden : .visible)
    }
}

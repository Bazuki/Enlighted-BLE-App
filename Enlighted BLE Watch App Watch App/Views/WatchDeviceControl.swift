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
    
    //Workout Manager object, which will give us heartrate data
    @EnvironmentObject var workoutManager: WorkoutManager
    
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
    @State var workoutControlMode = false
    
    //Current screen being shown
    @State var selectedTab = 0
    
    //Loading string so we can tell the user what is happening when the watch is loading limits, modes, brightness, etc.
    @State var loadingString: String?
    
    
    //Event listeners for interrupt signals - Credit to: https://stackoverflow.com/questions/58818046/how-to-set-addobserver-in-swiftui
    let loadingListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.WATCH_READY_TO_SHOW))
    let brightnessChangeListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS))
    let crossfadeChangeListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_CROSSFADE))
    let deviceConnectionListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.CONNECTED_TO_WATCH_DEVICE))
    let disconnectListener = NotificationCenter.default.publisher(for:  Notification.Name(rawValue: Constants.MESSAGES.DISCONNECTED_FROM_WATCH_DEVICE))
    let workoutListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.ENDED_WORKOUT))
    let loadingStringListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: Constants.MESSAGES.PARSED_COMPLETE_PACKET))
    
    //MARK: DIMMED STATE TESTER
    let brightnessHRChangeListener = NotificationCenter.default.publisher(for: Notification.Name(rawValue: "HRBrightness"))
    
    //Setup non-attached timer for brightness ticks
    let brightnessTimer = Timer(timeInterval: 0.33, repeats: true){ timer in
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS), object: nil)
    }
    
    //Brightness toggle timer ONLY FOR TESTING IF BLE CONNECTIONS CAN BE MADE AND MAINTAINED WHEN THE APP IS IN THE FOREGROUND BUT DIMMED
    let brightnessToggleTimer = Timer(timeInterval: 5, repeats: true){timer in
        NotificationCenter.default.post(name: Notification.Name(rawValue: "HRBrightness"), object: nil)
    }
    
    //Helper function for the next and previous buttons
    func newMode(next: Bool){
        //Set the mode index depending on which button was pushed
        if(next){
            thisDevice.currentModeIndex = ((thisDevice.currentModeIndex + 1 ) % thisDevice.maxNumModes)
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
    func CheckSliderValues(){
        //print("Checking if we need to send brightness")
        if((Int(brightnessSliderValue) != WatchDevice.connectedDevice?.brightness) && !WatchDevice.connectedDevice!.requestWithoutResponse){ //Send a new brightness if it's different from what we have stored and if we aren't waiting for a response (so that we don't spam the fifo if it's caught up already)
            BLE.changeBrightness(newBrightness: brightnessSliderValue)
        } else if(!(WatchDevice.connectedDevice?.checkedLastBrightnessChange)!){ //this flag will be set by the callback when we receive a success response from the hardware.  If there's a failure, it will retry the request
                print("Double checking the brightness: \(thisDevice.brightness)")
                BLE.getPrimaryBrightness()
                WatchDevice.connectedDevice?.checkedLastBrightnessChange = true
            //NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHECK_BRIGHTNESS), object: nil)
        } else if ((Int(crossfadeSliderValue) != WatchDevice.connectedDevice?.crossfade) && !WatchDevice.connectedDevice!.requestWithoutResponse){
            BLE.changeCrossfade(newCrossfade: crossfadeSliderValue)
        }
    }
    
    //Change brightness based on the heartrate
    func HRBrightnessChange() {
        if (workoutControlMode && workoutManager.running){
            print("**********REACTING TO HEARTRATE CONTROL**********")
            if (workoutManager.heartRate < 70){
                BLE.changeBrightness(newBrightness: 127)
            } else {
                BLE.changeBrightness(newBrightness: 128)
            }
        }
    }
    
    //MARK: Main body
    var body: some View {
        GeometryReader{ geometry in
            VStack{
                ZStack{ //Zstack so that we can layer the progressView (loading circle) over the main controls and restrict the user's interaction during loading

                    TabView(selection: $selectedTab){ //Main TabView that holds the mode control on the first page and the brightness, crossfade, and continuous control on the second page
                        VStack{ //Main vertical stack
                            //Basic device info
                            Text("\(loading ? "" : "\(String(thisDevice.currentModeIndex )): \(thisDevice.name == "emptyDevice" ? "Demo Mode": thisDevice.modeNames[thisDevice.currentModeIndex - 1])")") //modeNames is zero justified while currentModeIndex is not, so we need to subtract one from the index to get the correct modeName and not cause an index out of bounds
                                .fixedSize(horizontal: false, vertical: true) //Credit to: https://stackoverflow.com/questions/56505929/the-text-doesnt-get-wrapped-in-swift-ui
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
                            Spacer()
                        }.tag(0)
                        //.safeAreaPadding(.top, 80) //Credit to: https://swiftwithmajid.com/2021/11/03/managing-safe-area-in-swiftui/
                        VStack{ // Extra control VStack
                            Spacer()
                            if (!brightnessControlMode && !crossfadeControlMode && !workoutControlMode){
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
                                Button(){
                                    print("Switching to workout control")
                                    withAnimation{
                                        workoutControlMode = true
                                    }
                                } label: {
                                    DynamicSliderValueButtonLabelView(value: Binding.constant(0), title: "Heart Rate Control", minValue: 0, maxValue: 1)
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
                            } else if (workoutControlMode){
                                WorkoutSessionView()
                                    .onDisappear{
                                        workoutControlMode = false
                                    }
                                    .gesture(workoutControlMode ? DragGesture() : nil) //Credit to: https://stackoverflow.com/questions/63168014/swiftui-2-0-tabview-disable-swipe-to-change-page
                                    .focusable()
                            }
                            Spacer()
                        }
                        //.ignoresSafeArea()
                        .safeAreaPadding(.bottom, 10)
                        .tag(1)
                    }
                        .tabViewStyle(.carousel)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: workoutControlMode ? .never : .automatic)) //Credit to: https://stackoverflow.com/questions/63168014/swiftui-2-0-tabview-disable-swipe-to-change-page
                    if(loading){ //Layer the progress view on top of the controls so that users can't interact with them while loading
                        ProgressView(label: {Text(loadingString ?? "Loading")})
                    }
                }.background(content: { //Enlighted logo in the background
                    Image("logo_1024")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                })
                //MARK: Appear, disappear, and custom message listeners
            }
        }.onAppear(perform: {
            
            //When this view appears, connect to the selected device if it's a real device
            if (thisDevice.name != "emptyDevice"){
                loadingString = thisDevice.loadingStatus
                loading = true
                WatchDevice.setConnectedDevice(newDevice: thisDevice)
                WatchDevice.connectedDevice!.isConnected = false
                WatchDevice.connectedDevice!.isConnecting = true
                print("     Attempting to connect to peripheral: ")
                print(WatchDevice.connectedDevice!.peripheral ?? "No Peripheral Found")
                BLE.connectToPrimaryDevice()
            } else {
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.WATCH_READY_TO_SHOW), object: nil)
            }
            
        })
        .onDisappear(perform: { //When the user leaves the control page, disconnect from the corresponding device
            deviceIsSetup = false
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
            if(thisDevice.name != "emptyDevice"){
                RunLoop.main.add(brightnessTimer, forMode: .common)
                RunLoop.main.add(brightnessToggleTimer, forMode: .common)
            }
        })
        .onReceive(brightnessChangeListener, perform: {_ in //When we get the signal that the brightness has changed, update it
            CheckSliderValues()
        })
        .onReceive(crossfadeChangeListener, perform: {_ in
            BLE.changeCrossfade(newCrossfade: crossfadeSliderValue)
        })
        .onReceive(disconnectListener, perform: {_ in //If we've disconnected, reset the deviceIsSetup flag and leave the control screen
            deviceIsSetup = false
            dismiss()
        })
        .onReceive(brightnessHRChangeListener, perform: {_ in 
            //Change brightness based on the current heartrate of the user
            HRBrightnessChange()
            
//            //For testing purposes so that there's a visible indicator on the hardware that the app hasn't fallen asleep
//            if(thisDevice.brightness > 10){
//                BLE.changeBrightness(newBrightness: 10)
//            } else {
//                BLE.changeBrightness(newBrightness: 127)
//            }
        })
        .onReceive(workoutListener, perform: {_ in
            //When we get the workout finished message, remove the workout control page from the screen
            workoutControlMode = false
        })
        .onReceive(loadingStringListener, perform: { _ in
            //Update loading string whenever we get a complete packet
            loadingString = thisDevice.loadingStatus
            //print("Updating loading string")
        })
        .toolbar((selectedTab == 1) ? .hidden : .visible) //Only let the user disconnect from the top page since it was confusing to have multiple back buttons on the brightness, crossfade, and continuous control pages
    }
}

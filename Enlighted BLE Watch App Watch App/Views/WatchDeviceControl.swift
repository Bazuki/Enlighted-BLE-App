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
import CoreMotion

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
    
    //Alternator boolean so that we only double-check the mode every other tick of the BLE timer
    @State var ModeCheckAlternator: Int = 0
    
    //Motion Manager object, which will give us accel/gyro data
    var motionManager: CMMotionManager
    
    //CoreMotion variables
        //Boolean to know when we need to start the accel updates
    @State var accelActive: Bool = false
    
    //Clap Detection variables
    @State var clapped: Bool = false
        //Interval before the clap sensing resets
    @State var clapReset = Constants.DEFAULT_CLAP_RESET_INTERVAL
        //Boolean to reduce false positives and false double claps
    @State var ignoreNext: Bool = false
        //Boolean to tell the tick timer to send a clap
    @State var sendClap: Bool = false
    
    //Arm Position Variables
    enum armPositionType {
        case up, sideways, down, unknown
    }
    @State var averageBuffer: [Double] = [Double]()
    @State var rollingAverage: Double = 0.0
    @State var bufferIndex: Int = 0
    @State var bufferSize: Int = 25
    @State var bufferCount: Int = 0
    @State var lastPosition: armPositionType = .unknown
    @State var maxMinusMin: Double = 0.0
    
        //Accel info page variables
    @State var currentXAccel: Double = 0.0
    @State var peakXAccel: Double = 0.0
    
    //Arm Swinging variables
    @State var swingThreshhold: Bool = false
    
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
        //Bool to ensure we don't keep adding timers
    @State var BLETickTimerActive: Bool = false
    
    //Brightness toggle timer ONLY FOR TESTING IF BLE CONNECTIONS CAN BE MADE AND MAINTAINED WHEN THE APP IS IN THE FOREGROUND BUT DIMMED
    let brightnessToggleTimer = Timer(timeInterval: 5, repeats: true){timer in
        NotificationCenter.default.post(name: Notification.Name(rawValue: "HRBrightness"), object: nil)
    }
    
    //Helper function for the next and previous buttons
    func newMode(next: Bool){
        //Set the mode change flag so that we can give ourself a window of time to clearly set the mode without overlapping commands - reset when we get the success response in BLE_Connection_Controller
        WatchDevice.connectedDevice?.aboutToChangeMode = true
        //Set the mode index depending on which button was pushed
        if(next){
            thisDevice.currentModeIndex += 1
            if(thisDevice.currentModeIndex > thisDevice.maxNumModes){
                thisDevice.currentModeIndex = 1
            }
        } else{
            thisDevice.currentModeIndex -= 1
            if(thisDevice.currentModeIndex < 1){
                thisDevice.currentModeIndex = thisDevice.maxNumModes
            }
        }
        //Send the mode request - moved to BLETick() - moved back to this function since we decided to stop constantly polling the hardware for its current mode
        BLE.setPrimaryMode(newModeIndex: thisDevice.currentModeIndex)
    }
    
    //Centralized BLE Tick function which deals with transmitting slider values as they're being slid, checking that the mode is correct, and making sure we have clap and realtime data
    func BLETick(){
        //print("Checking if we need to send brightness")
        if((Int(brightnessSliderValue) != WatchDevice.connectedDevice?.brightness) && !WatchDevice.connectedDevice!.requestWithoutResponse){ //Send a new brightness if it's different from what we have stored and if we aren't waiting for a response (so that we don't spam the fifo if it's caught up already)
            BLE.changeBrightness(newBrightness: brightnessSliderValue)
            
        } else if(!(WatchDevice.connectedDevice?.checkedLastBrightnessChange)!){ //this flag will be set by the callback when we receive a success response from the hardware.  If there's a failure, it will retry the request
                print("Double checking the brightness: \(thisDevice.brightness)")
                BLE.getPrimaryBrightness()
                WatchDevice.connectedDevice?.checkedLastBrightnessChange = true
            
        } else if ((Int(crossfadeSliderValue) != WatchDevice.connectedDevice?.crossfade) &&  !WatchDevice.connectedDevice!.requestWithoutResponse){ //Send a new crossfade value if it's different from what we have stored and we aren't waiting for a response
            BLE.changeCrossfade(newCrossfade: crossfadeSliderValue)
        }
            //NOTE: The below code was used for constantly checking the current mode so that we could poll the hardware and see what realtime and clap parameters the current mode is looking for.  However, we have decided that we will instead use set gesture and have the firmware react to those events.  See BLE Communication Paradigm for Gestural Control in the spec for further notes
//        } else if(WatchDevice.connectedDevice!.supportsGesturalControl && !WatchDevice.connectedDevice!.requestWithoutResponse && !WatchDevice.connectedDevice!.checkedClaps){
//                //If we need to get the clap parameter this tick, do that
//            BLE.getPrimaryClaps()
//            
//        } else if(WatchDevice.connectedDevice!.supportsGesturalControl && !WatchDevice.connectedDevice!.requestWithoutResponse && !WatchDevice.connectedDevice!.checkedRealtime){
//            //If we need to get the realtime parameter type this tick, do that
//            BLE.getPrimaryRealtime()
//            
//            //If the user just pressed the next/prev button, set the mode
//        } else if(WatchDevice.connectedDevice!.aboutToChangeMode && !WatchDevice.connectedDevice!.requestWithoutResponse){
//            BLE.setPrimaryMode(newModeIndex: thisDevice.currentModeIndex)
//            ModeCheckAlternator = 1
//            
//            //If we've detected the correct number of claps, send a clap flag
//        } else if (sendClap && !WatchDevice.connectedDevice!.requestWithoutResponse){
//            BLE.sendPrimaryClap(clapType: WatchDevice.connectedDevice!.claps)
//            sendClap = false
//            
//            //If we don't need to do anything else and we aren't currently changing the mode, let's just double check the current mode in case somebody changed it manually
//        } else if(!WatchDevice.connectedDevice!.aboutToChangeMode){
//            if(ModeCheckAlternator == 0 && !WatchDevice.connectedDevice!.requestWithoutResponse){
//                    //If we're on the correct tick and not waiting for another response, check the mode to make sure nobody has changed it manually
//                BLE.getPrimaryLimits()
//                //ModeCheckAlternator += 1
//            } else {
//                    //Only check the mode every two ticks (~0.66 second)
//                ModeCheckAlternator = ((ModeCheckAlternator + 1) % 2)
//                print(ModeCheckAlternator)
//            }
//        }
    }
    
    //Change brightness based on the heartrate - NOTE: as it stands starting in 0.0.6, this only will change the brightness based on HR if the user is currently in the workout status page for the sake of not constantly spamming the hardware when the user may want to change mode, brightness (purposely), etc
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
                                Text("\(loading || (thisDevice.modeNames.count < thisDevice.maxNumModes) ? "" : "\(String(thisDevice.currentModeIndex )): \(thisDevice.name == "emptyDevice" ? "Demo Mode": thisDevice.modeNames[thisDevice.currentModeIndex - 1])")") //modeNames is zero justified while currentModeIndex is not, so we need to subtract one from the index to get the correct modeName and not cause an index out of bounds
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
                                        DynamicSliderValueButtonLabelView(value: Binding.constant(0), title: "Workout Status", minValue: 0, maxValue: 1)
                                    }
                                } else if (brightnessControlMode){
                                    HStack{
                                        Button("Back"){
                                            withAnimation{
                                                brightnessControlMode = false
                                            }
                                        }
                                        BrightnessSlider(value: $brightnessSliderValue, active: $brightnessControlMode, orientation: true)
                                            .disabled(!brightnessControlMode)
                                    }
                                } else if (crossfadeControlMode){
                                    HStack{
                                        Button("Back"){
                                            withAnimation{
                                                crossfadeControlMode = false
                                            }
                                        }
                                        CrossfadeSlider(value: $crossfadeSliderValue, active: crossfadeControlMode, orientation: true)
                                            .disabled(!crossfadeControlMode)
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
                                //MARK: Accel data for testing purposes only
                            VStack{
                                Spacer()
                                Text("X: \(String(format: "%.2f", currentXAccel))")
                                    .font(.title2)
                                Text("Avg: \(String(format: "%.2f", rollingAverage))")
                                    .font(.title2)
                                Button{peakXAccel = 0.0} label: {Text("Peak: \(String(format: "%.2f", peakXAccel))")
                                    .font(.title2)}
                                Text("Pos: \(lastPosition)")
                                    .font(.title2)
                                Spacer()
                            }
                            .onChange(of: lastPosition) { oldValue, newValue in
                                    print("New Arm Position: \(newValue)")
                            }
                            .sensoryFeedback(.increase, trigger: lastPosition)
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
                }.navigationBarBackButtonHidden(true)
                .toolbar { //Custom back button so that we can stop the workout on disconnect
                    ToolbarItem(placement: .topBarLeading, content: {
                        Button{
                            if (workoutManager.running){
                                workoutManager.endWorkout()
                                workoutManager.showingSummaryView = false
                            }
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                    })
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
            loading = true
            motionManager.stopAccelerometerUpdates()
            brightnessTimer.invalidate()
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
        .onReceive(loadingListener, perform: {_ in //When we get the signal that loading is done, remove the progressView, start the brightness timer, start the workout, and setup CoreMotion
            loading = false
            brightnessSliderValue = Double(thisDevice.brightness)
            crossfadeSliderValue = Double(thisDevice.crossfade)
            if(thisDevice.name != "emptyDevice" && !BLETickTimerActive){
                print("starting BLE Tick timer")
                RunLoop.main.add(brightnessTimer, forMode: .common)
                BLETickTimerActive = true
                RunLoop.main.add(brightnessToggleTimer, forMode: .common)
            }
            
            //Start workout session
            workoutManager.requestAuth()
            print("checking if we need to start workout: \(!workoutManager.running)")
            if (!workoutManager.running){
                workoutManager.startWorkout(workoutType: .cardioDance)
            }
            
            //Initialize averageBuffer if we need to
            if (averageBuffer.count == 0){
                averageBuffer = [Double](repeating: 0.0, count: bufferSize)
            }
            
            //Setup coreMotion
                //only setup the accelerometer if it's not already active and if the current mode wants it
            print("Checking if we need to start clap detection: \(motionManager.isAccelerometerActive)")
            if(!motionManager.isAccelerometerActive && !accelActive && WatchDevice.connectedDevice!.supportsGesturalControl){
                if(motionManager.isAccelerometerAvailable
                ){
                    print("Starting accelerometer for clap detection with interval: \(motionManager.accelerometerUpdateInterval)")
                    accelActive = true
                    motionManager.startAccelerometerUpdates(to: .main) { (data, error) in
                        guard error == nil else { print("CoreMotion Error: \(String(describing: error))"); return }
                        guard let accelData = data else { print("Could not get accelData"); return }
                        
                        currentXAccel = accelData.acceleration.x
                        peakXAccel = max(abs(currentXAccel), abs(peakXAccel))
                        
                        //MARK: Arm Position Code
                            //Updating the rolling average
                        averageBuffer[bufferIndex] = accelData.acceleration.x
                        bufferIndex = (bufferIndex + 1) % bufferSize
                        if (bufferCount < bufferSize){
                            bufferCount += 1
                        }
                            //Updating the max minus min so that we can determine if this was a sudden increase in X from a potential arm swing
                        maxMinusMin = abs(averageBuffer.max()! - averageBuffer.min()!)
                            //Averaging the array
                        rollingAverage = averageBuffer.reduce(0.0, {x, y in
                                x + y
                        }) / Double(bufferCount)
                            //Sensing position
                        if(rollingAverage < 1.0 && rollingAverage > 0.75 && maxMinusMin < 0.5){
                            if(lastPosition != .up){
                                BLE.sendPrimaryGesture(gestureType: 3)
                            }
                            lastPosition = .up
                        } else if(rollingAverage < 0.4 && rollingAverage > -0.4 && maxMinusMin < 0.5){
                            if(lastPosition != .sideways){
                                BLE.sendPrimaryGesture(gestureType: 4)
                            }
                            lastPosition = .sideways
                        } else if(rollingAverage < -0.75 && rollingAverage > -1.0 && maxMinusMin < 0.5){
                            if(lastPosition != .down){
                                print("Detected down gesture - mmm: \(maxMinusMin)")
                                BLE.sendPrimaryGesture(gestureType: 5)
                            }
                            lastPosition = .down
                        }
                        
                        //MARK: Arm Swing Detection - removed on 8/12/24 so that we can release a version with 5/6 gestures supported to janet
//                        if(abs(accelData.acceleration.x) > 3.0 && (abs(accelData.acceleration.y) > 1.0 || abs(accelData.acceleration.z) > 1.0) && !swingThreshhold){ //In order for the swing to count as a swing, we want the x to be high due to centrifugal force, and one of the other axes to be relatively high as well
//                            print("Arm Swing Gesture detected - mmm: \(maxMinusMin)")
//                            BLE.sendPrimaryGesture(gestureType: 6)
//                            swingThreshhold = true
//                        } else if (abs(accelData.acceleration.x) < 0.5 && swingThreshhold){
//                            print("Arm Swing Gesture reset")
//                            swingThreshhold = false
//                        }
                        
                        //MARK: Clap Detection Code
                        if (accelData.acceleration.z < -5.0){
                            if (!clapped && !ignoreNext){
                                print("Detected single clap")
                                BLE.sendPrimaryGesture(gestureType: 1)
                                clapped = true
                                ignoreNext = true
                            } else if (!ignoreNext){
                                print("Detected double clap")
                                BLE.sendPrimaryGesture(gestureType: 2)
                                clapped = false
                                clapReset = Constants.DEFAULT_CLAP_RESET_INTERVAL
                                ignoreNext = true
                            } else {
                                print("ignoring false positive clap")
                                //ignoreNext = false
                            }
                        } else{
                            ignoreNext = false //Once the accel value has gone below the threshhold again, the next clap will be valid
                        }
                        
                        if (clapped && (clapReset >= 0.0)){
                            clapReset = clapReset - motionManager.accelerometerUpdateInterval
                        } else if (clapped){
                            clapped = false
                            clapReset = Constants.DEFAULT_CLAP_RESET_INTERVAL
                            print("reset clap")
                        }
                    }
                }
                
            }
            
        })
        .onReceive(brightnessChangeListener, perform: {_ in //When we get the signal that the brightness has changed, update it
            BLETick()
        })
        .onReceive(crossfadeChangeListener, perform: {_ in
            BLE.changeCrossfade(newCrossfade: crossfadeSliderValue)
        })
        .onReceive(disconnectListener, perform: {_ in //If we've disconnected, reset the deviceIsSetup flag and leave the control screen
            deviceIsSetup = false
            motionManager.stopAccelerometerUpdates()
            brightnessTimer.invalidate()
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

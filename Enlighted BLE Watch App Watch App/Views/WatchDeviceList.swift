//
//  WatchDeviceList.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/21/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI
import CoreMotion

struct WatchDeviceList: View {
    @EnvironmentObject var BLE: BLEConnectionController
    @EnvironmentObject var workoutManager: WorkoutManager
    @State var devicesToShow = [WatchDevice]()
    @State var showPopUp: Bool = false
    
        //Motion Manager object which will give us access to accel, gyro, magnetometer, etc.  We initialize this variable here because we don't want to create multiple instances of it when we disconnect and re-enter the control screen
    @State var motionManager = CMMotionManager()
    
    //Disconnect listener so that we can show a pop-up notifying the user when we disconnect
    let disconnectListener = NotificationCenter.default.publisher(for:  Notification.Name(rawValue: Constants.MESSAGES.DISCONNECTED_FROM_WATCH_DEVICE))
    
    var demoDevice: WatchDevice = WatchDevice(true)
    var body: some View {
            NavigationView{
                ScrollView{
                    ZStack{
                        VStack{
                            if(!showPopUp){
                                HStack{
                                    Text(BLE.isBluetoothEnabled ? "Available Devices: " : "Bluetooth is not available")
                                }
                                Divider()
                                // List of devices
                                VStack {
                                    if(!BLE.isBluetoothEnabled || BLE.canShowDemoDevice){ //If bluetooth is disabled or we want to show demo device, show demo device
                                        NavigationLink(destination: WatchDeviceControl(thisDevice: demoDevice, motionManager: motionManager), label: {WatchDeviceListRow(thisDevice: demoDevice)})
                                    }
                                    else if (BLE.isBluetoothEnabled){ //If we have bluetooth and aren't showing the demo device, we must have some devices to show
                                        ForEach(BLE.visibleDevices, id:\.self) { listDevice in
                                            NavigationLink(destination: WatchDeviceControl(thisDevice: listDevice, motionManager: motionManager), label: {WatchDeviceListRow(thisDevice: listDevice)}).onTapGesture {
                                                WatchDevice.setConnectedDevice(newDevice: listDevice)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                            else{
                                Spacer()
                                Text("Got Disconnected from Primary Device")
                                Button("Back to Device List"){
                                    withAnimation{
                                        showPopUp = false
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(disconnectListener, perform: {_ in
                showPopUp = true
                if (workoutManager.running){
                    workoutManager.endWorkout()
                    workoutManager.showingSummaryView = false
                }
            })
    }
}

#Preview {
    WatchDeviceList()
}

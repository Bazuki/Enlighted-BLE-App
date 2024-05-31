//
//  WatchDeviceList.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/21/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI

struct WatchDeviceList: View {
    @EnvironmentObject var BLE: BLEConnectionController
    @State var devicesToShow = [WatchDevice]()
    var demoDevice: WatchDevice = WatchDevice(true)
    var body: some View {
            NavigationView{
                ScrollView{
                    ZStack{
                        VStack{
                            HStack{
                                Text(BLE.isBluetoothEnabled ? "Available Devices: " : "Bluetooth is not available")
                            }
                            Divider()
                            // List of devices
                            VStack {
                                if(!BLE.isBluetoothEnabled || BLE.canShowDemoDevice){ //If bluetooth is disabled or we want to show demo device, show demo device
                                    NavigationLink(destination: WatchDeviceControl(thisDevice: demoDevice), label: {WatchDeviceListRow(thisDevice: demoDevice)})
                                }
                                else if (BLE.isBluetoothEnabled){ //If we have bluetooth and aren't showing the demo device, we must have some devices to show
                                    ForEach(BLE.visibleDevices, id:\.self) { listDevice in
                                        NavigationLink(destination: WatchDeviceControl(thisDevice: listDevice), label: {WatchDeviceListRow(thisDevice: listDevice)}).onTapGesture {
                                            WatchDevice.setConnectedDevice(newDevice: listDevice)
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    WatchDeviceList()
}

//
//  ContentView.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/17/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var BLE: BLEConnectionController
    var body: some View {
        VStack{
            WatchDeviceList()
        }
    }
}

#Preview {
    ContentView()
}

//
//  WatchDeviceListRow.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/21/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI

struct WatchDeviceListRow: View {
    var thisDevice: WatchDevice
    var body: some View {
        HStack{
            Text(thisDevice.name == "emptyDevice" ? "Demo Device" : thisDevice.name)
            Spacer()
            Image(systemName: "arrowshape.right")
        }.padding(.all)
    }
}

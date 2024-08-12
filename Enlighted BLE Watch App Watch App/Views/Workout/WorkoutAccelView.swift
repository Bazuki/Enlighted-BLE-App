//
//  WorkoutAccelView.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 8/7/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import SwiftUI

struct WorkoutAccelView: View {
    @State var currentXAccel: Double
    @State var peakXAccel: Double
    @State var rollingAverage: Double
    @State var lastPosition: String
    
    
    var body: some View {
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
    }
}

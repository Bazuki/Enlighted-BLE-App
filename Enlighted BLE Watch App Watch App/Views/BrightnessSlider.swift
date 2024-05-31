//
//  BrightnessSlider.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 5/24/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

//Credit for tutorial to: https://medium.com/@kusalprabathrajapaksha/bidirectional-custom-slider-in-swiftui-b5c92cadcba4

import SwiftUI

struct BrightnessSlider: View {
    @Binding var value: Double
    
    private let minValue: Double = 0
    private let maxValue: Double = 255
    private let thumbRadius: CGFloat = 8
    private let sliderHeight: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                //Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(1))
                    .frame(width: geometry.size.width, height: sliderHeight)
                HStack{
                    ZStack{
                        let currentRatio = CGFloat(value/(maxValue - minValue))
                        let tintWidth = geometry.size.width * currentRatio
                        
                        //Tint
                        Rectangle()
                            .fill(Color(white: currentRatio))
                            .frame(width: abs(tintWidth), height: sliderHeight)
                        
                    }
                    Spacer()
                }
                HStack{
                    //Sliding piece
                    Circle()
                        .fill(Color.black)
                        .fill(Color.white.opacity(value/(maxValue - minValue)))
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: thumbRadius * 2)
                        .offset(x: CGFloat((value)/(maxValue - minValue)) * geometry.size.width - thumbRadius)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged({gesture in
                                    updateValue(with: gesture, in: geometry)
                                    
                                })
                                .onEnded({gesture in // Credit to: https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures
                                    updateValue(with: gesture, in: geometry)
                                    print("Ended Dragging")
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS), object: nil)
                                })
                        )
                    Spacer()
                }
                
                            
            }
        }
        .frame(height: 100)
        .padding()
    }
    
    //Update the binded value when the slider is dragged
    private func updateValue(with gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let dragPortion = gesture.location.x / geometry.size.width
        let newValue = Double((maxValue - minValue) * dragPortion)
        value = min(max(newValue, minValue), maxValue)
    }
        
}


#Preview {
    BrightnessSlider(value: Binding.constant(CGFloat(50)))
}

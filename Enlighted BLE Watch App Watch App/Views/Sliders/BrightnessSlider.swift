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
    //Actual slider value
    @Binding var value: Double
    
    //Whether or not this slider is currently active on the screen
    @Binding var active: Bool
    
    //Whether the slider is vertical or horizontal - true = vertical, false = horizontal
    @State var orientation: Bool
    
    //Limits for parameters
    private let minValue: Double = 0
    private let maxValue: Double = 255
    private let thumbRadius: CGFloat = 8
    private let sliderHeight: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            if(!orientation){ //Horizontal Slider
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
                            .onChange(of: value) { oldValue, newValue in
                                value = min(max(newValue, minValue), maxValue)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged({gesture in
                                        updateValue(with: gesture, in: geometry)
                                        
                                    })
                                    .onEnded({gesture in // Credit to: https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures
                                        updateValue(with: gesture, in: geometry)
                                        print("Ended Dragging")
                                        //                                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS), object: nil)
                                    })
                            )
                        Spacer()
                    }
                    
                    
                }
            } else{ //Vertical Slider
                ZStack{
                    //Track
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(1))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    VStack{
                        Spacer()
                        ZStack{
                            let currentRatio = CGFloat(value/(maxValue - minValue))
                            let tintHeight = geometry.size.height * currentRatio
                            
                            //Tint
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(white: currentRatio))
                                .frame(width: geometry.size.width, height: abs(tintHeight))
                            
                        }
                    }
                    VStack{
                        //Sliding piece
                        RoundedRectangle(cornerRadius: thumbRadius)
                            .fill(Color.black)
                            .fill(Color.white.opacity(value/(maxValue - minValue)))
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: geometry.size.width, height: thumbRadius * 2)
                            .offset(y: CGFloat((maxValue - value)/(maxValue - minValue)) * geometry.size.height - thumbRadius)
                            .onChange(of: value) { oldValue, newValue in
                                value = min(max(newValue, minValue), maxValue)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged({gesture in
                                        updateValue(with: gesture, in: geometry)
                                        
                                    })
                                    .onEnded({gesture in // Credit to: https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures
                                        updateValue(with: gesture, in: geometry)
                                        print("Ended Dragging")
                                        //                                    NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.MESSAGES.CHANGE_BRIGHTNESS), object: nil)
                                    })
                            )
                        Spacer()
                    }
                    
                    
                }
            }
        }
        .frame(height: orientation ? 150 : 100)
        .padding()
        .focusable(active) //Credit to: https://www.hackingwithswift.com/quick-start/swiftui/how-to-read-the-digital-crown-on-watchos-using-digitalcrownrotation
        .disabled(!active)
        .digitalCrownRotation($value, from: minValue , through: maxValue, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true )
        .scrollIndicators(.hidden)
    }
    
    //Update the binded value when the slider is dragged
    private func updateValue(with gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let dragPortion = self.orientation ? (geometry.size.height - gesture.location.y) / geometry.size.height : gesture.location.x / geometry.size.width
        let newValue = ((Double(maxValue) - Double(minValue)) * dragPortion)
        value = min(max(newValue, minValue), maxValue).rounded(.toNearestOrAwayFromZero)
    }
        
}


#Preview {
    BrightnessSlider(value: Binding.constant(200), active: Binding.constant(true), orientation: true)
}

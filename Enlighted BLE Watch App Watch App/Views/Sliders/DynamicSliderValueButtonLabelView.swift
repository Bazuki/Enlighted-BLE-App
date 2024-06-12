//
//  DynamicSliderValueButton.swift
//  Enlighted BLE Watch App
//
//  Created by Dylan Suzuki on 6/11/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

//Custom button label that displays the slider value for the associated slider

import SwiftUI

struct DynamicSliderValueButtonLabelView: View {
    
    @Binding var value: Double
    
    var title: String
    
    var minValue: Double
    var maxValue: Double
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{ //Main ZStack
                RoundedRectangle(cornerRadius: 25) //Background
                    .fill(Color.black.opacity(1))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                HStack{ //Tint
                    ZStack{
                        let currentRatio = CGFloat(value/(maxValue - minValue))
                        let tintWidth = geometry.size.width * currentRatio
                        
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(white: currentRatio))
                            .frame(width: abs(tintWidth), height: geometry.size.height)
                    }
                    Spacer()
                }
                HStack{ //Centered Title
                    Spacer()
                    Text(title)
                        .foregroundStyle((value <= maxValue/2) ? .white : .black)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    DynamicSliderValueButtonLabelView(value: Binding.constant(127), title: "Brightness", minValue: 0, maxValue: 255)
}

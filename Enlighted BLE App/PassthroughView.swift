//
//  PassthroughView.swift
//  Enlighted BLE App
//
//  Created by Dylan Suzuki on 12/22/23.
//  Copyright © 2023 Bryce Suzuki. All rights reserved.
//

import Foundation
import UIKit

class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

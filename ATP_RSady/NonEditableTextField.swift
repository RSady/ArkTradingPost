//
//  NonEditableTextField.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 4/23/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation
import UIKit
import SkyFloatingLabelTextField

class NonEditableTextField: SkyFloatingLabelTextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        self.resignFirstResponder()
        return false
    }
    
    override func shouldChangeText(in range: UITextRange, replacementText text: String) -> Bool {
        self.resignFirstResponder()
        return false
    }
    
    
}


class NonEditableTextFieldWithIcon: SkyFloatingLabelTextFieldWithIcon {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        self.resignFirstResponder()
        return false
    }
    
    override func shouldChangeText(in range: UITextRange, replacementText text: String) -> Bool {
        self.resignFirstResponder()
        return false
    }
    
    
}

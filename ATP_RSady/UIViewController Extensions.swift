//
//  UIViewController Extensions.swift
//  ArkTradingPost
//
//  Created by Ryan Sady on 3/2/19.
//  Copyright © 2019 Ryan Sady. All rights reserved.
//

import Foundation
import UIKit
import SideMenu

extension UIViewController {
    
    func showError(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func showMenu() {
        DispatchQueue.main.async {
            self.present(SideMenuManager.default.menuLeftNavigationController!, animated: true, completion: nil)
        }
        
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func createToolBar(buttonTitle: String, labelTitle: String) -> UIToolbar {
        // Create Toolbar Items
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 40))
        toolbar.barStyle = UIBarStyle.default
        toolbar.tintColor = UIColor.black
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(donePressed(sender:)))
        doneButton.title = buttonTitle
        let flexButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width/3, height: 40))
        label.textColor = UIColor.black
        label.font = UIFont.systemFont(ofSize: 17)
        label.textAlignment = NSTextAlignment.center
        label.text = labelTitle
        let labelButton = UIBarButtonItem(customView: label)
        toolbar.setItems([flexButton, flexButton, labelButton, flexButton, doneButton], animated: true)
        return toolbar
    }
    
    @objc fileprivate func donePressed (sender: UIBarButtonItem) {
        view.endEditing(true)
    }
}

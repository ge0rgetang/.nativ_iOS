//
//  ForgotPasswordPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAuth
import CryptoSwift

class ForgotPasswordPopViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Outlets/Variables
    
    let misc = Misc()
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.confirmButton.isEnabled = false
        self.dismissKeyboard()
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
        self.sendPassReset()
    }
    @IBAction func confirmButtonDown(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "down", view: self.view)
    }
 
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.emailTextField.delegate = self
        self.preferredContentSize = CGSize(width: 320, height: 100)
        self.messageLabel.sizeToFit()
        self.makeButtonFancy(self.confirmButton, title: "Confirm")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let messageLabelHeight = self.messageLabel.bounds.height
        let emailFieldHeight = self.emailTextField.bounds.height
        let confirmButtonHeight = self.confirmButton.frame.height
        let preferredHeight = messageLabelHeight + emailFieldHeight + confirmButtonHeight
        self.preferredContentSize = CGSize(width: 320, height: preferredHeight + 32)
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - TextField
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 191
    }
    
    // MARK: - Misc
    
    func sendPassReset() {
        if let email = self.emailTextField.text {
            FIRAuth.auth()?.sendPasswordReset(withEmail: email, completion: { (error) in
                DispatchQueue.main.async(execute: {
                    if error != nil {
                        if let errorString = error?.localizedDescription {
                            self.displayAlert("Oops", alertMessage: errorString)
                            return
                        } else {
                            self.displayAlert("Oops", alertMessage: "An error occured. Please try again later. If the problem persists, email us at dotnative@gmail.com")
                            return
                        }
                    } else {
                        let alertController = UIAlertController(title: "Email Sent!", message: "Please check your email to reset your password.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                            self.dismiss(animated: true, completion: nil)
                            self.confirmButton.isEnabled = true
                        }
                        alertController.addAction(okAction)
                        alertController.view.tintColor = self.misc.nativColor
                        self.present(alertController, animated: true, completion: nil)
                    }
                })
            })
        } else {
            self.displayAlert("No Email", alertMessage: "Please enter in your email")
            return
        }
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.confirmButton.isEnabled = true
        })
    }
    
    func makeButtonFancy(_ button: UIButton, title: String) {
        let attributedTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.white])
        let defaultTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: misc.nativColor])
        button.backgroundColor = .white
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = misc.nativColor.cgColor
        button.setAttributedTitle(attributedTitle, for: .highlighted)
        button.setAttributedTitle(attributedTitle, for: .selected)
        button.setAttributedTitle(attributedTitle, for: .focused)
        button.setAttributedTitle(defaultTitle, for: .normal)
    }
    
}

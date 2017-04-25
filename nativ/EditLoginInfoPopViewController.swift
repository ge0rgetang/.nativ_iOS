//
//  EditLoginInfoPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics
import FirebaseAuth
import CryptoSwift

class EditLoginInfoPopViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var phoneText: String = "No phone number set"
    var birthdayText: String = "no birthday set"
    var handleText: String = "handle"
    var nameText: String = "name"
    var descriptionText: String = "no description set"
    var emailText: String = "email"
    
    
    var isFIRSucess: Bool = true
    let misc = Misc()
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var loginLabel: UILabel!
    @IBOutlet weak var currentEmailTextField: UITextField!
    @IBOutlet weak var currentPasswordTextField: UITextField!
    @IBOutlet weak var loginInfoLabel: UILabel!
    @IBOutlet weak var newEmailTextField: UITextField!
    @IBOutlet weak var newPasswordTextField: UITextField!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.confirmButton.isEnabled = false
        self.authenticate()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.currentEmailTextField.text = emailText
        
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        self.view.backgroundColor = .white
        
        self.currentEmailTextField.delegate = self
        self.currentEmailTextField.tag = 0
        self.currentPasswordTextField.delegate = self
        self.currentPasswordTextField.tag = 1
        self.newEmailTextField.delegate = self
        self.newEmailTextField.tag = 2
        self.newPasswordTextField.delegate = self
        self.newPasswordTextField.tag = 3
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.confirmButton.isEnabled = true
        self.isFIRSucess = true
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.emailText == "email" {
            let alertController = UIAlertController(title: "Oops", message: "We messed up and can't change info at this time. Please report this bug if it persists", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                self.dismiss(animated: true, completion: nil)
            }
            alertController.view.tintColor = self.misc.nativColor
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        } else {
            self.logViewEditLoginInfo()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let loginLabelHeight = self.loginLabel.frame.size.height
        let emailHeight = self.currentEmailTextField.frame.size.height
        let passHeight = self.currentPasswordTextField.frame.size.height
        
        let infoHeight = self.loginInfoLabel.frame.size.height
        let newEmailHeight = self.newEmailTextField.frame.size.height
        let newPassHeight = self.newPasswordTextField.frame.size.height
        
        let confirmButtonHeight = self.confirmButton.frame.size.height
        
        let preferredHeight = loginLabelHeight + emailHeight + passHeight + infoHeight + newEmailHeight + newPassHeight + confirmButtonHeight + 64
        self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "makeWhiteViewsWhite"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 191
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.dismissKeyboard()
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.confirmButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Analytics
    
    func logViewEditLoginInfo() {
        FIRAnalytics.logEvent(withName: "viewEditLoginInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logEditedLoginInfo() {
        FIRAnalytics.logEvent(withName: "editedLoginInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func updateLoginInfo(_ userEmail: String) {
        let ref = self.ref.child("users").child(self.myIDFIR)
        ref.child("userEmail").setValue(userEmail)
    }
    
    func authenticate() {
        let emailText: String! = self.currentEmailTextField.text?.trimSpace()
        let passText: String! = self.currentPasswordTextField.text
        
        if emailText.isEmpty || passText.isEmpty {
            self.displayAlert("Current Login Info Empty", alertMessage: "Please fill in your current email and password.")
            return
            
        } else {
            let credential = FIREmailPasswordAuthProvider.credential(withEmail: emailText!, password: passText!)
            let user = FIRAuth.auth()?.currentUser
            user?.reauthenticate(with: credential) { error in
                if error != nil {
                    self.displayAlert("Oops", alertMessage: "Please check to see your email and password are valid.")
                    return
                } else {
                    self.editLoginInfo()
                }
            }
        }
    }
    
    func updatePassword(_ newPassword: String) {
        let user = FIRAuth.auth()?.currentUser
        user?.updatePassword(newPassword) { error in
            if error != nil {
                self.isFIRSucess = false
                print(error ?? "error")
                self.displayAlert("Oops", alertMessage: "Please go back and reauthenticate")
                return
            } else {
                print("password updated")
            }
        }
    }
    
    func updateEmail(_ newEmail: String) {
        let user = FIRAuth.auth()?.currentUser
        user?.updateEmail(newEmail) { error in
            if error != nil {
                self.isFIRSucess = false
                print(error ?? "error")
                self.displayAlert("Oops", alertMessage: "Please go back and reauthenticate")
                return
            } else {
                print("email updated")
            }
        }
    }
    
    // MARK: - AWS
    
    func editLoginInfo() {
        self.dismissKeyboard()
        
        let action: String = "edit"
        let isPicSet: String = "blank"
        
        let currentEmail: String! = self.currentEmailTextField.text?.trimSpace()
        let currentPassword: String! = self.currentPasswordTextField.text
        let newEmail: String! = self.newEmailTextField.text?.trimSpace()
        let newPassword: String! = self.newPasswordTextField.text
        
        if currentEmail.isEmpty || currentPassword.isEmpty {
            self.displayAlert("Current Login Info Empty", alertMessage: "Please fill in your current email and password.")
            return
        }
        
        var email: String
        if newEmail.isEmpty {
            email = currentEmail
        } else {
            email = newEmail
        }
        
        if !newPassword.isEmpty && newPassword.characters.count < 6 {
            self.displayAlert("Password Too Short", alertMessage: "Your pass needs to be at least 6 characters.")
            return
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/updateMyProfile")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&action=\(action)&myID=\(self.myID)&isPicSet=\(isPicSet)&myName=\(self.nameText)&myHandle=\(self.handleText)&myDescription=\(self.descriptionText)&myEmail=\(email)&myBirthday=\(self.birthdayText)&myPhoneNumber=\(self.phoneText)"
            sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert(":(", alertMessage: "Sorry, no internet. Your info has not been changed. Please try again later.")
                    return
                }
                
                do{
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")

                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your changes may not have been made. Please report the bug in your profile if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                if !newPassword.isEmpty {
                                    self.updatePassword(newPassword!)
                                }
                                
                                if !newEmail.isEmpty {
                                    self.updateEmail(newEmail!)
                                }
                                
                                if self.isFIRSucess {
                                    self.logEditedLoginInfo()
                                    self.updateLoginInfo(email)
                                    
                                    let alertController = UIAlertController(title: "Yay!", message: "Login info successfully changed :)", preferredStyle: .alert)
                                    let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                                        self.confirmButton.isEnabled = true
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "addFirebaseObservers"), object: nil)
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "makeWhiteViewsWhite"), object: nil)
                                        self.dismiss(animated: true, completion: nil)
                                    }
                                    alertController.view.tintColor = self.misc.nativColor
                                    alertController.addAction(okAction)
                                    self.present(alertController, animated: true, completion: nil)
                                    
                                } else {
                                    self.rollBack()
                                }
                            }
                            
                        })
                    }
                    
                } catch {
                    self.displayAlert("Oops", alertMessage: "We're updating our servers right now. Please try again later.")
                    print(error)
                    return
                }
                
            }
            
            task.resume()
            
        } catch {
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug using the report bug button in your profile if this persists.")
            return
        }
        
    }
    
    func rollBack() {
        let isPicSet: String = "blank"
        let action: String = "edit"
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/updateMyProfile")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&action=\(action)&myID=\(self.myID)&isPicSet=\(isPicSet)&myName=\(self.nameText)&myHandle=\(self.handleText)&myDescription=\(self.descriptionText)&myEmail=\(self.emailText)&myBirthday=\(self.birthdayText)&myPhoneNumber=\(self.phoneText)"
            sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert("waht. How did that happen?", alertMessage: "We think your internet connection dropped mid change. That's super rare. Guess you're one in a million ;) (sorry that was cheesy). If you encounter any abnormalities in your info, try to edit again later. If you can't login, please contact us at dotnative@gmail.com")
                    return
                }
                
                do{
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")

                        DispatchQueue.main.async(execute: {
                            self.updateLoginInfo(self.emailText)
                            
                            if status == "error" {
                                let alertController = UIAlertController(title: "Oops", message: "We messed up big time. Please send us an email at dotnative@gmail.com titled \"Profile Update Error\" with your last known login info (email and pass) in the body. Sorry for the trouble.", preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                                    self.dismiss(animated: true, completion: nil)
                                }
                                alertController.view.tintColor = self.misc.nativColor
                                alertController.addAction(okAction)
                                self.present(alertController, animated: true, completion: nil)
                            }
                            
                            if status == "success" {
                                let alertController = UIAlertController(title: "Oops", message: "We broke something. Please try to update your profile at a later time. Please report this bug if it continues.", preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                                    self.confirmButton.isEnabled = true
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "getMyProfile"), object: nil)
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "makeWhiteViewsWhite"), object: nil)
                                    self.dismiss(animated: true, completion: nil)
                                }
                                alertController.view.tintColor = self.misc.nativColor
                                alertController.addAction(okAction)
                                self.present(alertController, animated: true, completion: nil)
                            }
                            
                        })
                    }
                    
                } catch {
                    self.displayAlert("Oops", alertMessage: "We're updating our servers right now. Please try again later.")
                    print(error)
                    return
                }
                
            }
            
            task.resume()
            
        } catch {
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug using the report bug button in your profile if this persists.")
            return
        }
    }
    
}

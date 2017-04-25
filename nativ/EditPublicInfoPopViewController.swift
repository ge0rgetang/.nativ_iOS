//
//  EditPublicInfoPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics
import CryptoSwift

class EditPublicInfoPopViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var handleText: String = "handle"
    var nameText: String = "name"
    var descriptionText: String = "no description set"
    var handleExists: String = "error"
    
    var emailText: String = "email"
    var phoneText: String = "No phone number set"
    var birthdayText: String = "no birthday set"
    
    let misc = Misc()
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var publicInfoLabel: UILabel!
    @IBOutlet weak var checkHandleLabel: UILabel!
    @IBOutlet weak var handleTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var characterCountLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.confirmButton.isEnabled = false
        self.editPublicInfo()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        self.view.backgroundColor = .white
        
        self.nameTextField.text = self.nameText
        self.handleTextField.text = self.handleText
        self.descriptionTextView.text = self.descriptionText
        
        self.handleTextField.delegate = self
        self.handleTextField.tag = 0
        self.nameTextField.delegate = self
        self.nameTextField.tag = 1
        
        self.descriptionTextView.delegate = self
        self.characterCountLabel.isHidden = true
        
        self.descriptionTextView.layer.cornerRadius = 5
        self.descriptionTextView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        self.descriptionTextView.layer.borderWidth = 0.5
        self.descriptionTextView.clipsToBounds = true
        self.descriptionTextView.autocorrectionType = .default
        self.descriptionTextView.spellCheckingType = .default
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.confirmButton.isEnabled = true
        
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
            self.logViewEditPublicInfo()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if var myHandle = self.handleTextField.text {
            let firstCharacter = myHandle[myHandle.startIndex]
            if firstCharacter == "@" {
                myHandle.remove(at: myHandle.startIndex)
            }
        }
        
        let pubInfoHeight = self.publicInfoLabel.frame.size.height
        let handleLabelHeight = self.checkHandleLabel.frame.size.height
        let handleHeight = self.handleTextField.frame.size.height
        let nameHeight = self.nameTextField.frame.size.height
        let descriptionHeight = self.descriptionTextView.frame.size.height
        let confirmButtonHeight = self.confirmButton.frame.size.height
        let preferredHeight = pubInfoHeight + handleLabelHeight + handleHeight + nameHeight + descriptionHeight + confirmButtonHeight + 54
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
        if textField.tag == 0 {
            guard let text = textField.text else { return true }
            let length = text.characters.count + string.characters.count - range.length
            return length <= 50
        }
        
        if textField.tag == 1 {
            guard let text = textField.text else { return true }
            let length = text.characters.count + string.characters.count - range.length
            return length <= 15
        }
        
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 191
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.dismissKeyboard()
        
        if textField.tag == 0 {
            if textField.text != "" {
                if textField.text!.trimSpace() != self.handleText {
                    self.checkHandle(textField.text!.trimSpace(), type: "user")
                }
            } else {
                self.checkHandleLabel.text = ""
                self.checkHandleLabel.textColor = .lightGray
            }
        }
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text.lowercased() == "no description set" {
            textView.text = ""
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.resizeView()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        
        let currentLength = textView.text.characters.count + (text.characters.count - range.length)
        var charactersLeft = 191 - currentLength
        if charactersLeft < 0 {
            charactersLeft = 0
        }
        
        if currentLength >= 149 {
            self.characterCountLabel.isHidden = false
            self.characterCountLabel.text = "\(charactersLeft)"
            self.characterCountLabel.textColor = UIColor.lightGray
        } else {
            self.characterCountLabel.isHidden = true
        }
        
        return currentLength <= 191
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "No description set"
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    // - MARK: Misc
    
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
    
    func resizeView() {
        let maxHeight: CGFloat = UIScreen.main.bounds.size.height
        let fixedWidth: CGFloat = self.descriptionTextView.frame.size.width
        let newSize = self.descriptionTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT)))
        var newFrame = self.descriptionTextView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: min(newSize.height, maxHeight))
        self.descriptionTextView.frame = newFrame
        
        let pubInfoHeight = self.publicInfoLabel.frame.size.height
        let handleLabelHeight = self.checkHandleLabel.frame.size.height
        let handleHeight = self.handleTextField.frame.size.height
        let nameHeight = self.nameTextField.frame.size.height
        let descriptionHeight = self.descriptionTextView.frame.size.height
        let confirmButtonHeight = self.confirmButton.frame.size.height
        let preferredHeight = pubInfoHeight + handleLabelHeight + handleHeight + nameHeight + descriptionHeight + confirmButtonHeight + 48
        
        UIView.animate(withDuration: 0.1, animations: {
            self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
            self.view.layoutIfNeeded()
        })
    }
    
    func setHandleLabel() {
        DispatchQueue.main.async(execute: {
            if self.handleText.lowercased() == self.handleTextField.text?.lowercased() {
                self.checkHandleLabel.text = "This is your current handle."
                self.checkHandleLabel.textColor = .lightGray
            } else {
                switch self.handleExists {
                case "no":
                    let spec = self.misc.getSpecialHandles()
                    if let handle = self.handleTextField.text?.trimSpace().lowercased() {
                        if spec.contains(handle) {
                            self.checkHandleLabel.text = "Sorry, this handle is unavailable."
                            self.checkHandleLabel.textColor = .red
                        } else {
                            self.checkHandleLabel.text = "This handle is available!"
                            self.checkHandleLabel.textColor = self.misc.nativColor
                        }
                    }
                case "yes":
                    self.checkHandleLabel.text = "Sorry, this handle is unavailable."
                    self.checkHandleLabel.textColor = .red
                case "server":
                    self.checkHandleLabel.text = "We're updating our servers right now. Please try again later."
                    self.checkHandleLabel.textColor = .lightGray
                case "special":
                    self.checkHandleLabel.text = "Only a-z, A-Z, and 0-9 are allowed."
                    self.checkHandleLabel.textColor = .red
                case "internet":
                    self.checkHandleLabel.text = "No internet. Please try again once you have connected to the web."
                    self.checkHandleLabel.textColor = .lightGray
                default:
                    self.checkHandleLabel.text = "An error occured. Please try again later"
                    self.checkHandleLabel.textColor = .red
                }
            }
        })
    }
    
    // MARK: - Analytics
    
    func logViewEditPublicInfo() {
        FIRAnalytics.logEvent(withName: "viewEditPublicInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logEditedPublicInfo() {
        FIRAnalytics.logEvent(withName: "editedPublicInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func updatePublicInfo(_ userName: String, userHandle: String, userDescription: String) {
        let ref = self.ref.child("users").child(self.myIDFIR)
        ref.child("userName").setValue(userName)
        ref.child("userHandle").setValue(userHandle)
        ref.child("userDescription").setValue(userDescription)
    }
    
    // MARK: - AWS
    
    func editPublicInfo() {
        self.dismissKeyboard()
        
        let action: String = "edit"
        let isPicSet: String = "blank"
        
        let myName: String! = self.nameTextField.text?.trimSpace()
        let myHandle: String! = self.handleTextField.text?.trimSpace()
        var myDescription: String! = self.descriptionTextView.text.trimSpace()
        
        
        if myName.isEmpty || myHandle.isEmpty {
            self.displayAlert("Incomplete Info", alertMessage: "Please fill the required empty fields.")
            return
        }
        
        if myDescription.isEmpty {
            myDescription = "No description set"
        }
        
        let hasSpecialChars = misc.checkSpecialCharacters(myHandle)
        if hasSpecialChars {
            self.displayAlert("Special Characters", alertMessage: "Please remove any special characters from your handle. Only a-z, A-Z, and 0-9 are allowed.")
            return
        }
        
        let spaceCharacter = CharacterSet.whitespaces
        if myHandle.rangeOfCharacter(from: spaceCharacter) != nil {
            self.displayAlert("Space Found", alertMessage: "Please remove any spaces or special characters in your handle")
            return
        }
        
        let handeLower = myHandle.lowercased()
        let spec = misc.getSpecialHandles()
        if spec.contains(handeLower) && !spec.contains(self.handleText.lowercased()) {
            self.displayAlert(":)", alertMessage: "Sorry, this handle is taken by one of our resident skinny dippers. Please choose another.")
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
            
            let sendString = "iv=\(iv)&token=\(cipherText)&action=\(action)&myID=\(self.myID)&isPicSet=\(isPicSet)&myName=\(myName!)&myHandle=\(myHandle!)&myDescription=\(myDescription!)&myEmail=\(self.emailText)&myBirthday=\(self.birthdayText)&myPhoneNumber=\(self.phoneText)"
            
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
                                self.logEditedPublicInfo()
                                self.updatePublicInfo(myName!, userHandle: myHandle!, userDescription: myDescription!)
                                let myNameTrunc = self.misc.truncateName(myName!)
                                UserDefaults.standard.set(myNameTrunc, forKey: "myName.nativ")
                                UserDefaults.standard.set(myName, forKey: "myFullName.nativ")
                                UserDefaults.standard.set(myHandle, forKey: "myHandle.nativ")
                                UserDefaults.standard.synchronize()
                                
                                let alertController = UIAlertController(title: "Yay!", message: "Public info successfully changed :)", preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Ok", style: .default) { action in
                                    self.confirmButton.isEnabled = true
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "addFirebaseObservers"), object: nil)
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
    
    func checkHandle(_ handle: String, type: String) {
        let hasSpecialChars = misc.checkSpecialCharacters(handle.trimSpace().lowercased())
        if hasSpecialChars {
            self.handleExists = "special"
            self.setHandleLabel()
            return
        }
        
        if handle.lowercased() == self.handleText.lowercased() {
            self.setHandleLabel()
            return
        }
        
        let actionURL = URL(string: "https://dotnative.io/handleCheck")
        var actionRequest = URLRequest(url: actionURL!)
        actionRequest.httpMethod = "POST"
        
        let actionString = "handle=\(handle)&handleType=\(type)"
        
        actionRequest.httpBody = actionString.data(using: String.Encoding.utf8)
        
        let task = URLSession.shared.dataTask(with: actionRequest as URLRequest) {
            (data, response, error) in
            
            if error != nil {
                print(error ?? "error")
                self.handleExists = "internet"
                self.setHandleLabel()
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                
                if let parseJSON = json {
                    let status: String = parseJSON["status"] as! String
                    
                    DispatchQueue.main.async(execute: {
                        
                        if status == "error" {
                            self.handleExists = "error"
                            self.setHandleLabel()
                        }
                        
                        if status == "success" {
                            self.handleExists = parseJSON["handleExists"] as! String
                            self.setHandleLabel()
                        }
                        
                    })
                }
                
            } catch {
                print(error)
                self.handleExists = "server"
                self.setHandleLabel()
            }
            
        }
        
        task.resume()
    }
    
}

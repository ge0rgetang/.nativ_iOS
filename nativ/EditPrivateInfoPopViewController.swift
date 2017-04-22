//
//  EditPrivateInfoPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAnalytics
import CryptoSwift

class EditPrivateInfoPopViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var phoneText: String = "No phone number set"
    var birthdayText: String = "no birthday set"
    
    var handleText: String = "handle"
    var nameText: String = "name"
    var descriptionText: String = "no description set"
    var emailText: String = "email"
    var textFieldTag: Int = 0
    
    let misc = Misc()
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var privateInfoLabel: UILabel!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var birthdayTextField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        self.confirmButton.isEnabled = false
        self.editPrivateInfo()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        self.view.backgroundColor = .white
        
        self.phoneTextField.text = self.phoneText
        self.birthdayTextField.text = self.birthdayText
        
        self.phoneTextField.delegate = self
        self.phoneTextField.tag = 0
        self.birthdayTextField.delegate = self
        self.birthdayTextField.tag = 1
        
        let toolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        toolbar.sizeToFit()
        
        toolbar.tintColor = misc.nativColor
        let done = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.dismissKeyboard))
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelToolbar))
        
        toolbar.setItems([cancel, space, done], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        let datePickerView = UIDatePicker()
        datePickerView.datePickerMode = .date
        self.birthdayTextField.inputView = datePickerView
        self.birthdayTextField.inputAccessoryView = toolbar
        self.birthdayTextField.delegate = self
        datePickerView.addTarget(self, action: #selector(self.dateValueDidChange), for: .valueChanged)
        
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
            self.logViewEditPrivateInfo()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let privateLabelHeight = self.privateInfoLabel.frame.size.height
        let phoneHeight = self.phoneTextField.frame.size.height
        let birthdayHeight = self.birthdayTextField.frame.size.height
        let confirmButtonHeight = self.confirmButton.frame.size.height
        let preferredHeight = privateLabelHeight + phoneHeight + birthdayHeight + confirmButtonHeight + 48
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldTag = textField.tag
    }
    
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
        
        if textField.text == "" {
            self.cancelToolbar()
        }
    }
    
    // MARK: - DatePicker
    
    func dateValueDidChange(_ sender: UIDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        
        self.birthdayTextField.text = dateFormatter.string(from: sender.date)
    }
    
    func cancelToolbar() {
        switch self.textFieldTag {
        case 0:
            self.phoneTextField.text = self.phoneText
        case 1:
            self.birthdayTextField.text = self.birthdayText
        default:
            return
        }
        
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
    
    func logViewEditPrivateInfo() {
        FIRAnalytics.logEvent(withName: "viewEditPrivateInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logEditedPrivateInfo() {
        FIRAnalytics.logEvent(withName: "editedPrivateInfo", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    fileprivate func updatePrivateInfo(_ userPhone: String, userBirthday: String) {
        let ref = self.ref.child("users").child(self.myIDFIR)
        ref.child("userPhoneNumber").setValue(userPhone)
        ref.child("userBirthday").setValue(userBirthday)
    }
    
    // MARK: - AWS
    
    func editPrivateInfo() {
        self.dismissKeyboard()
        
        let action: String = "edit"
        let isPicSet: String = "blank"
        
        var myBirthday: String! = self.birthdayTextField.text
        var myPhoneNumber: String! = self.phoneTextField.text
        
        let seventhIndex = myBirthday.index(myBirthday.startIndex, offsetBy: 6)
        let seventhCharacter = myBirthday[seventhIndex]
        let characterCount = myBirthday.characters.count
        if myBirthday != "no birthday set" {
            if seventhCharacter != "," || characterCount != 12 {
                self.displayAlert("Bday Format", alertMessage: "Please format your bday as: MMM dd, yyyy")
                return
            }
        }
        
        if myBirthday.isEmpty {
            myBirthday = "no birthday set"
        } else {
            UserDefaults.standard.set(myBirthday, forKey: "myBirthday.nativ")
            UserDefaults.standard.synchronize()
        }
        
        if myPhoneNumber.isEmpty {
            myPhoneNumber = "No phone number set"
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
            
            let sendString = "iv=\(iv)&token=\(cipherText)&action=\(action)&myID=\(self.myID)&isPicSet=\(isPicSet)&myName=\(self.nameText)&myHandle=\(self.handleText)&myDescription=\(self.descriptionText)&myEmail=\(self.emailText)&myBirthday=\(myBirthday!)&myPhoneNumber=\(myPhoneNumber!)"
            
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
                                self.logEditedPrivateInfo()
                                self.updatePrivateInfo(myPhoneNumber!, userBirthday: myBirthday!)
                                
                                let alertController = UIAlertController(title: "Yay!", message: "Private info successfully changed :)", preferredStyle: .alert)
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

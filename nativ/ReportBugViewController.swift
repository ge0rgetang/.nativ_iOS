//
//  ReportBugViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SideMenu
import MIBadgeButton_Swift

class ReportBugViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate, UIPickerViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    let misc = Misc()
    var pickerView = UIPickerView()
    var oldText: String = "Flow issue"
    var oldRow: Int = 0
    var newText: String = "Flow issue"
    var newRow: Int = 0
    
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    
    var ref = FIRDatabase.database().reference()
    
    var subjectOptions = ["Flow issue", "Drops issue", "Friends issue", "Chats issue", "My Profile issue", "Other"]

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var characterCountLabel: UILabel!
    @IBOutlet weak var subjectTextField: UITextField!
    @IBOutlet weak var bodyTextView: UITextView!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
        self.confirmButton.isEnabled = false
        self.reportBug()
    }
    @IBAction func confirmButtonDown(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "down", view: self.view)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Report Bug"
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        
        self.bodyTextView.text = "Please describe the bug"
        self.bodyTextView.textColor = .lightGray
        self.bodyTextView.delegate = self
        self.subjectTextField.delegate = self
        self.bodyTextView.layer.cornerRadius = 5
        self.bodyTextView.layer.borderColor = UIColor.lightGray.withAlphaComponent(1).cgColor
        self.bodyTextView.layer.borderWidth = 0.5
        self.bodyTextView.clipsToBounds = true
        self.bodyTextView.autocorrectionType = .default
        self.bodyTextView.spellCheckingType = .default
        self.characterCountLabel.isHidden = true
        
        let toolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.isTranslucent = true
        toolbar.sizeToFit()
        
        toolbar.tintColor = misc.nativColor
        let done = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.dismissKeyboard))
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPicker))
        
        toolbar.setItems([cancel, space, done], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        self.pickerView.backgroundColor = UIColor.white
        self.pickerView.delegate = self
        self.subjectTextField.inputView = self.pickerView
        self.subjectTextField.inputAccessoryView = toolbar
        self.pickerView.tag = 0
        self.pickerView.selectRow(self.oldRow, inComponent: 0, animated: false)
        self.subjectTextField.text = self.oldText
        
        self.setSideMenu()
        self.setMenuBarButton()
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNotifications()
        misc.setSideMenuIndex(6)
        self.updateBadge()

        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        } else {
            self.confirmButton.isEnabled = true
            self.logViewBug()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - Navigation
    
    func setSideMenu() {
        if let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController {
            sideMenuNavigationController.leftSide = true
            SideMenuManager.menuLeftNavigationController = sideMenuNavigationController
            SideMenuManager.menuPresentMode = .menuSlideIn
            SideMenuManager.menuAnimationBackgroundColor = misc.nativSideMenu
            SideMenuManager.menuAnimationFadeStrength = 0.35
            SideMenuManager.menuAnimationTransformScaleFactor = 0.95
            SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
        }
    }
    
    func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - PickerView
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.subjectOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.subjectOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.subjectTextField.text = self.subjectOptions[row]
        self.newText = self.subjectOptions[row]
        self.newRow = row
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment  = NSTextAlignment.center
        label.sizeToFit()
        label.text = self.subjectOptions[row]
        
        return label
    }
    
    func cancelPicker() {
        self.subjectTextField.text = self.oldText
        self.pickerView.selectRow(self.oldRow, inComponent: 0, animated: false)
        self.newRow = self.oldRow
        self.newText = self.oldText
        self.dismissKeyboard()
        
    }
    
    func donePicking() {
        self.oldText = self.newText
        self.oldRow = self.newRow
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.donePicking()
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
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
            textView.text = "Please describe the bug"
            textView.textColor = UIColor.lightGray
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        var userInfo = (notification as NSNotification).userInfo!
        var keyboardFrame: CGRect = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        var contentInset: UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 8
        self.scrollView.contentInset = contentInset
    }
    
    func keyboardWillHide(_ notification: Notification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        self.scrollView.contentInset = contentInset
    }
    
    // MARK: - Notifications
    
    func updateBadge() {
        let badge = UserDefaults.standard.integer(forKey: "badgeNumber.native")
        if badge > 0 {
            self.badgeButton.badgeString = "\(badge)"
        } else {
            self.badgeButton.badgeString = nil
        }
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
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
    
    func setMenuBarButton() {
        self.badgeButton.setImage(UIImage(named: "menu"), for: .normal)
        self.badgeButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.badgeButton.addTarget(self, action: #selector(self.presentSideMenu), for: .touchUpInside)
        
        let badgeNumber = UserDefaults.standard.integer(forKey: "badgeNumber.nativ")
        if badgeNumber > 0 {
            self.badgeButton.badgeString = misc.setCount(badgeNumber)
        }
        self.badgeButton.badgeTextColor = .white
        self.badgeButton.badgeBackgroundColor = .red
        self.badgeButton.badgeEdgeInsets = UIEdgeInsetsMake(2, 0, 0, 0)
        
        self.badgeBarButton.customView = self.badgeButton
        self.navigationItem.setLeftBarButton(self.badgeBarButton, animated: false)
    }
    
    // MARK: - Analytics
    
    func logViewBug() {
        FIRAnalytics.logEvent(withName: "viewReportBug", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logReportBug(_ type: String) {
        FIRAnalytics.logEvent(withName: "reportedBug", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "type": type as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writeBug(_ message: String, type: String) {
        self.ref.child("bugs").childByAutoId().setValue(["myID": self.myID, "myIDFIR": self.myIDFIR, "message": message, "type": type])
    }
    
    // MARK: - AWS
    
    func reportBug() {
        var subject: String! = ""
        switch self.oldRow {
        case 0:
            subject = "pond"
        case 1:
            subject = "drop"
        case 2:
            subject = "friend"
        case 3:
            subject = "chat"
        case 4:
            subject = "myProfile"
        case 5:
            subject = "other"
        default:
            subject = "error"
        }
        let message: String! = self.bodyTextView.text
        
        if self.subjectTextField.text!.isEmpty {
            self.displayAlert("No subject", alertMessage: "Please select a subject for the bug.")
            return
        }
        
        if message.isEmpty || self.bodyTextView.textColor == .lightGray {
            self.displayAlert("No message", alertMessage: "Please describe the bug.")
            return
        }
        
        let sendURL = URL(string: "https://dotnative.io/reportBug")
        var sendRequest = URLRequest(url: sendURL!)
        sendRequest.httpMethod = "POST"
        
        let sendString = "myID=\(self.myID)&subject=\(subject!)&message=\(message!)"
        
        sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
        
        let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
            (data, response, error) in
            
            if error != nil {
                print(error ?? "error")
                self.displayAlert("uhh, Houston, we have a problem", alertMessage: "Sorry, could not connect to le internet. :(")
                return
            }
            
            do{
                let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                
                if let parseJSON = json {
                    let status: String = parseJSON["status"] as! String
                    let response = parseJSON["message"] as! String
                    print("status: \(status), message: \(response)")
                    
                    DispatchQueue.main.async(execute: {
                        
                        if status == "error" {
                            self.displayAlert("Oops", alertMessage: "Wow we really messed up. Email us at dotnative@gmail.com to report this/these bugs. :(")
                            return
                        }
                        
                        if status == "success" {
                            self.logReportBug(subject!)
                            self.writeBug(message!, type: subject!)
                            self.displayAlert("Thank you!", alertMessage: "We will look into the bug. As we continue to grow, we rely on people like you to improve everyone's experience with .nativ. We sincerly appreciate your help. :)")
                            self.bodyTextView.text = ""
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
    }
    
}

//
//  FeedbackViewController.swift
//  nativ
//
//  Created by George Tang on 4/17/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SideMenu
import MIBadgeButton_Swift

class FeedbackViewController: UIViewController, UITextViewDelegate {
    
    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    let misc = Misc()
    
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
        self.confirmButton.isEnabled = false
        if self.textView.text.isEmpty || self.textView.textColor == .lightGray {
            self.displayAlert("Nothing typed", alertMessage: "Please enter in your feedback.")
            return
        } else {
            self.writeFeedback(self.textView.text!)
        }
    }
    @IBAction func confirmButtonDown(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "down", view: self.view)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "Give Feedback"
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        
        self.feedbackLabel.text = "Give us some feedback, suggestions, or features you would like changed/added"
        
        self.textView.text = "enter feedback here... "
        self.textView.textColor = .lightGray
        self.textView.delegate = self
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(1).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
        
        self.setSideMenu()
        self.setMenuBarButton()
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNotifications()
        misc.setSideMenuIndex(7)
        self.updateBadge()
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        } else {
            self.confirmButton.isEnabled = true
            self.logViewFeedback()
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

    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "enter feedback here..."
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
    
    func logViewFeedback() {
        FIRAnalytics.logEvent(withName: "viewFeedback", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logGaveFeedback(_ text: String) {
        FIRAnalytics.logEvent(withName: "giveFeedback", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "text": text as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writeFeedback(_ message: String) {
        self.ref.child("feedback").childByAutoId().setValue(["myID": self.myID, "myIDFIR": self.myIDFIR, "message": message])
    
        self.logGaveFeedback(message)
        self.displayAlert("Thank you :)", alertMessage: "Your feedback has been received. This app is made for people like you, and we'll continue to shape it towards what you guys want.")
        self.textView.text = ""
    }

}

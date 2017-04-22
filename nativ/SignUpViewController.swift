//
//  SignUpViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import AWSS3
import FirebaseAnalytics
import FirebaseDatabase
import FirebaseAuth
import SDWebImage
import CryptoSwift
import FBSDKCoreKit
import FBSDKLoginKit
import SideMenu

class SignUpViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Outlets/Variables
    
    var isPicSet: String = "no"
    var handleExists: String = "error"
    
    var ref = FIRDatabase.database().reference()
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var loginButton = UIButton()
    var loginBarButton = UIBarButtonItem()
    
    @IBOutlet weak var sideMenuBarButton: UIBarButtonItem!
    @IBAction func sideMenuBarButtonTapped(_ sender: Any) {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }

    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var userPicImageView: UIImageView!
    
    @IBOutlet weak var userEmailTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userHandleTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    
    @IBAction func userPicImageViewTapped(_ sender: UITapGestureRecognizer) {
        self.selectPicSource()
    }
    
    @IBOutlet weak var signUpButton: UIButton!
    @IBAction func signUpButtonTapped(_ sender: AnyObject) {
        DispatchQueue.main.async(execute: {
            self.misc.colorButton(self.signUpButton, event: "up", view: self.view)
        })
    }
    @IBAction func signUpButtonDown(_ sender: Any) {
        DispatchQueue.main.async(execute: {
            self.sendSignUpInfo()
            self.misc.colorButton(self.signUpButton, event: "down", view: self.view)
        })
    }
    
    @IBOutlet weak var fbLoginButton: UIButton!
    @IBAction func fbLoginButtonTapped(_ sender: Any) {
        self.fbLoginTapped()
    }
    
    @IBOutlet weak var termsLabel: UILabel!
    @IBOutlet weak var privacyPolicyLabel: UILabel!
    @IBOutlet weak var checkHandleLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Sign Up"
        self.loginButton.setTitle("Login", for: .normal)
        self.loginButton.sizeToFit()
        self.loginButton.setTitleColor(misc.nativColor, for: .normal)
        self.loginButton.addTarget(self, action: #selector(self.presentLogin), for: .touchUpInside)
        self.loginBarButton.customView = self.loginButton
        self.navigationItem.setRightBarButton(self.loginBarButton, animated: false)
        
        misc.makeButtonFancy(self.signUpButton, title: "Sign Up!", view: self.view)
        
        self.fbLoginButton.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.fbLoginButton.layer.shadowOpacity = 0.42
        self.fbLoginButton.layer.masksToBounds = false
        self.fbLoginButton.layer.cornerRadius = 2.5
        
        self.userEmailTextField.delegate = self
        self.userEmailTextField.tag = 0
        self.userPasswordTextField.delegate = self
        self.userNameTextField.delegate = self
        self.userNameTextField.tag = 1
        self.userHandleTextField.delegate = self
        self.userHandleTextField.tag = 2
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        let tapTerms = UITapGestureRecognizer(target: self, action: #selector(self.presentTermsPop))
        self.termsLabel.addGestureRecognizer(tapTerms)
        
        let tapPrivacy = UITapGestureRecognizer(target: self, action: #selector(self.openPrivacyPolicy))
        self.privacyPolicyLabel.addGestureRecognizer(tapPrivacy)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetSignUp), name: NSNotification.Name(rawValue: "signedOut"), object: nil)

        self.logViewSignUp()
        
        self.setSideMenu()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        misc.setSideMenuIndex(1)
        self.setNotifications()
        self.signUpButton.isEnabled = true
        self.userPicImageView.isUserInteractionEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.misc.colorButton(self.signUpButton, event: "up", view: self.view)
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
    
    func presentTermsPop() {
        let termsPopViewController = storyboard?.instantiateViewController(withIdentifier: "TermsPopViewController") as! TermsPopViewController
        termsPopViewController.modalPresentationStyle = .popover
        termsPopViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        if let popoverController = termsPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.termsLabel
            popoverController.sourceRect = self.termsLabel.bounds
        }
        
        self.present(termsPopViewController, animated: true, completion: nil)
    }
    
    func presentLogin() {
        self.performSegue(withIdentifier: "fromSignUpToLogin", sender: self)
    }
    
    func openPrivacyPolicy() {
        if let linkURL = URL(string: "https://www.iubenda.com/privacy-policy/7955712") {
            UIApplication.shared.open(linkURL, options: [:], completionHandler: nil)
        }
    }
    
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
    
    // MARK: - ImagePicker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.userPicImageView.image = selectedImage
            self.isPicSet = "yes"
            self.setUserImage()
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
        if self.isPicSet != "yes" {
            self.userPicImageView.image = UIImage(named: "addPicUnselected")
        }
    }
    
    func selectPicSource() {
        self.dismissKeyboard()
        if self.isPicSet != "yes" {
            self.userPicImageView.image = UIImage(named: "addPicSelected")
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let takeSelfieAction = UIAlertAction(title: "Take a selfie!", style: .default, handler: { action in
                imagePicker.sourceType = .camera
                imagePicker.cameraCaptureMode = .photo
                imagePicker.cameraDevice = .front
                if self.isPicSet != "yes" {
                    self.userPicImageView.image = UIImage(named: "addPicUnselected")
                }
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(takeSelfieAction)
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                imagePicker.sourceType = .photoLibrary
                if self.isPicSet != "yes" {
                    self.userPicImageView.image = UIImage(named: "addPicUnselected")
                }
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(choosePhotoLibraryAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {
            action in
            if self.isPicSet != "yes" {
                self.userPicImageView.image = UIImage(named: "addPicUnselected")
            }
        })
        )
        alertController.view.tintColor = misc.nativColor
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: T- extField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.tag == 1 {
            guard let text = textField.text else { return true }
            let length = text.characters.count + string.characters.count - range.length
            return length <= 50
        }
        
        if textField.tag == 2 {
            guard let text = textField.text else { return true }
            let length = text.characters.count + string.characters.count - range.length
            return length <= 15
        }
        
        guard let text = textField.text else { return true }
        let length = text.characters.count + string.characters.count - range.length
        return length <= 191
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == 2 {
            if textField.text != "" {
                self.checkHandle(textField.text!.trimSpace(), type: "user")
            }  else {
                self.checkHandleLabel.text = ""
                self.checkHandleLabel.textColor = .lightGray
            }
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        var userInfo = notification.userInfo!
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
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - Notifications
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.activityView.removeFromSuperview()
            self.signUpButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func setUserImage() {
        self.view.layoutIfNeeded()
        if self.isPicSet == "yes" {
            self.userPicImageView.layer.cornerRadius = userPicImageView.frame.size.width/2
            self.userPicImageView.clipsToBounds = true
        } else {
            self.userPicImageView.layer.cornerRadius = 0
            self.userPicImageView.clipsToBounds = false
        }
    }
    
    func displayActivity(_ message: String, indicator: Bool) {
        self.activityLabel = UILabel(frame: CGRect(x: 8, y: 0, width: self.view.frame.width - 16, height: 50))
        self.activityLabel.text = message
        self.activityLabel.textAlignment = .center
        self.activityLabel.textColor = .white
        self.activityView = UIView(frame: CGRect(x: 8, y: self.view.frame.height/2 - 77.5, width: self.view.frame.width - 16, height: 50))
        self.activityView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        self.activityView.layer.cornerRadius = 5
        if indicator {
            self.activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            self.activityView.addSubview(self.activityIndicator)
            self.activityIndicator.activityIndicatorViewStyle = .white
            self.activityIndicator.startAnimating()
        }
        self.activityView.addSubview(self.activityLabel)
        self.view.addSubview(self.activityView)
    }
    
    func setHandleLabel() {
        DispatchQueue.main.async(execute: {
            switch self.handleExists {
            case "no":
                let spec = self.misc.getSpecialHandles()
                if let handle = self.userHandleTextField.text?.trimSpace().lowercased() {
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
        })
    }
    
    func resetSignUp() {
        self.checkHandleLabel.text = ""
        self.userHandleTextField.text = ""
        self.userNameTextField.text = ""
        self.userEmailTextField.text = ""
        self.userPasswordTextField.text = ""
        self.userPicImageView.image = UIImage(named: "addPicUnselected")
        self.isPicSet = "no"
        self.setUserImage()
    }
    
    // MARK: - Analytics
    
    func logViewSignUp() {
        FIRAnalytics.logEvent(withName: "viewSignUp", parameters: nil)
    }
    
    func logLogInFromFacebook() {
        FIRAnalytics.logEvent(withName: "loggedInFromFacebook", parameters: nil)
    }
    
    func logLogInFromSignUp(_ userID: Int) {
        FIRAnalytics.logEvent(withName: "loggedInFromSignUp", parameters: [
            "userID": userID as NSObject
            ])
    }
    
    func logSignUp(_ userID: Int) {
        FIRAnalytics.logEvent(withName: "signedUp", parameters: [
            "userID": userID as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func setSignUpFIR(_ userEmail: String, userPassword: String, completion: @escaping (_ result:String) -> Void) {
        FIRAuth.auth()?.createUser(withEmail: userEmail, password: userPassword) { (user, error) in
            if error != nil {
                self.displayAlert("Oops", alertMessage: "This email is already registered or we can't connect to our servers right now.")
                completion("error")
                return
            } else {
                let uid = user!.uid
                UserDefaults.standard.removeObject(forKey: "myIDFIR.nativ")
                UserDefaults.standard.set(uid, forKey: "myIDFIR.nativ")
                UserDefaults.standard.synchronize()
                completion("success")
            }
        }
    }
    
    func loginFIR(_ userEmail: String, userPassword: String, userID: Int, userHandle: String, userName: String, picURLString: String, message: String,  completion: @escaping (_ result:String) -> Void) {
        FIRAuth.auth()?.signIn(withEmail: userEmail, password: userPassword) { (user, error) in
            if error != nil {
                self.displayAlert("waht. How did that happen?", alertMessage: "We think your connection dropped mid creation. That's super rare. Guess you're one in a million ;) (sorry that was cheesy). Please contact us at dotnative@gmail.com if you can't login.")
                print(error ?? "error")
                completion("error")
                return
            } else {
                let uid = user!.uid
                self.ref.child("users").child(uid).setValue(["userEmail": userEmail, "userID": userID, "userHandle": userHandle, "userName": userName, "userBirthday": "n/a", "userPhoneNumber": "n/a"])
                let friendListRef = self.ref.child("users").child(uid).child("friendList")
                friendListRef.child("friends").setValue(true)
                friendListRef.child("added").setValue(true)
                friendListRef.child("addedMe").setValue(true)
                friendListRef.child("chats").setValue(true)
                friendListRef.child("lastMessage").setValue(true)
                let userRef = self.ref.child("users").child(uid)
                userRef.child("inPostID").setValue(0)
                userRef.child("notifications").setValue(true)
                userRef.child("inFriendList").setValue(false)
                userRef.child("inNotifications").setValue(false)
                userRef.child("isLoggedIn").setValue(true)
                userRef.child("personalPoints").setValue(0)
                userRef.child("lastFriendPost").setValue(0)
                userRef.child("picURLString").setValue(picURLString)
                completion("success")
            }
        }
    }
    
    func deleteUser(_ message: String) {
        let user = FIRAuth.auth()?.currentUser
        user?.delete(completion: { error in
            if error != nil {
                self.displayAlert("waht. How did that happen?", alertMessage: "We think your connection dropped mid creation. That's super rare. Guess you're one in a million ;) (sorry that was cheesy). Please contact us at dotnative@gmail.com if you can't login.")
                return
            } else {
                self.displayAlert("Oops", alertMessage: message)
                return
            }
        })
        
    }
    
    // MARK: - AWS
    
    func uploadPic(_ picData: Data, url: URL, bucket: String, key: String, size: String) {
        var picSized: UIImage!
        let picImage = UIImage(data: picData)
        let sourceWidth = picImage!.size.width
        let sourceHeight = picImage!.size.height
        
        var scaleFactor: CGFloat!
        switch size {
        case "small":
            if sourceWidth > sourceHeight {
                scaleFactor = 160/sourceWidth
            } else {
                scaleFactor = 160/sourceHeight
            }
        case "medium":
            if sourceWidth > sourceHeight {
                scaleFactor = 300/sourceWidth
            } else {
                scaleFactor = 300/sourceHeight
            }
            
        default:
            if sourceWidth > sourceHeight {
                scaleFactor = 600/sourceWidth
            } else {
                scaleFactor = 600/sourceHeight
            }
        }
        
        let newWidth = scaleFactor*sourceWidth
        let newHeight = scaleFactor*sourceHeight
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContext(newSize)
        picImage?.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        picSized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let newPicData = UIImageJPEGRepresentation(picSized, 1) {
            try? newPicData.write(to: url, options: [.atomic])
        }
        
        let transferManager = AWSS3TransferManager.default()
        let uploadRequest : AWSS3TransferManagerUploadRequest = AWSS3TransferManagerUploadRequest()
        
        uploadRequest.bucket = bucket
        uploadRequest.key = key
        uploadRequest.body = url
        
        transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread(), block: {(task: AWSTask<AnyObject>) -> Any? in
            if let errorNotNS = task.error {
                let error = errorNotNS as NSError
                if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                    switch code {
                    case .cancelled, .paused:
                        print("paused/cancelled")
                        break
                    default:
                        print("error: \(String(describing: uploadRequest.key)) \(error)")
                    }
                    
                } else {
                    print("error: \(String(describing: uploadRequest.key)) \(error)")
                }
                return nil
            }
            
            let uploadOutput = task.result
            print("Upload complete for \(String(describing: uploadRequest.key)), \(String(describing: uploadOutput))")
            return nil
        })
    }
    
    func sendSignUpInfo() {
        self.displayActivity("creating profile...", indicator: true)
        self.dismissKeyboard()
        self.signUpButton.isEnabled = false
        self.userPicImageView.isUserInteractionEnabled = false
        
        let userEmail: String = self.userEmailTextField.text!.trimSpace()
        let userPassword: String = self.userPasswordTextField.text!
        let userName: String = self.userNameTextField.text!.trimSpace()
        let userHandle: String = self.userHandleTextField.text!.trimSpace()
        
        var userPicData: Data!
        if self.isPicSet == "yes" {
            userPicData = UIImageJPEGRepresentation(self.userPicImageView.image!, 1)
        }
        
        if userEmail.isEmpty || userPassword.isEmpty || userName.isEmpty || userHandle.isEmpty {
            self.displayAlert("Incomplete Info", alertMessage: "Please fill the empty fields.")
            return
        }
        
        let atSet = CharacterSet(charactersIn: "@")
        if userEmail.rangeOfCharacter(from: atSet) == nil {
            self.displayAlert("Invalid Email", alertMessage: "Please enter a valid email.")
            return
        }
        
        if userPassword.characters.count < 6 {
            self.displayAlert("Password Too Short", alertMessage: "Your pass needs to be at least 6 characters.")
            return
        }
        
        let hasSpecialChars = misc.checkSpecialCharacters(userHandle)
        if hasSpecialChars {
            self.displayAlert("Special Characters", alertMessage: "Please remove any special characters from your handle. Only a-z, A-Z, and 0-9 are allowed.")
            return
        }
        
        let handleLower = userHandle.lowercased()
        let spec = misc.getSpecialHandles()
        if spec.contains(handleLower) {
            self.displayAlert(":)", alertMessage: "Sorry, this handle is taken by one of our resident skinny dippers. Please choose another.")
            return
        }
        
        let spaceCharacter = CharacterSet.whitespaces
        if userHandle.rangeOfCharacter(from: spaceCharacter) != nil {
            self.displayAlert("Space Found", alertMessage: "Please remove any spaces in your handle.")
            return
        }
        
        var deviceToken: String
        if let token = UserDefaults.standard.string(forKey: "deviceToken.nativ") {
            deviceToken = token
        } else {
            deviceToken = "n/a"
        }
        
        self.setSignUpFIR(userEmail, userPassword: userPassword) { (result:String) in
            if result == "success" {
                
                let myIDFIR: String = UserDefaults.standard.string(forKey: "myIDFIR.nativ")!
                let token = self.misc.generateToken(16, firebaseID: myIDFIR)
                let iv = token.first!
                let tokenString = token.last!
                let key = token[1]
                
                do {
                    let aes = try AES(key: key, iv: iv)
                    let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
                    
                    let regURL = URL(string: "https://dotnative.io/register")
                    var postRequest = URLRequest(url: regURL!)
                    postRequest.httpMethod = "POST"
                    
                    let postString = "iv=\(iv)&token=\(cipherText)&userEmail=\(userEmail)&userName=\(userName)&userHandle=\(userHandle)&isPicSet=\(self.isPicSet)&myIDFIR=\(myIDFIR)&deviceID=\(deviceToken)"
                    postRequest.httpBody = postString.data(using: String.Encoding.utf8)
                    
                    let task = URLSession.shared.dataTask(with: postRequest as URLRequest) {
                        (data, response, error) in
                        
                        if error != nil {
                            print(error ?? "error")
                            self.deleteUser("waht. How did that happen? We think your connection dropped mid creation. That's super rare. Guess you're one in a million ;) (sorry that was cheesy). Please contact us at dotnative@gmail.com if you can't login/or sign up again.")
                            return
                        }
                        
                        do{
                            let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                            
                            if let parseJSON = json {
                                let status = parseJSON["status"] as! String
                                let message: String = parseJSON["message"] as! String
                                print("status: \(status), message: \(message)")
                                
                                DispatchQueue.main.async(execute: {
                                    
                                    if status == "error" {
                                        self.activityView.removeFromSuperview()
                                        self.deleteUser(message)
                                    }
                                    
                                    if status == "success" {
                                        let myID = parseJSON["myID"] as! Int
                                        UserDefaults.standard.set(true, forKey: "isUserLoggedIn.nativ")
                                        UserDefaults.standard.set(myID, forKey: "myID.nativ")
                                        let userNameTrunc = self.misc.truncateName(userName)
                                        UserDefaults.standard.set(userNameTrunc, forKey: "myName.nativ")
                                        UserDefaults.standard.set(userName, forKey: "myFullName.nativ")
                                        UserDefaults.standard.set(userHandle, forKey: "myHandle.nativ")
                                        UserDefaults.standard.set(false, forKey: "inFriendList.nativ")
                                        UserDefaults.standard.synchronize()
                                        
                                        let bucket = parseJSON["bucket"] as! String
                                        let smallKey = parseJSON["smallKey"] as! String
                                        let mediumKey = parseJSON["mediumKey"] as! String
                                        let largeKey = parseJSON["largeKey"] as! String
                                        if smallKey != "default_small" {
                                            let smallURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicSmall.nativ")
                                            self.uploadPic(userPicData, url: smallURL, bucket: bucket, key: smallKey, size: "small")
                                            let myURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(smallKey)")!
                                            UserDefaults.standard.set(myURL, forKey: "myPicURL.nativ")
                                            UserDefaults.standard.synchronize()
                                            
                                            let mediumURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicMedium.nativ")
                                            self.uploadPic(userPicData, url: mediumURL, bucket: bucket, key: mediumKey, size: "medium")
                                            
                                            let largeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicLarge.nativ")
                                            self.uploadPic(userPicData, url: largeURL, bucket: bucket, key: largeKey, size: "large")
                                        }
                                        
                                        let urlString = "https://\(bucket).s3.amazonaws.com/\(largeKey)"
                                        self.loginFIR(userEmail, userPassword: userPassword, userID: myID, userHandle: userHandle, userName: userName, picURLString: urlString, message: message) { (result:String) in
                                            if result == "success" {
                                                DispatchQueue.main.async(execute: {
                                                    self.activityView.removeFromSuperview()
                                                    let alertController = UIAlertController(title: "Sign Up Complete!", message: message, preferredStyle: .alert)
                                                    let okAction = UIAlertAction(title: "Dive in", style: .default) { action in
                                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToMyProfile"), object: nil)
                                                    }
                                                    alertController.addAction(okAction)
                                                    alertController.view.tintColor = self.misc.nativColor
                                                    self.signUpButton.isEnabled = true
                                                    self.logLogInFromSignUp(myID)
                                                    self.misc.clearWebImageCache()
                                                    self.userPicImageView.isUserInteractionEnabled = true
                                                    self.present(alertController, animated: true, completion: nil)
                                                })
                                            }
                                        }
                                    }
                                    
                                })
                            }
                            
                        } catch {
                            print(error)
                            self.deleteUser("We're updating our servers right now. Please try again later.")
                        }
                        
                    }
                    
                    task.resume()
                    
                } catch {
                    self.deleteUser("We messed up. Please contact us at dotnative@gmail.com if this continues.")
                }
            }
        }
    }
    
    func checkHandle(_ handle: String, type: String) {
        let hasSpecialChars = self.misc.checkSpecialCharacters(handle)
        if hasSpecialChars {
            self.handleExists = "special"
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
    
    // MARK: - FBSDK Login
    
    func fbLoginTapped() {
        let loginManager = FBSDKLoginManager()
        loginManager.logIn(withReadPermissions: ["public_profile", "email", "user_friends"], from: self) { (result, error) -> Void in
            if error != nil {
                print(error?.localizedDescription ?? "error")
                self.displayAlert("Facebook Error", alertMessage: "We encountered an error while trying to retrieve your fb info. Please report this bug if it persists.")
                return
            } else if result!.isCancelled {
                print("cancelled fb login")
            } else {
                self.logLogInFromFacebook()
                if result!.grantedPermissions.contains("email") {
                    self.getFBUserData()
                }
            }
        }
    }
    
    func getFBUserData() {
        if FBSDKAccessToken.current() != nil {
            FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "email, name, id, gender"]).start(completionHandler: {(connection, result, error) -> Void in
                if error != nil {
                    print(error?.localizedDescription ?? "error")
                    self.displayAlert("Facebook Error", alertMessage: "We encountered an error while trying to retrieve your fb info. Please report this bug if it persists.")
                    return
                } else {
                    if let userInfo = result as? [String:Any] {
                        print(userInfo)
                        if let userEmail = userInfo["email"] as? String {
                            self.userEmailTextField.text = userEmail
                        }
                        if let userName = userInfo["name"] as? String {
                            self.userNameTextField.text = userName
                        }
                        if let id = userInfo["id"] as? String {
                            let picURL = URL(string: "https://graph.facebook.com/\(id)/picture?type=large")!
                            self.userPicImageView.sd_setImage(with: picURL)
                            self.isPicSet = "yes"
                            self.setUserImage()
                        }
                        if let gender = userInfo["gender"] as? String {
                            UserDefaults.standard.set(gender, forKey: "gender.nativ")
                            UserDefaults.standard.synchronize()
                        }
                    }
                }
            })
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        print("fb logged out")
    }
    
}


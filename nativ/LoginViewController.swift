//
//  LoginViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import Foundation
import FirebaseAnalytics
import FirebaseAuth
import FirebaseDatabase
import AWSS3
import SDWebImage
import CryptoSwift

class LoginViewController: UIViewController, UITextFieldDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Outlets/Variables
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var dotnativeLabel: UILabel!
    
    @IBOutlet weak var userLoginTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    @IBAction func loginButtonTapped(_ sender: AnyObject) {
        let email: String! = self.userLoginTextField.text?.trimSpace()
        let password: String! = self.userPasswordTextField.text?.trimSpace()
        if email.isEmpty || password.isEmpty {
            self.displayAlert("Incorrect Login", alertMessage: "Please enter a valid Email/Handle and Password")
            return
        } else {
            self.dismissKeyboard()
            self.loginButton.isEnabled = false
            self.displayActivity("logging in...", indicator: true)
            self.loginFIR(email!, userPassword: password!)
        }
        misc.colorButton(self.loginButton, event: "up", view: self.view)
    }
    @IBAction func loginButtonDown(_ sender: Any) {
        misc.colorButton(self.loginButton, event: "down", view: self.view)
    }
    
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBAction func forgotPasswordButtonTapped(_ sender: AnyObject) {
        self.presentForgotPassword()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Login"
        
        misc.makeButtonFancy(self.loginButton, title: "Login", view: self.view)
        
        self.userLoginTextField.delegate = self
        self.userPasswordTextField.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(LoginViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNotifications()
        self.logViewLogin()
        self.loginButton.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        misc.colorButton(self.loginButton, event: "up", view: self.view)
        self.userLoginTextField.text = ""
        self.userPasswordTextField.text = "" 
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        self.userLoginTextField.text = ""
        self.userPasswordTextField.text = ""
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - Navigation
    
    func presentForgotPassword() {
        let forgotPassPopViewController = storyboard?.instantiateViewController(withIdentifier: "ForgotPasswordPopViewController") as! ForgotPasswordPopViewController
        forgotPassPopViewController.modalPresentationStyle = .popover
        forgotPassPopViewController.preferredContentSize = CGSize(width: 320, height: 100)
        
        if let popoverController = forgotPassPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = self.forgotPasswordButton
            popoverController.sourceRect = self.forgotPasswordButton.bounds
        }
        
        self.present(forgotPassPopViewController, animated: true, completion: nil)
    }
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
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
            self.loginButton.isEnabled = true
            self.present(alertController, animated: true, completion: nil)
        })
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
    
    // MARK: - Analytics
    
    func logViewLogin() {
        FIRAnalytics.logEvent(withName: "viewLogin", parameters: nil)
    }
    
    func logLogInFromLogin(_ userID: Int) {
        FIRAnalytics.logEvent(withName: "loggedInFromLogin", parameters: [
            "userID": userID as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func loginFIR(_ userEmail: String, userPassword: String) {
        FIRAuth.auth()?.signIn(withEmail: userEmail, password: userPassword) {(user, error) in
            if error != nil {
                print(error ?? "error")
                if let desc = error?.localizedDescription {
                    if desc == "The user account has been disabled by an administrator." {
                        self.displayAlert("Account Disabled", alertMessage: "Your account has been disabled. Please contact us for further information.")
                        return
                    } else {
                        self.displayAlert("Invalid Login", alertMessage: "Your email/pass was incorrect or we can't connect to our servers right now.")
                        return
                    }
                }
            } else {
                if let user = FIRAuth.auth()?.currentUser {
                    let uid = user.uid
                    self.ref.child("users").child(uid).child("isLoggedIn").setValue(true)
                    UserDefaults.standard.removeObject(forKey: "myIDFIR.nativ")
                    UserDefaults.standard.set(uid, forKey: "myIDFIR.nativ")
                    UserDefaults.standard.synchronize()
                    self.login(userEmail, myIDFIR: uid)
                }
            }
        }
    }
    
    // MARK: - AWS
    
    func downloadPic(_ url: URL, bucket: String, key: String) {
        let transferManager = AWSS3TransferManager.default()
        let downloadRequest : AWSS3TransferManagerDownloadRequest = AWSS3TransferManagerDownloadRequest()
        
        downloadRequest.bucket = bucket
        downloadRequest.key = key
        downloadRequest.downloadingFileURL = url
        
        transferManager.download(downloadRequest).continueWith(executor: AWSExecutor.mainThread(), block: {(task: AWSTask<AnyObject>) -> Any? in
            if let errorNoNS = task.error {
                let error = errorNoNS as NSError
                if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                    switch code {
                    case .cancelled, .paused:
                        print("paused/cancelled")
                        break
                    default:
                        print("error: \(String(describing: downloadRequest.key)) \(error)")
                    }
                    
                } else {
                    print("error: \(String(describing: downloadRequest.key)) \(error)")
                }
                return nil
            }
            
            let downloadOutput = task.result
            print("Upload complete for \(String(describing: downloadRequest.key)), \(String(describing: downloadOutput))")
            return nil
        })
    }
    
    
    func login(_ email: String, myIDFIR: String) {
        
        var deviceToken: String
        if let token = UserDefaults.standard.string(forKey: "deviceToken.nativ") {
            deviceToken = token
        } else {
            deviceToken = "1234567890123456789012345678901234567890123456789012345678901234"
        }
        
        let myIDFIR: String = UserDefaults.standard.string(forKey: "myIDFIR.nativ")!
        let token = misc.generateToken(16, firebaseID: myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let loginURL = URL(string: "https://dotnative.io/login")
            var postRequest = URLRequest(url: loginURL!)
            postRequest.httpMethod = "POST"
            
            let postString = "iv=\(iv)&token=\(cipherText)&userEmail=\(email)&deviceID=\(deviceToken)"
            postRequest.httpBody = postString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: postRequest as URLRequest) {
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
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")

                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Invalid Login", alertMessage: message)
                                return
                            }
                            
                            if status == "success" {
                                self.activityView.removeFromSuperview()
                                let myID = parseJSON["myID"] as! Int
                                let myName = parseJSON["userName"] as! String
                                let myFullName = parseJSON["userFullName"] as! String
                                let myHandle = parseJSON["handle"] as! String
                                let bucket = parseJSON["bucket"] as! String
                                
                                let smallKey = parseJSON["smallKey"] as! String
                                let smallURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicSmall.nativ")
                                self.downloadPic(smallURL, bucket: bucket, key: smallKey)
                                let myURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(smallKey)")!
                                UserDefaults.standard.set(myURL, forKey: "myPicURL.nativ")
                                
                                let mediumKey = parseJSON["mediumKey"] as! String
                                let mediumURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicMedium.nativ")
                                self.downloadPic(mediumURL, bucket: bucket, key: mediumKey)
                                
                                let largeKey = parseJSON["largeKey"] as! String
                                let largeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicLarge.nativ")
                                self.downloadPic(largeURL, bucket: bucket, key: largeKey)
                                
                                UserDefaults.standard.set(myID, forKey: "myID.nativ")
                                UserDefaults.standard.set(myName, forKey: "myName.nativ")
                                UserDefaults.standard.set(myFullName, forKey: "myFullName.nativ")
                                UserDefaults.standard.set(myHandle, forKey: "myHandle.nativ")
                                UserDefaults.standard.set(true, forKey: "isUserLoggedIn.nativ")
                                UserDefaults.standard.set(false, forKey: "inFriendList.nativ")
                                UserDefaults.standard.synchronize()
                                self.misc.clearWebImageCache()
                                self.logLogInFromLogin(myID)
                                _ = self.navigationController?.popViewController(animated: false)
                                NotificationCenter.default.post(name: Notification.Name(rawValue: "signedIn"), object: nil)
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
            self.displayAlert("Token Error", alertMessage: "We messed up. If this continues, please send us an email at dotnative@gmail.com")
            print(error)
            return
        }
    }
    
}


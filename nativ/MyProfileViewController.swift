//
//  MyProfileViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseAuth
import FirebaseDatabase
import SDWebImage
import CryptoSwift
import AWSS3
import SideMenu
import MIBadgeButton_Swift

class MyProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var myNameToPass: String = "blank"
    var myHandleToPass: String = "blank"
    var myDescriptionToPass: String = "blank"
    var myBirthdayToPass: String = "blank"
    var myPhoneNumberToPass: String = "blank"
    var picURLToPass: URL!
    var myEmailToPass: String = "blank"
    
    var ref = FIRDatabase.database().reference()
    
    let misc = Misc()
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var myPicImageView: UIImageView!
    @IBOutlet weak var myPointsLabel: UILabel!
    @IBOutlet weak var myNameLabel: UILabel!
    @IBOutlet weak var myHandleLabel: UILabel!
    @IBOutlet weak var myDescriptionLabel: UILabel!
    @IBOutlet weak var myEmailLabel: UILabel!
    @IBOutlet weak var myBirthdayLabel: UILabel!
    @IBOutlet weak var myPhoneNumberLabel: UILabel!
    @IBOutlet weak var picWhiteView: UIView!
    @IBOutlet weak var bodyWhiteView: UIView!
    @IBOutlet weak var privateWhiteView: UIView!
    @IBOutlet weak var privateInfoLabel: UILabel!
    
    @IBOutlet weak var myPicWidth: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Me :)"
        
        let model = UIDevice.current.modelName
        if model.contains("iPhone") {
            if model.lowercased().contains("plus") {
                self.myPicWidth.constant = 200
            } else if model.contains("6") || model.contains("7") || model.contains("8") {
                self.myPicWidth.constant = 175
            } else {
                self.myPicWidth.constant = 150
            }
        }
        
        self.settingsButton.setImage(UIImage(named: "settingsUnselected"), for: .normal)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .selected)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .highlighted)
        self.settingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.settingsButton.addTarget(self, action: #selector(self.presentMyOptions), for: .touchUpInside)
        self.settingsBarButton.customView = self.settingsButton
        self.navigationItem.setRightBarButton(self.settingsBarButton, animated: false)
        
        let tapImageBackground: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectPicSource))
        self.picWhiteView.addGestureRecognizer(tapImageBackground)
        tapImageBackground.cancelsTouchesInView = false
        let tapImage: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectPicSource))
        self.myPicImageView.addGestureRecognizer(tapImage)
        tapImage.cancelsTouchesInView = false
        
        let tapPubInfo: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditPublicInfoPop))
        self.bodyWhiteView.addGestureRecognizer(tapPubInfo)
        tapPubInfo.cancelsTouchesInView = false
        
        let tapPrivateInfo: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentEditPrivateInfoActionSheet))
        self.privateWhiteView.addGestureRecognizer(tapPrivateInfo)
        tapPrivateInfo.cancelsTouchesInView = false
        
        self.picWhiteView.alpha = 0
        self.bodyWhiteView.alpha = 0
        self.privateWhiteView.alpha = 0
        self.myPicImageView.alpha = 0
        UIView.animate(withDuration: 0.75, animations: {
            self.picWhiteView.alpha = 1
            self.bodyWhiteView.alpha = 1
            self.myPicImageView.alpha = 1
            self.privateWhiteView.alpha = 1
        })
        
        self.setSideMenu()
        self.setMenuBarButton()
        self.makeWhiteViewsFancy()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.makeWhiteViewsWhite()
        self.setNotifications()
        misc.setSideMenuIndex(4)
        self.updateBadge()

        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
        } else {
            self.logViewMyProfile()
            self.getMyProfile()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillLayoutSubviews() {
        self.myPicImageView.layer.cornerRadius = self.myPicImageView.frame.size.width/2
        self.myPicImageView.clipsToBounds = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        misc.clearWebImageCache()
    }
    
    // MARK: - Navigation
    
    func presentMyOptions() {
        self.settingsButton.isSelected = true
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let editProfilePicAction = UIAlertAction(title: "Edit Profile Pic", style: .default, handler: { action in
            self.selectPicSource()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editProfilePicAction)
        
        let editPublicInfoAction = UIAlertAction(title: "Edit Public Info", style: .default, handler: { action in
            self.presentEditPublicInfoPop()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editPublicInfoAction)
        
        let editPrivateInfoAction = UIAlertAction(title: "Edit Phone/Birthday", style: .default, handler: { action in
            self.presentEditPrivateInfoPop()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editPrivateInfoAction)
        
        let editLoginInfoAction = UIAlertAction(title: "Change Email/Password", style: .default, handler: { action in
            self.presentEditLoginInfoPop()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editLoginInfoAction)
        
        let logOutAction = UIAlertAction(title: "Log Out", style: .default, handler: { action in
            self.settingsButton.isSelected = false
            self.logOut()
            self.logLogOut()
        })
        alertController.addAction(logOutAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
        })
        )
        alertController.view.tintColor = misc.nativColor
        self.present(alertController, animated: true, completion: nil)
    }
    
    func presentEditPrivateInfoActionSheet() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let editPrivateInfoAction = UIAlertAction(title: "Edit Phone/Birthday", style: .default, handler: { action in
            self.presentEditPrivateInfoPop()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editPrivateInfoAction)
        
        let editLoginInfoAction = UIAlertAction(title: "Change Email/Password", style: .default, handler: { action in
            self.presentEditLoginInfoPop()
            self.settingsButton.isSelected = false
        })
        alertController.addAction(editLoginInfoAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
        })
        )
        alertController.view.tintColor = misc.nativColor
        self.present(alertController, animated: true, completion: nil)
    }
    
    func presentEditPublicInfoPop() {
        self.bodyWhiteView.backgroundColor = misc.nativFade
        
        let editPublicInfoPopViewController = storyboard?.instantiateViewController(withIdentifier: "EditPublicInfoPopViewController") as! EditPublicInfoPopViewController
        editPublicInfoPopViewController.modalPresentationStyle = .popover
        editPublicInfoPopViewController.preferredContentSize = CGSize(width: 320, height: 275)
        
        editPublicInfoPopViewController.handleText = self.myHandleToPass
        editPublicInfoPopViewController.nameText = self.myNameToPass
        editPublicInfoPopViewController.descriptionText = self.myDescriptionToPass
        
        editPublicInfoPopViewController.emailText = self.myEmailToPass
        editPublicInfoPopViewController.phoneText = self.myPhoneNumberToPass
        editPublicInfoPopViewController.birthdayText = self.myBirthdayToPass
        
        if let popoverController = editPublicInfoPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.permittedArrowDirections = .any
            popoverController.sourceView = self.myHandleLabel
            popoverController.sourceRect = self.myHandleLabel.bounds
        }
        
        self.present(editPublicInfoPopViewController, animated: true, completion: nil)
    }
    
    func presentEditPrivateInfoPop() {
        self.privateWhiteView.backgroundColor = misc.nativFade
        
        let editPrivateInfoPopViewController = storyboard?.instantiateViewController(withIdentifier: "EditPrivateInfoPopViewController") as! EditPrivateInfoPopViewController
        editPrivateInfoPopViewController.modalPresentationStyle = .popover
        editPrivateInfoPopViewController.preferredContentSize = CGSize(width: 320, height: 200)
        
        editPrivateInfoPopViewController.phoneText = self.myPhoneNumberToPass
        editPrivateInfoPopViewController.birthdayText = self.myBirthdayToPass
        
        editPrivateInfoPopViewController.handleText = self.myHandleToPass
        editPrivateInfoPopViewController.nameText = self.myNameToPass
        editPrivateInfoPopViewController.descriptionText = self.myDescriptionToPass
        editPrivateInfoPopViewController.emailText = self.myEmailToPass
        
        if let popoverController = editPrivateInfoPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.permittedArrowDirections = .any
            popoverController.sourceView = self.myBirthdayLabel
            popoverController.sourceRect = self.myBirthdayLabel.bounds
        }
        
        self.present(editPrivateInfoPopViewController, animated: true, completion: nil)
    }
    
    func presentEditLoginInfoPop() {
        self.privateWhiteView.backgroundColor = misc.nativFade
        
        let editLoginInfoPopViewController = storyboard?.instantiateViewController(withIdentifier: "EditLoginInfoPopViewController") as! EditLoginInfoPopViewController
        editLoginInfoPopViewController.modalPresentationStyle = .popover
        editLoginInfoPopViewController.preferredContentSize = CGSize(width: 320, height: 320)
        
        editLoginInfoPopViewController.handleText = self.myHandleToPass
        editLoginInfoPopViewController.nameText = self.myNameToPass
        editLoginInfoPopViewController.descriptionText = self.myDescriptionToPass
        
        editLoginInfoPopViewController.emailText = self.myEmailToPass
        editLoginInfoPopViewController.phoneText = self.myPhoneNumberToPass
        editLoginInfoPopViewController.birthdayText = self.myBirthdayToPass
        
        if let popoverController = editLoginInfoPopViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.permittedArrowDirections = .any
            popoverController.sourceView = self.myEmailLabel
            popoverController.sourceRect = self.myEmailLabel.bounds
        }
        
        self.present(editLoginInfoPopViewController, animated: true, completion: nil)
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
    
    func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    // MARK: - ImagePicker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        self.makeWhiteViewsWhite()
        
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.myPicImageView.image = selectedImage
            self.setUserImage()
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func selectPicSource() {
        self.picWhiteView.backgroundColor = misc.nativFade
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let takeSelfieAction = UIAlertAction(title: "Take a selfie!", style: .default, handler: { action in
                imagePicker.sourceType = .camera
                imagePicker.cameraCaptureMode = .photo
                imagePicker.cameraDevice = .front
                self.makeWhiteViewsWhite()
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(takeSelfieAction)
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                imagePicker.sourceType = .photoLibrary
                self.makeWhiteViewsWhite()
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(choosePhotoLibraryAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
            self.makeWhiteViewsWhite()
        })
        )
        alertController.view.tintColor = misc.nativColor
        self.present(alertController, animated: true, completion: nil)
    }
    
    func setUserImage() {
        self.view.layoutIfNeeded()
        self.myPicImageView.layer.cornerRadius = myPicImageView.frame.size.width/2
        self.myPicImageView.clipsToBounds = true
        self.editUserImage()
    }
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.settingsButton.isSelected = false
        self.makeWhiteViewsWhite()
    }
    
    // MARK: - Sort Options
    
    func myProfileSortCriteriaDidChange(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 1 {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToHistory"), object: nil)
        }
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.getMyProfile), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.makeWhiteViewsWhite), name: NSNotification.Name(rawValue: "makeWhiteViewsWhite"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "makeWhiteViewsWhite"), object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func makeWhiteViewsFancy() {
        self.picWhiteView.backgroundColor = UIColor.white
        self.picWhiteView.layer.masksToBounds = false
        self.picWhiteView.layer.cornerRadius = 2.5
        self.picWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.picWhiteView.layer.shadowOpacity = 0.42
        self.picWhiteView.sizeToFit()
        
        self.bodyWhiteView.backgroundColor = UIColor.white
        self.bodyWhiteView.layer.masksToBounds = false
        self.bodyWhiteView.layer.cornerRadius = 2.5
        self.bodyWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.bodyWhiteView.layer.shadowOpacity = 0.42
        self.bodyWhiteView.sizeToFit()
        
        self.privateWhiteView.backgroundColor = UIColor.white
        self.privateWhiteView.layer.masksToBounds = false
        self.privateWhiteView.layer.cornerRadius = 2.5
        self.privateWhiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
        self.privateWhiteView.layer.shadowOpacity = 0.42
        self.privateWhiteView.sizeToFit()
    }
    
    func makeWhiteViewsWhite() {
        self.picWhiteView.backgroundColor = .white
        self.bodyWhiteView.backgroundColor = .white
        self.privateWhiteView.backgroundColor = .white
    }
    
    func formatTimestamp(_ timestampString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.date(from: timestampString)
        
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let timestamp = dateFormatter.string(from: date!)
        return timestamp
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
    
    func logViewMyProfile() {
        FIRAnalytics.logEvent(withName: "viewMyProfile", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logLogOut() {
        FIRAnalytics.logEvent(withName: "loggedOut", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logProfPicEdited() {
        FIRAnalytics.logEvent(withName: "profilePicEdited", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func observeMyPoints() {
        let myPointsRef = self.ref.child("users").child(self.myIDFIR).child("personalPoints")
        myPointsRef.observe(.value, with: {
            (snapshot) -> Void in
            if let myPoints = snapshot.value as? Int {
                self.myPointsLabel.text = "\(myPoints) points"
            }
        })
    }
    
    // MARK: - AWS
    
    func editUserImage() {
        let action: String = "edit"
        let isPicSet: String = "yes"
        let myPicData: Data! = UIImageJPEGRepresentation(self.myPicImageView.image!, 1)
        
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
            
            let sendString = "iv=\(iv)&token=\(cipherText)&action=\(action)&myID=\(self.myID)&isPicSet=\(isPicSet)&myName=\(self.myNameToPass)&myHandle=\(self.myHandleToPass)&myDescription=\(self.myDescriptionToPass)&myEmail=\(self.myEmailToPass)&myBirthday=\(self.myBirthdayToPass)&myPhoneNumber=\(self.myPhoneNumberToPass)"
            
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your changes may not have been made. Please report the bug in the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                
                                self.logProfPicEdited()
                                
                                let bucket = parseJSON["bucket"] as! String
                                let smallKey = parseJSON["smallKey"] as! String
                                let mediumKey = parseJSON["mediumKey"] as! String
                                let largeKey = parseJSON["largeKey"] as! String
                                
                                if smallKey != "default_small" {
                                    let smallURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicSmall.nativ")
                                    self.uploadPic(myPicData, url: smallURL, bucket: bucket, key: smallKey, size: "small")
                                    let myURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(smallKey)")!
                                    UserDefaults.standard.set(myURL, forKey: "myPicURL.nativ")
                                    UserDefaults.standard.synchronize()
                                    
                                    let mediumURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicMedium.nativ")
                                    self.uploadPic(myPicData, url: mediumURL, bucket: bucket, key: mediumKey, size: "medium")
                                    
                                    let largeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicLarge.nativ")
                                    self.uploadPic(myPicData, url: largeURL, bucket: bucket, key: largeKey, size: "large")
                                    self.myPicImageView.sd_setImage(with: largeURL)
                                    
                                    let urlString = "https://\(bucket).s3.amazonaws.com/\(largeKey)"
                                    self.ref.child("users").child(self.myIDFIR).child("picURLString").setValue(urlString)
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu.")
            return
        }
    }
    
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
    
    func getMyProfile() {
        let picSize: String = "large"
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let getURL = URL(string: "https://dotnative.io/getMyProfile")
            var getRequest = URLRequest(url: getURL!)
            getRequest.httpMethod = "POST"
            
            let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&size=\(picSize)"
            getRequest.httpBody = getString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: getRequest as URLRequest) {
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
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load your profile. Please report the bug in the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                let myName = parseJSON["myName"] as! String
                                self.myNameLabel.text = myName
                                self.myNameToPass = myName.trimSpace()
                                
                                let myHandle = parseJSON["myHandle"] as! String
                                self.myHandleLabel.text = "@\(myHandle)"
                                self.myHandleToPass = myHandle.trimSpace()
                                
                                let myDescription = parseJSON["myDescription"] as! String
                                self.myDescriptionLabel.text = myDescription
                                self.myDescriptionToPass = myDescription.trimSpace()
                                
                                let myPoints = parseJSON["myPoints"] as! Int
                                self.myPointsLabel.text = "\(myPoints) points"
                                
                                let myEmail = parseJSON["myEmail"] as! String
                                self.myEmailLabel.text = myEmail
                                self.myEmailToPass = myEmail.trimSpace()
                                
                                let myBirthday = parseJSON["myBirthday"] as! String
                                if myBirthday.lowercased() == "need to set" {
                                    self.myBirthdayLabel.text = "No birthday set"
                                    self.myBirthdayToPass = "No birthday set"
                                } else {
                                    let bday = self.formatTimestamp(myBirthday)
                                    self.myBirthdayLabel.text = bday
                                    self.myBirthdayToPass = bday.trimSpace()
                                }
                                
                                let myPhoneNumber = parseJSON["myPhoneNumber"] as! String
                                if myPhoneNumber.lowercased() == "need to set" {
                                    self.myPhoneNumberLabel.text = "No phone number set"
                                    self.myPhoneNumberToPass = "No phone number set"
                                } else {
                                    self.myPhoneNumberLabel.text = myPhoneNumber
                                    self.myPhoneNumberToPass = myPhoneNumber.trimSpace()
                                }
                                
                                let key = parseJSON["key"] as! String
                                let bucket = parseJSON["bucket"] as! String
                                let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                self.picURLToPass = picURL
                                
                                let largeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMyPicLarge.nativ")
                                do {
                                    let data = try Data(contentsOf: largeURL)
                                    let tempImage = UIImage(data: data)
                                    self.myPicImageView.sd_setImage(with: picURL, placeholderImage: tempImage)
                                } catch {
                                    self.myPicImageView.sd_setImage(with: picURL)
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu.")
            return
        }
    }
    
    func logOut() {
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/logout")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)"
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
                        let status = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we've encountered an error trying to log you out. Please report the bug in the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                self.ref.child("users").child(self.myIDFIR).child("isLoggedIn").setValue(false)
                                let auth = FIRAuth.auth()
                                do {
                                    try auth?.signOut()
                                } catch let error as NSError {
                                    print(error)
                                }
                                UserDefaults.standard.set(false, forKey: "isUserLoggedIn.nativ")
                                UserDefaults.standard.removeObject(forKey: "myID.nativ")
                                UserDefaults.standard.removeObject(forKey: "myIDFIR.nativ")
                                UserDefaults.standard.synchronize()
                                NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
                                NotificationCenter.default.post(name: Notification.Name(rawValue: "unwindToHome"), object: nil)
                                NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToSignUp"), object: nil)
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in the report section of the menu.")
            return
        }
    }
    
}

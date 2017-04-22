//
//  ImagePostViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import AWSS3
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift
import SDWebImage

class ImagePostViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    var text: String = "post..."
    var image: UIImage!
    var segment: String = "pond"
    var segueSender: String = "pondList"
    
    var longitude: Double = 200
    var latitude: Double = 200
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    
    weak var sendImagePostDelegate: SendImagePostProtocol?
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBAction func imageTapped(_ sender: UITapGestureRecognizer) {
        self.selectPicSource()
    }
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: AnyObject) {
        DispatchQueue.main.async(execute: {
            self.sendPost()
            self.sendButton.isEnabled = false
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.image != nil {
            self.imageView.image = image
        }
        
        self.navigationItem.title = "Drop an Image"
        
        self.textView.delegate = self
        self.characterCountLabel.isHidden = true
        self.sendButton.isEnabled = false
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(1).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.text = self.text
        if self.text == "post..." {
            self.textView.textColor = .lightGray
        } else {
            self.textView.textColor = .black
        }
        self.textView.textAlignment = .left
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
        self.textView.isUserInteractionEnabled = true
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNotifications()
        self.sendButton.isEnabled = true
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0  || self.myIDFIR == "0000000000000000000000000000" {
            self.unwindToHome()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
        } else {
            self.logViewImagePost()
            self.sendButton.isEnabled = true
            self.imageView.isUserInteractionEnabled = true
        }
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
    
    func unwindToHome() {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - ImagePicker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.imageView.image = selectedImage
            self.imageView.backgroundColor = .black
        } else {
            print("Oops")
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
        self.imageView.image = self.image
    }
    
    func selectPicSource() {
        self.dismissKeyboard()
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let takeSelfieAction = UIAlertAction(title: "Camera", style: .default, handler: { action in
                imagePicker.sourceType = .camera
                imagePicker.cameraCaptureMode = .photo
                imagePicker.cameraDevice = .rear
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(takeSelfieAction)
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let choosePhotoLibraryAction = UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { action in
                imagePicker.sourceType = .photoLibrary
                self.present(imagePicker, animated: true, completion: nil)
            })
            alertController.addAction(choosePhotoLibraryAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.view.tintColor = misc.nativColor
        present(alertController, animated: true, completion: nil)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
        textView.textAlignment = .left
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.textColor == UIColor.black && textView.text != "" {
            self.sendButton.isEnabled = true
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
            textView.text = "post..."
            self.sendButton.isEnabled = false
            textView.textColor = UIColor.lightGray
            self.characterCountLabel.isHidden = true
            textView.textAlignment = .center
        }
    }
    
    func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            var contentInset: UIEdgeInsets = self.scrollView.contentInset
            contentInset.bottom = keyboardSize.size.height + 8
            self.scrollView.contentInset = contentInset
        }
    }
    
    func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            var contentInset: UIEdgeInsets = self.scrollView.contentInset
            contentInset.bottom = keyboardSize.size.height + 8
            self.scrollView.contentInset = contentInset
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        self.scrollView.contentInset = contentInset
    }
    
    // MARK: - Notifications
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.unwindToHome), name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
    }
    
    // MARK: - Misc
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.sendButton.isEnabled = true
            self.activityView.removeFromSuperview()
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
    
    func logViewImagePost() {
        FIRAnalytics.logEvent(withName: "logViewImagePost", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "segment": self.segment as NSObject,
            ])
    }
    
    func logPondPostSent(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "pondPostSent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "longitude": self.longitude as NSObject,
            "latitude": self.latitude as NSObject
            ])
    }
    
    func logAnonPostSent(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "anonPostSent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "longitude": self.longitude as NSObject,
            "latitude": self.latitude as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func writePostSent (_ postID: Int, postContent: String, tags: [String], imageURL: URL) {
        if self.segment == "pond" {
            let pondRef = self.ref.child("posts").child("\(postID)")
            pondRef.child("longitude").setValue(self.longitude)
            pondRef.child("latitude").setValue(self.latitude)
            pondRef.child("points").setValue(0)
            pondRef.child("tags").setValue(tags)
            pondRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0, "imageURL": imageURL])
            
            let myPondRef = self.ref.child("users").child(self.myIDFIR).child("posts").child("\(postID)")
            myPondRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
        } else {
            let anonRef = self.ref.child("anonPosts").child("\(postID)")
            anonRef.child("longitude").setValue(self.longitude)
            anonRef.child("latitude").setValue(self.latitude)
            anonRef.child("points").setValue(0)
            anonRef.child("tags").setValue(tags)
            anonRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0, "imageURL": imageURL])
            
            let myAnonRef = self.ref.child("users").child(self.myIDFIR).child("anonPosts").child("\(postID)")
            myAnonRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
        }
    }
    
    // MARK: - AWS
    
    func setImagePost(_ postID: Int, postContent: String, imageURL: URL) -> [String:Any] {
        var picURL: URL
        if let url = UserDefaults.standard.url(forKey: "myPicURL.nativ") {
            picURL = url
        } else {
            picURL = URL(string: "https://hostpostuserprof.s3.amazonaws.com/default_small")!
        }
        let myName: String
        let myHandle: String
        
        if let name = UserDefaults.standard.string(forKey: "myFullName.nativ") {
            myName = name
        } else {
            myName = "Me"
        }
        
        if let handle = UserDefaults.standard.string(forKey: "myHandle.nativ") {
            myHandle = handle
        } else {
            myHandle = "Me"
        }
        
        var post: [String:Any] = ["postID": postID, "userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "pointsCount": 0, "didIVote": "no", "imageURL": imageURL, "replyCount": 0, "shareCount": 0, "longitude": self.longitude, "latitude": self.latitude]
        if self.segment == "pond" {
            post["userName"] = myName
            post["userHandle"] = myHandle
            post["picURL"] = picURL
        }
        
        return post
    }
    
    func uploadPic(_ picData: Data, url: URL, bucket: String, key: String, completion: @escaping (_ success:Bool) -> Void) {
        var picSized: UIImage!
        let picImage = UIImage(data: picData)
        let sourceWidth = picImage!.size.width
        let sourceHeight = picImage!.size.height
        
        var scaleFactor: CGFloat!
        if sourceWidth > sourceHeight {
            scaleFactor = 750/sourceWidth
        } else {
            scaleFactor = 750/sourceHeight
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
            if let errorNoNS = task.error {
                let error = errorNoNS as NSError
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
            completion(true)
            return nil
        })
    }
    
    func sendPost() {
        self.displayActivity("uploading...", indicator: true)
        
        if self.textView.text == "" || self.textView.textColor == .lightGray {
            self.displayAlert("No Text Set", alertMessage: "Please include text with your pic")
            return
        }
        
        if self.longitude == 200 || self.latitude == 200 {
            self.displayAlert("No Location", alertMessage: "We couldn't seem to find your posting location. Please go back to the Flow and try to set your location again. If this bug persists, let us know in the report bug section of the menu.")
            return
        }
        
        self.imageView.isUserInteractionEnabled = false
        var picData: Data!
        if self.imageView.image == UIImage(named: "addPicSelected") || self.imageView.image == UIImage(named: "addPicUnselected") {
            self.displayAlert("Pic Not Set", alertMessage: "Please tap the pic icon to add a picture")
            return
        } else {
            picData = UIImageJPEGRepresentation(self.imageView.image!, 1)
        }
        
        let postID: Int = 0
        let postContent: String = self.textView.text
        let handles = misc.handlesWithoutAt(postContent)
        let tags = misc.tagsWithoutDot(postContent)
        let isPicSet: String = "yes"
        
        if self.segment == "anon" && !handles.isEmpty {
            self.displayAlert("No user tags in anon posts", alertMessage: "You cannot tag a user in an anonymous post. Please remove the text mentioning the user before posting.")
            return
        }
        
        self.dismissKeyboard()
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            var sendURL: URL!
            if self.segment == "pond" {
                sendURL = URL(string: "https://dotnative.io/sendPondPost")
            } else {
                sendURL = URL(string: "https://dotnative.io/sendAnonPondPost")
            }
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            var sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&postContent=\(postContent)&isPicSet=\(isPicSet)&longitude=\(self.longitude)&latitude=\(self.latitude)"
            if !handles.isEmpty {
                sendString.append("&userHandles=\(handles)")
            }
            if !tags.isEmpty {
                sendString.append("&tags=\(tags)")
            }
            
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
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your post has not been sent. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                if let newPostID = parseJSON["postID"] as? Int {
                                    let imageBucket = parseJSON["imageBucket"] as! String
                                    let imageKey = parseJSON["imageKey"] as! String
                                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempPostPic.nativ")
                                    self.uploadPic(picData, url: tempURL, bucket: imageBucket, key: imageKey) {(success) -> Void in
                                        self.activityView.removeFromSuperview()
                                        let post = self.setImagePost(newPostID, postContent: postContent, imageURL: tempURL)
                                        self.sendImagePostDelegate?.insertImagePost(post)
                                        
                                        if self.segment == "pond" {
                                            self.logPondPostSent(newPostID)
                                        } else {
                                            self.logAnonPostSent(newPostID)
                                        }
                                        self.textView.text = ""
                                        let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                        self.writePostSent(newPostID, postContent: postContent, tags: tags, imageURL: imageURL)
                                        SDWebImagePrefetcher.shared().prefetchURLs([imageURL])
                                        self.unwindToHome()
                                    }
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug by going to the report section in the menu if this persists.")
            return
        }
    }
    
}

protocol SendImagePostProtocol: class {
    func insertImagePost(_ post: [String:Any])
}

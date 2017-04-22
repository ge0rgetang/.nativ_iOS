//
//  EditPostPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift

class EditPostPopViewController: UIViewController, UITextViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = UserDefaults.standard.integer(forKey: "myID.nativ")
    var myIDFIR: String = UserDefaults.standard.string(forKey: "myIDFIR.nativ")!
    var userIDFIR: String = "-2"
    var postID: Int = -2
    var postSubID: Int = -2
    var poolID: Int = -2
    var chapterID: Int = -2
    var postType: String = "pond"
    var postSubType: String = "parent"
    var postContent: String = "n/a"
    let misc = Misc()
    
    var post: [String:Any] = [:]
    
    var ref = FIRDatabase.database().reference()
    
    weak var editPostDelegate: EditPostProtocol?
    
    @IBOutlet weak var postContentTextView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    
    @IBOutlet weak var confirmButton: UIButton!
    @IBAction func confirmButtonTapped(_ sender: AnyObject) {
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
        self.confirmButton.isEnabled = false
        self.editPost()
    }
    @IBAction func confirmButtonDown(_ sender: Any) {
        misc.colorButton(self.confirmButton, event: "down", view: self.view)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredContentSize = CGSize(width: 320, height: 75)
        
        misc.makeButtonFancy(self.confirmButton, title: "Confirm", view: self.view)
        
        self.postContentTextView.delegate = self
        self.characterCountLabel.isHidden = true
        self.postContentTextView.layer.cornerRadius = 5
        self.postContentTextView.layer.borderColor = UIColor.lightGray.withAlphaComponent(1).cgColor
        self.postContentTextView.layer.borderWidth = 0.5
        self.postContentTextView.clipsToBounds = true
        self.postContentTextView.autocorrectionType = .default
        self.postContentTextView.spellCheckingType = .default
        self.postContentTextView.text = self.postContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        self.confirmButton.isEnabled = true
        self.logViewEditPost()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let preferredHeight = self.postContentTextView.bounds.height + self.confirmButton.frame.size.height + 24
        if self.postType == "chapter" {
            self.preferredContentSize = CGSize(width: 300, height: preferredHeight)
        } else {
            self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
        }
        self.postContentTextView.becomeFirstResponder()
        misc.colorButton(self.confirmButton, event: "up", view: self.view)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
            self.resizeView()
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.textColor == UIColor.black && textView.text != "" {
            self.confirmButton.isEnabled = true
        }
        
        self.resizeView()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentLength = textView.text.characters.count + (text.characters.count - range.length)
        var charactersLeft = 191 - currentLength
        if charactersLeft < 0 {
            charactersLeft = 0
        }
        
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
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
            textView.text = "edit your post"
            textView.textColor = UIColor.lightGray
            self.characterCountLabel.isHidden = true
            self.confirmButton.isEnabled = false
        }
    }
    
    // MARK: - Misc
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
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
        let fixedWidth: CGFloat = self.postContentTextView.frame.size.width
        let newSize = self.postContentTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT)))
        var newFrame = self.postContentTextView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: min(newSize.height, maxHeight))
        self.postContentTextView.frame = newFrame
        UIView.animate(withDuration: 0.1, animations: {
            let preferredHeight = self.postContentTextView.bounds.height + self.confirmButton.frame.size.height + 24
            self.preferredContentSize = CGSize(width: 320, height: preferredHeight)
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: - Analytics
    
    func logViewEditPost() {
        if self.postSubType == "reply" {
            FIRAnalytics.logEvent(withName: "viewEditReplyPost", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postSubID as NSObject,
                "postType": self.postType as NSObject,
                ])
        } else {
            FIRAnalytics.logEvent(withName: "viewEditParentPost", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postID as NSObject,
                "postType": self.postType as NSObject,
                ])
        }
    }
    
    func logEditPondPost() {
        if self.postSubType == "reply" {
            FIRAnalytics.logEvent(withName: "pondReplyPostEdited", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postSubID as NSObject
                ])
        } else {
            FIRAnalytics.logEvent(withName: "pondParentPostEdited", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postID as NSObject
                ])
        }
    }
    
    func logEditAnonymousPondPost() {
        if self.postSubType == "reply" {
            FIRAnalytics.logEvent(withName: "anonymousReplyPondPostEdited", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postSubID as NSObject
                ])
        } else {
            FIRAnalytics.logEvent(withName: "anonymousParentPondPostEdited", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postID as NSObject
                ])
        }
    }
    
    // MARK: Firebase
    
    func editPostFIR(_ postContent: String) {
        switch self.postType {
        case "pond":
            if self.postSubType == "reply" {
                let ref = self.ref.child("posts").child("\(self.postID)").child("\(self.postSubID)")
                ref.child("postContent").setValue(postContent)
                ref.child("timestamp").setValue(misc.getTimestamp("UTC"))
            } else {
                let ref = self.ref.child("posts").child("\(self.postID)").child("parent")
                ref.child("postContent").setValue(postContent)
                ref.child("timestamp").setValue(misc.getTimestamp("UTC"))
            }
            
        case "anon":
            if self.postSubType == "reply" {
                let ref = self.ref.child("anonPosts").child("\(self.postID)").child("\(self.postSubID)")
                ref.child("postContent").setValue(postContent)
                ref.child("timestamp").setValue(misc.getTimestamp("UTC"))
            } else {
                let ref = self.ref.child("anonPosts").child("\(self.postID)").child("parent")
                ref.child("postContent").setValue(postContent)
                ref.child("timestamp").setValue(misc.getTimestamp("UTC"))
            }
            
        default:
            return
        }
    }
    
    // MARK: AWS
    
    fileprivate func editPost() {
        self.dismissKeyboard()
        
        let action: String = "edit"
        
        let newContent: String! = self.postContentTextView.text
        if newContent.isEmpty || self.postContentTextView.textColor == UIColor.lightGray {
            self.displayAlert("Invalid Content", alertMessage: "Please fill the empty field.")
            return
        }
        
        self.editPostFIR(newContent!)
        self.editPostDelegate?.updatePost(newContent!)
        self.dismiss(animated: true, completion: nil)
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/editPost")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(self.postID)&action=\(action)&postType=\(self.postType)&newContent=\(newContent!)"
            
            sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.postContentTextView.text = "Cannot connect to the internet"
                    self.postContentTextView.textColor = .red
                }
                
                do{
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.postContentTextView.text = "We messed up. Please report this bug in the report section of the menu."
                                self.postContentTextView.textColor = .red
                                return
                            }
                            
                            if status == "success" {
                                switch self.postType {
                                case "pond":
                                    self.logEditPondPost()
                                case "anon":
                                    self.logEditAnonymousPondPost()
                                default:
                                    return
                                }
                            }
                            
                        })
                    }
                    
                } catch {
                    self.postContentTextView.text = "We're updating our servers. Please try again later"
                    self.postContentTextView.textColor = .red
                    print(error)
                }
                
            }
            
            task.resume()
            
        } catch {
            self.postContentTextView.text = "Token error. Please report this bug in the report section of the menu."
            self.postContentTextView.textColor = .red
        }
    }
    
}

protocol EditPostProtocol: class {
    func updatePost(_ postContent: String)
}


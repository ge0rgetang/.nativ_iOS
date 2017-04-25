//
//  ChatViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift
import SDWebImage

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    var userID: Int = -2
    var userIDFIR: String = "-2"
    var chatID: String = "-2"
    var firstLoad: Bool = true
    var firstLoadNoContent: Bool = true
    var scrollPosition: String = "top"
    var isFriend: String = "Z"
    var picURL: URL = URL(string: "https://static.pexels.com/photos/101584/pexels-photo-101584.jpeg")!
    
    var segueSender: String = "list"
    var userHandle: String = "blank"
    
    var messageIDArray: [Int] = []
    var heightAtIndexPath: [IndexPath:CGFloat] = [:]
    var chatMessages: [[String:Any]] = []
    var amITyping: Bool = false
    var isTyping: Bool = false {
        didSet {
            if self.isTyping != oldValue {
                self.showTyping()
            }
        }
    }
    
    let misc = Misc()
    var backButton = UIButton()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var chatTableView: UITableView!
    
    @IBOutlet weak var typingLabelView: UIView!
    @IBOutlet weak var typingLabel: UILabel!
    @IBOutlet weak var typingLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var userInputTextViewBottom: NSLayoutConstraint!
    @IBOutlet weak var dotLabelHeight: NSLayoutConstraint!
    
    @IBOutlet weak var userInputTextView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: AnyObject) {
        self.sendButton.isEnabled = false
        if let chatMessage = self.userInputTextView.text {
            self.sendMessage(chatMessage)
        } else {
            self.displayAlert("No message", alertMessage: "Please send a message")
            return
        }
    }
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.characterCountLabel.isHidden = true
        self.sendButton.isEnabled = false
        
        if self.segueSender == "userProfile" && self.isFriend == "F" {
            self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
            let swipeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeRight))
            swipeRight.direction = .right
            self.chatTableView.addGestureRecognizer(swipeRight)
        }
        
        self.typingLabelView.alpha = 0
        self.typingLabel.alpha = 0
        self.typingLabelHeight.constant = 0
        self.dotLabelHeight.constant = 0
        self.typingLabelView.layer.cornerRadius = 4.2
        
        self.chatTableView.delegate = self
        self.chatTableView.dataSource = self
        self.chatTableView.rowHeight = UITableViewAutomaticDimension
        self.chatTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.chatTableView.backgroundColor = UIColor.white
        self.chatTableView.showsVerticalScrollIndicator = false
        
        self.userInputTextView.delegate = self
        self.userInputTextView.isScrollEnabled = false
        self.userInputTextView.textColor = UIColor.lightGray
        self.userInputTextView.font = UIFont.systemFont(ofSize: 14)
        self.userInputTextView.layer.cornerRadius = 5
        self.userInputTextView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        self.userInputTextView.layer.borderWidth = 0.5
        self.userInputTextView.clipsToBounds = true
        self.userInputTextView.layer.masksToBounds = true
        self.userInputTextView.autocorrectionType = .default
        self.userInputTextView.spellCheckingType = .default
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.chatTableView.addGestureRecognizer(tap)
        
        self.setRetainedNotifications()
        
        self.chatTableView.transform = CGAffineTransform(scaleX: 1, y: -1)
        if self.segueSender == "userProfile" {
            self.setBackButton()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.firstLoad = true
        self.setNotifications()
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            self.unwindToHome()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
        } else {
            self.writeChatID()
            self.observeForChats()
            self.logViewChat()
            if self.segueSender == "notification" {
                self.segueSender = "list"
                self.segmentedControl.isHidden = true
                self.navigationItem.title = self.userHandle
            } else {
                if self.isFriend == "F" {
                    self.segmentedControl.isHidden = false
                    self.segmentedControl.selectedSegmentIndex = 1
                    self.navigationItem.titleView = self.segmentedControl
                    self.segmentedControl.sizeToFit()
                    self.navigationItem.title = self.userHandle
                    self.writeInConversation(true)
                    if self.userInputTextView.text != "" && self.userInputTextView.textColor != .lightGray {
                        self.sendButton.isEnabled = true
                    }
                }
                if self.isFriend == "B" || self.isFriend == "BB" {
                    self.sendButton.isEnabled = false
                    self.userInputTextView.isUserInteractionEnabled = false
                    self.segmentedControl.isHidden = true
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if self.isFriend == "B" || self.isFriend == "BB" {
            self.userInputTextView.text = "disabled"
            self.userInputTextView.textColor = .lightGray
        } else if self.chatMessages.isEmpty {
            self.userInputTextView.text = "start a conversation"
            self.userInputTextView.textColor = .lightGray
        } else {
            if self.userInputTextView.text == "" {
                self.userInputTextView.text = "send a message"
                self.userInputTextView.textColor = .lightGray
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        self.removeObserverForChats()
        self.writeInConversation(false)
        self.dismissKeyboard()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.removeObserverForChats()
        self.writeInConversation(false)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.messageIDArray = []
        self.chatMessages = []
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        misc.clearWebImageCache()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.chatMessages.isEmpty || self.isFriend == "B" || self.isFriend == "BB" {
            return 1
        }
        
        return self.chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.chatMessages.isEmpty || self.isFriend == "B" || self.isFriend == "BB"  {
            let cell = chatTableView.dequeueReusableCell(withIdentifier: "noChatsCell") as! NoContentTableViewCell
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.textColor = .lightGray
            cell.noContentLabel.sizeToFit()
            if self.firstLoad {
                cell.noContentLabel.text = "loading..."
            } else if self.isFriend == "B" {
                cell.noContentLabel.text = "You have been blocked by this person."
            } else if self.isFriend == "BB" {
                cell.noContentLabel.text = "You have blocked this person."
            } else {
                cell.noContentLabel.text = "Send a message or swipe to see their profile."
            }
            if self.firstLoadNoContent {
                cell.alpha = 0
                UIView.animate(withDuration: 0.25, animations: {
                    cell.alpha = 1
                })
                self.firstLoadNoContent = false
            }
            cell.transform = CGAffineTransform(scaleX: 1, y: -1)
            
            return cell
        }
        
        let individualMessage = self.chatMessages[indexPath.row]
        
        var cell: ChatTableViewCell
        let userID = individualMessage["userID"] as! Int
        if userID == self.myID {
            cell = self.chatTableView.dequeueReusableCell(withIdentifier: "sentChatCell") as! ChatTableViewCell
        } else {
            cell = self.chatTableView.dequeueReusableCell(withIdentifier: "receivedChatCell") as! ChatTableViewCell
            cell.userPicImageView.sd_setImage(with: self.picURL)
            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
        }
        
        cell.chatMessageLabel.text = individualMessage["chatMessage"] as? String
        cell.timestampLabel.text = individualMessage["timestamp"] as? String
        cell.timestampLabel.backgroundColor = UIColor.white
        
        cell.whiteView.sizeToFit()
        cell.whiteView.layer.masksToBounds = true
        cell.whiteView.layer.cornerRadius = 4.2
        cell.chatMessageLabel.numberOfLines = 0
        cell.chatMessageLabel.sizeToFit()
        
        let messageID = individualMessage["messageID"] as! Int
        if !self.messageIDArray.contains(messageID) {
            cell.alpha = 0
            UIView.animate(withDuration: 0.25, animations: {
                cell.alpha = 1
            })
            self.messageIDArray.append(messageID)
        }
        
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let height = cell.frame.size.height
        self.heightAtIndexPath.updateValue(height, forKey: indexPath)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !self.firstLoad {
            if let height = self.heightAtIndexPath[indexPath] {
                return height
            } else {
                return UITableViewAutomaticDimension
            }
        }
        
        return UITableViewAutomaticDimension
    }
    
    // MARK: - Navigation
    
    func unwindToNotifications() {
        self.performSegue(withIdentifier: "unwindFromChatToNotifications", sender: self)
    }
    
    func unwindToFriendList() {
        self.performSegue(withIdentifier: "unwindFromChatToFriendList", sender: self)
    }
    
    func unwindToHome() {
        if self.segueSender == "notification" {
            self.unwindToNotifications()
        } else {
            self.unwindToFriendList()
        }
    }
    
    func setIsFriendN() {
        if self.segueSender == "userProfile" {
            self.isFriend = "N"
            self.userInputTextView.text = "send a message"
            self.userInputTextView.textColor = .lightGray
            self.chatTableView.reloadData()
        }
    }
    
    func setIsFriendBB() {
        if self.segueSender == "userProfile" {
            self.isFriend = "BB"
            self.userInputTextView.text = "disabled"
            self.userInputTextView.textColor = .lightGray
            self.chatTableView.reloadData()
        }
    }
    
    func swipeRight() {
        if self.isFriend == "F" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToUserProfile"), object: nil)
        }
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
        textView.font = UIFont.systemFont(ofSize: 18)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.textColor == UIColor.black && textView.text != "" {
            self.sendButton.isEnabled = true
        } else {
            self.sendButton.isEnabled = false
        }
        
        if textView.text == "" {
            self.writeAmITyping(false)
            self.amITyping = false
        } else {
            if self.amITyping != true {
                self.writeAmITyping(true)
                self.amITyping = true
            }
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
            textView.text = "send a message"
            textView.textColor = UIColor.lightGray
            textView.font = UIFont.systemFont(ofSize: 14)
            self.characterCountLabel.isHidden = true
            self.sendButton.isEnabled = false
        }
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        if offset <= 420 {
            self.scrollToTopButton.removeFromSuperview()
        }
        
        if offset == 0 {
            self.scrollPosition = "top"
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if self.chatMessages.count >= 42 {
                self.getChatMessages()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
    }
    
    // MARK: - Sort Options
    
    func sortCriteriaDidChange(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToUserProfile"), object: nil)
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.userInputTextViewBottom.constant == 8 {
                self.userInputTextViewBottom.constant += keyboardSize.height
                UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
            }
        }
    }
    
    func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.userInputTextViewBottom.constant = 8 + keyboardSize.height
            UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if self.userInputTextViewBottom.constant != 8 {
            self.userInputTextViewBottom.constant = 8
            UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
        }
    }
    
    // MARK: - Notifications
    
    func setRetainedNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.setIsFriendN), name: NSNotification.Name(rawValue: "setIsFriendN"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setIsFriendBB), name: NSNotification.Name(rawValue: "setIsFriendBB"), object: nil)
    }
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForChats), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.unwindToHome), name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "uunwindToHome"), object: nil)
    }
    
    // MARK: - Misc
    
    func displayAlert(_ alertTitle: String, alertMessage: String) {
        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.activityView.removeFromSuperview()
            self.scrollToTopButton.removeFromSuperview()
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
        
        self.addScrollToTop()
    }
    
    func addScrollToTop() {
        self.scrollToTopButton.removeFromSuperview()
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.chatTableView.frame.size.height, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: "down")
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.chatTableView.setContentOffset(.zero, animated: true)
        self.scrollToTopButton.removeFromSuperview()
    }
    
    func colorTopButtonDown() {
        self.scrollToTopButton.backgroundColor = misc.nativSemiFade
    }
    
    func colorTopButtonUp() {
        self.scrollToTopButton.backgroundColor = UIColor(white: 0, alpha: 0.025)
    }
    
    func showTyping() {
        if self.isTyping {
            UIView.animate(withDuration: 0.25, animations: {
                self.typingLabelView.alpha = 1
                self.typingLabel.alpha = 1
                self.typingLabelHeight.constant = 32
                self.dotLabelHeight.constant = 24
                self.typingLabelView.layoutIfNeeded()
                self.typingLabel.layoutIfNeeded()
                self.chatTableView.layoutIfNeeded()
            })
            
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear, animations: {
                self.typingLabelView.alpha = 0
                self.typingLabel.alpha = 0
                self.typingLabelView.layoutIfNeeded()
                self.typingLabel.layoutIfNeeded()
            }, completion: { (finished:Bool) in
                if finished {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.typingLabelHeight.constant = 0
                        self.dotLabelHeight.constant = 0
                        self.chatTableView.layoutIfNeeded()
                    })
                }
            })
        }
    }
    
    func setBackButton() {
        self.backButton.setImage(UIImage(named: "backButton"), for: .normal)
        self.backButton.setTitle(" Added", for: .normal)
        self.backButton.addTarget(self, action: #selector(self.unwindToFriendList), for: .touchUpInside)
        self.backButton.setTitleColor(misc.nativColor, for: .normal)
        self.backButton.sizeToFit()
        self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: self.backButton), animated: false)
    }
    
    func setTempPost(_ chatMessage: String) {
        let chat: [String:Any] = ["userID": self.myID, "chatMessage": chatMessage, "messageID": -1, "timestamp": self.misc.getTimestamp("mine")]
        self.chatMessages.insert(chat, at: 0)
        self.chatTableView.reloadData()
    }
    
    // MARK: - Analytics
    
    func logViewChat() {
        FIRAnalytics.logEvent(withName: "viewChat", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logSentMessage() {
        FIRAnalytics.logEvent(withName: "chatSent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func observeForChats() {
        self.removeObserverForChats()
        
        let chatRef = self.ref.child("chats").child(self.chatID).child("messages")
        chatRef.observe(.value, with: { (snapshot) -> Void in
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            self.perform(#selector(self.getChatMessages), with: nil, afterDelay: 0.05)
        })
        
        let isTypingRef = self.ref.child("chats").child(self.chatID).child("\(self.userID)_typing")
        isTypingRef.observe(.value, with: { (snapshot) -> Void in
            if let value = snapshot.value as? Bool {
                self.isTyping = value
            }
        })
    }
    
    func removeObserverForChats() {
        let chatRef = self.ref.child("chats").child(self.chatID).child("messages")
        chatRef.removeAllObservers()
        
        let isTypingRef = self.ref.child("chats").child(self.chatID).child("\(self.userID)_typing")
        isTypingRef.removeAllObservers()
    }
    
    func writeChatID() {
        let userRef = self.ref.child("users")
        userRef.child(self.myIDFIR).child("friendList").child("chats").child(self.chatID).setValue(true)
        
        let chatRef = self.ref.child("chats").child(self.chatID)
        chatRef.child(self.myIDFIR).setValue(true)
        chatRef.child(self.userIDFIR).setValue(true)
        chatRef.child("\(self.userID)_typing").setValue(false)
        chatRef.child("\(self.myID)_typing").setValue(false)
    }
    
    func writeChatMessage(_ message: String, messageID: Int) {
        let userRef = self.ref.child("users")
        userRef.child(self.userIDFIR).child("friendList").child("lastMessage").setValue(["userID": self.myID, "message": message])
        
        let chatRef = self.ref.child("chats").child(self.chatID).child("messages")
        chatRef.child("\(messageID)").setValue(["message": message, "timestamp": misc.getTimestamp("UTC"), "senderID": self.myID])
        
        self.writeAmITyping(false)
        self.amITyping = false
    }
    
    func writeAmITyping(_ amITyping: Bool) {
        let amITypingRef = self.ref.child("chats").child(self.chatID).child("\(self.myID)_typing")
        amITypingRef.setValue(amITyping)
    }
    
    func writeInConversation(_ amIInConversation: Bool) {
        let inConversationRef = self.ref.child("chats").child(self.chatID).child("\(self.myID)_inConversation")
        inConversationRef.setValue(amIInConversation)
        
        if amIInConversation {
            UserDefaults.standard.set(self.chatID, forKey: "currentChatID.nativ")
            UserDefaults.standard.synchronize()
        } else {
            UserDefaults.standard.removeObject(forKey: "currentChatID.nativ")
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: AWS
    
    func sendMessage (_ chatMessage: String) {
        self.setTempPost(chatMessage)
        self.userInputTextView.text = ""
        self.dismissKeyboard()
        self.characterCountLabel.isHidden = true
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/sendChat")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(self.userID)&chatMessage=\(chatMessage)"
            
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your message may not have been sent. Please report the bug in by going to the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                self.logSentMessage()
                                if let messageID = parseJSON["chatID"] as? Int {
                                    self.messageIDArray.append(messageID)
                                    self.writeChatMessage(chatMessage, messageID: messageID)
                                    self.chatTableView.reloadData()
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in by going to the report section of the menu.")
            return
        }
    }
    
    func getChatMessages() {
        var lastMessageID: Int = 0
        if self.scrollPosition == "bottom" && self.chatMessages.count >= 42 {
            let lastMessage = self.chatMessages.last!
            lastMessageID = lastMessage["messageID"] as! Int
            self.displayActivity("going back in time...", indicator: true)
        } else {
            lastMessageID = 0
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let getChatURL = URL(string: "https://dotnative.io/getChat")
            var getChatRequest = URLRequest(url: getChatURL!)
            getChatRequest.httpMethod = "POST"
            
            let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(self.userID)&lastChatID=\(lastMessageID)"
            
            getChatRequest.httpBody = getString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: getChatRequest as URLRequest) {
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
                            self.activityView.removeFromSuperview()
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load your chat messages. Please report the bug in by going to the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                let userHandle = parseJSON["userHandle"] as! String
                                self.userHandle = "@\(userHandle)"
                                
                                if let chatsArray = parseJSON["chats"] as? [[String:Any]] {
                                    var chats: [[String:Any]] = []
                                    for individualMessage in chatsArray {
                                        let userID = individualMessage["userID"] as! Int
                                        let messageID = individualMessage["chatID"] as! Int
                                        let chatMessage = individualMessage["chatMessage"] as! String
                                        
                                        let time = individualMessage["timestamp"] as! String
                                        let timestamp = self.misc.formatTimestamp(time)
                                        
                                        let chat: [String:Any] = ["userID": userID, "messageID": messageID, "chatMessage": chatMessage, "timestamp": timestamp]
                                        chats.append(chat)
                                    }
                                    
                                    if lastMessageID != 0 {
                                        let latestMessage = chats.last!
                                        if lastMessageID != latestMessage["messageID"] as! Int {
                                            self.chatMessages.append(contentsOf: chats)
                                            if self.chatMessages.count > 210 {
                                                let difference = self.chatMessages.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.chatMessages = self.chatMessages.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.chatMessages = chats
                                    }
                                }
                                
                                self.firstLoad = false
                                self.chatTableView.reloadData()
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in by going to the report section of the menu.")
            return
        }
    }
    
    func refreshWithDelay() {
        self.perform(#selector(self.observeForChats), with: nil, afterDelay: 0.5)
    }
}

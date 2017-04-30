//
//  DropViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import SDWebImage
import CryptoSwift
import FBSDKShareKit
import TwitterKit

class DropViewController: UIViewController, UITextViewDelegate, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate, EditPostProtocol {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var scrollPosition: String = "top"
    var firstLoad: Bool = true
    var parentRow: Int = -2
    var isRemoved: Bool = false
    var isKeyboardUp: Bool = false
    var isEditingPost: Bool = false
    var segueSender: String = "pondList"
    var lastContentOffset: CGFloat = 0
    
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var userHandleToPass: String = "-2"
    var imageURLToPass: URL!
    var postContentToPass: String!
    var fromHandle: Bool = false
    
    var newPostsCount: Int = 0
    var postIDArray: [Int] = []
    var urlArray: [URL] = []
    var heightAtIndexPath: [IndexPath:CGFloat] = [:]
    var replyPosts: [[String:Any]] = []
    var parentPost: [String:Any] = [:]
    var postID: Int = -2
    var isAnon: Bool = false
    
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    var dimView = UIView()
    
    weak var editPondParentDelegate: EditPondParentProtocol?
    
    var ref = FIRDatabase.database().reference()
    
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    
    @IBOutlet weak var dropTableView: UITableView!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        if self.textView.textColor == .black && self.textView.text != "" {
            self.sendReply()
        }
    }
    
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Drop"
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.dropTableView.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        self.dropTableView.delegate = self
        self.dropTableView.dataSource = self
        self.dropTableView.rowHeight = UITableViewAutomaticDimension
        self.dropTableView.sectionHeaderHeight = UITableViewAutomaticDimension
        self.dropTableView.backgroundColor = .white
        self.dropTableView.showsVerticalScrollIndicator = true
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.dropTableView.addSubview(refreshControl)
        
        self.settingsButton.setImage(UIImage(named: "settingsUnselected"), for: .normal)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .selected)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .highlighted)
        self.settingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.settingsButton.addTarget(self, action: #selector(self.presentParentOptions), for: .touchUpInside)
        self.settingsBarButton.customView = self.settingsButton
        self.navigationItem.rightBarButtonItem = self.settingsBarButton
        
        self.textView.delegate = self
        self.textView.text = "reply..."
        self.textView.textColor = .lightGray
        self.textView.font = UIFont.systemFont(ofSize: 14)
        self.textView.isScrollEnabled = false
        self.textView.layer.cornerRadius = 5
        self.textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        self.textView.layer.borderWidth = 0.5
        self.textView.clipsToBounds = true
        self.textView.layer.masksToBounds = true
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .default
        self.sendButton.isEnabled = false
        self.characterCountLabel.isHidden = true
        
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.dropTableView.addSubview(self.dimView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
            self.textView.isUserInteractionEnabled = false
            self.textView.text = "Sign in to reply!"
            self.textView.textColor = .lightGray
            self.sendButton.isEnabled = false
        } else {
            self.textView.isUserInteractionEnabled = true
            self.writeInPostID(self.postID)
        }
        
        self.logViewDrop()
        self.observeReplies()
        self.setNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.dropTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        self.removeObserverForReplies()
        self.dismissKeyboard()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if self.myID > 0 {
            self.writeInPostID(0)
        }
        if let url = self.imageURLToPass {
            SDWebImagePrefetcher.shared().prefetchURLs([url])
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.removeObserverForReplies()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        misc.clearWebImageCache()
        self.clearArrays()
        self.observeReplies()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.parentPost.isEmpty {
            return 1
        }
        
        if self.replyPosts.count == 1 || (!self.parentPost.isEmpty && self.replyPosts.isEmpty) {
            return 2
        }
        
        return self.replyPosts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.parentPost.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "anonReplyCell") as! PostTableViewCell
            if self.firstLoad {
                cell.postContentTextView.text = "loading..."
            } else {
                cell.postContentTextView.text = "Uhh we messed up :( Please try again, or report this issue in the report section of the menu."
            }
            return cell
        }
        
        if !self.parentPost.isEmpty && indexPath.row == 0 {
            var cell: PostTableViewCell
            let individualPost = self.parentPost
            let userID = individualPost["userID"] as! Int
            let didIVote = individualPost["didIVote"] as! String
            let postContent = individualPost["postContent"] as! String

            if let handle = individualPost["userHandle"] as? String {
                if let imageURL = individualPost["imageURL"] as? URL {
                    cell = tableView.dequeueReusableCell(withIdentifier: "pondHeaderImageCell") as! PostTableViewCell
                    let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                        cell.postImageView.image = image
                        cell.setNeedsLayout()
                    }
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.postImageView.sd_setImage(with: imageURL, placeholderImage: nil, options: .progressiveDownload, completed: block)
                    let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                    cell.postImageView.addGestureRecognizer(tapToViewImage)
                } else {
                    cell = tableView.dequeueReusableCell(withIdentifier: "pondHeaderCell") as! PostTableViewCell
                }
                
                cell.contentView.backgroundColor = .white
                cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
                cell.userPicImageView.clipsToBounds = true
                let picURL = self.parentPost["picURL"] as! URL
                cell.userPicImageView.sd_setImage(with: picURL)
                cell.userNameLabel.text = self.parentPost["userName"] as? String
                cell.userHandleLabel.text = "@\(handle)"
                cell.postContentTextView.attributedText = misc.stringWithColoredTags(postContent, time: "default", fontSize: 18, timeSize: 18)

                if userID != self.myID && self.myID > 0 {
                    let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfileFromParent))
                    let tapNameToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfileFromParent))
                    let tapHandleToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfileFromParent))
                    cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
                    cell.userNameLabel.addGestureRecognizer(tapNameToViewUser)
                    cell.userHandleLabel.addGestureRecognizer(tapHandleToViewUser)
                }
                
            } else {
                if let imageURL = self.parentPost["imageURL"] as? URL {
                    cell = tableView.dequeueReusableCell(withIdentifier: "anonHeaderImageCell") as! PostTableViewCell
                    let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                        cell.postImageView.image = image
                        cell.setNeedsLayout()
                    }
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.postImageView.sd_setImage(with: imageURL, placeholderImage: nil, options: .progressiveDownload, completed: block)
                    let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                    cell.postImageView.addGestureRecognizer(tapToViewImage)
                } else {
                    cell = tableView.dequeueReusableCell(withIdentifier: "anonHeaderCell") as! PostTableViewCell
                }
                cell.contentView.backgroundColor = .white
                cell.postContentTextView.attributedText = misc.anonStringWithColoredTags(postContent, time: "default", fontSize: 18, timeSize: 18)
            }
            
            if userID != self.myID {
                cell.actionButton.setImage(UIImage(named: "upvoteUnselected"), for: .normal)
                cell.actionButton.setImage(UIImage(named: "upvoteSelected"), for: .selected)
                cell.actionButton.setImage(UIImage(named: "upvoteSelected"), for: .highlighted)
                if didIVote == "yes" {
                    cell.actionButton.isSelected = true
                } else {
                    cell.actionButton.isSelected = false
                    let tapSpacerToUpvote = UITapGestureRecognizer(target: self, action: #selector(self.upvotePost))
                    cell.actionSpacerLabel.addGestureRecognizer(tapSpacerToUpvote)
                }
                cell.actionButton.isHidden = false
                cell.actionSpacerLabel.isHidden = false
            } else {
                cell.actionButton.isHidden = true
                cell.actionSpacerLabel.isHidden = false
            }
            
            cell.contentView.backgroundColor = .white

            let tapWord = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.postContentTextView.addGestureRecognizer(tapWord)
            
            let pointsCount = individualPost["pointsCount"] as! Int
            cell.pointsLabel.text  = misc.setCount(pointsCount)
        
            cell.timestampLabel.text = individualPost["timestamp"] as? String
            
            let shareCount = individualPost["shareCount"] as! Int
            cell.shareCountLabel.text = misc.setCount(shareCount)
            let tapSpacerToShare = UITapGestureRecognizer(target: self, action: #selector(self.presentSharePostSheet))
            cell.shareSpacerLabel.addGestureRecognizer(tapSpacerToShare)
            
            let replyCount = individualPost["replyCount"] as! Int
            cell.replyCountLabel.text = misc.setCount(replyCount)
            
            let tapToEditParent: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.presentParentOptions))
            cell.addGestureRecognizer(tapToEditParent)
            
            return cell
        }
        
        if (self.replyPosts.isEmpty || self.replyPosts.count == 1) && indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "anonReplyCell", for: indexPath) as! PostTableViewCell
            cell.postContentTextView.textColor = .lightGray
            if self.firstLoad {
                cell.postContentTextView.text = "loading replies..."
            } else {
                cell.postContentTextView.text = "No replies yet. Be the first! :)"
            }
            return cell
        }
        
        var cell: PostTableViewCell
        let individualPost = self.replyPosts[indexPath.row]
        let postContent = individualPost["postContent"] as! String
        let timestamp = individualPost["timestamp"] as! String
        
        if self.isAnon {
            cell = tableView.dequeueReusableCell(withIdentifier: "anonReplyCell", for: indexPath) as! PostTableViewCell
            cell.contentView.backgroundColor = .white

            let string = "\(timestamp)" + "\r\n" + "\(postContent)"
            cell.postContentTextView.attributedText = misc.anonStringWithColoredTags(string, time: timestamp, fontSize: 18, timeSize: 14)
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "pondReplyCell", for: indexPath) as! PostTableViewCell
            cell.contentView.backgroundColor = .white

            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
            let picURL = individualPost["picURL"] as! URL
            cell.userPicImageView.sd_setImage(with: picURL)
            
            let userHandle = individualPost["userHandle"] as! String
            let string = "@\(userHandle) \(timestamp)" + "\r\n" + "\(postContent)"
            cell.postContentTextView.attributedText = misc.stringWithColoredTags(string, time: timestamp, fontSize: 18, timeSize: 14)
            let tapWord = UITapGestureRecognizer(target: self, action: #selector(self.textViewTapped))
            cell.postContentTextView.addGestureRecognizer(tapWord)
            
            let userID = individualPost["userID"] as! Int
            if userID != self.myID && self.myID > 0 {
                let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfileFromReply))
                cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
            }
        }
        
        let postID = individualPost["postID"] as! Int
        if !self.postIDArray.contains(postID) {
            cell.alpha = 0
            UIView.animate(withDuration: 0.1, animations: {
                cell.alpha = 1
            })
            self.postIDArray.append(postID)
        }
        
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
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.parentRow = indexPath.row
        
        if indexPath.row == 0 {
            if let cell = tableView.cellForRow(at: indexPath) as? PostTableViewCell {
                cell.contentView.backgroundColor = misc.nativFade
                self.presentParentOptions()
            }
        }
        
        if !self.replyPosts.isEmpty && !self.isKeyboardUp {
            if let cell = tableView.cellForRow(at: indexPath) as? PostTableViewCell {
                cell.contentView.backgroundColor = misc.nativFade
                self.presentReplyOptions(indexPath)
            }
        } else {
            if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
                if let cell = tableView.cellForRow(at: indexPath) as? PostTableViewCell {
                    cell.contentView.backgroundColor = misc.nativFade
                    self.textView.becomeFirstResponder()
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromDropToUserProfile" {
            if let userProfileViewController = segue.destination as? UserProfileViewController {
                if self.segueSender == "pondMap" {
                    userProfileViewController.segueSender = "mapDrop"
                } else if self.segueSender == "pondList" {
                    userProfileViewController.segueSender = "listDrop"
                } else if self.segueSender == "dropList" {
                    userProfileViewController.segueSender = "drop"
                } else {
                    userProfileViewController.segueSender = self.segueSender
                }
                userProfileViewController.fromHandle = self.fromHandle
                userProfileViewController.userID = self.userIDToPass
                userProfileViewController.userIDFIR = self.userIDFIRToPass
                userProfileViewController.userHandle = "@\(self.userHandleToPass)"
                userProfileViewController.chatID = misc.setChatID(self.myID, userID: self.userIDToPass)
            }
        }
        
        if segue.identifier == "fromDropToImage" {
            if let imageViewController = segue.destination as? ImageViewController {
                imageViewController.imageURL = self.imageURLToPass
            }
        }
    }
    
    func unwindToHome() {
        if self.segueSender == "userProfile" {
            self.performSegue(withIdentifier: "unwindFromDropToFriendList", sender: self)
        } else {
            _ = self.navigationController?.popViewController(animated: false)
        }
    }
    
    func presentImage() {
        let individualPost = self.parentPost
        var contentToPass: String
        let postContent = individualPost["postContent"] as! String
        let timestamp = individualPost["timestamp"] as! String
        if let handle = individualPost["userHandle"] as? String {
            contentToPass = "@\(handle), \(timestamp): \(postContent)"
        } else {
            contentToPass = "\(timestamp): \(postContent)"
        }
        if let url = individualPost["imageURL"] as? URL {
            self.imageURLToPass = url
            self.postContentToPass = contentToPass
            self.performSegue(withIdentifier: "fromDropToImage", sender: self)
        }
    }
    
    func presentUserProfileFromReply(sender: UITapGestureRecognizer) {
        if self.myID <= 0 ||  self.myIDFIR == "0000000000000000000000000000" {
            self.displayAlert("Need to Sign In", alertMessage: "In order to view a profile, you need to login/sign up. Click the menu icon on the top left and go to the sign up section. There's only one step to sign up! :)")
            return
        } else {
            let position = sender.location(in: self.dropTableView)
            let indexPath: IndexPath! = self.dropTableView.indexPathForRow(at: position)
            self.parentRow = indexPath.row
            let individualPost = self.replyPosts[self.parentRow]
            let userID = individualPost["userID"] as! Int
            self.fromHandle = false
            self.userIDToPass = userID
            self.userIDFIRToPass = individualPost["userIDFIR"] as! String
            self.userHandleToPass = individualPost["userHandle"] as! String
            if self.myID != userID && userID > 0 {
                self.performSegue(withIdentifier: "fromDropToUserProfile", sender: self)
            }
        }
    }
    
    func presentUserProfileFromParent() {
        if self.myID <= 0 ||  self.myIDFIR == "0000000000000000000000000000" {
            self.displayAlert("Need to Sign In", alertMessage: "In order to view a profile, you need to login/sign up. Click the menu icon on the top left and go to the sign up section. There's only one step to sign up! :)")
            return
        } else {
            let individualPost = self.parentPost
            let userID = individualPost["userID"] as! Int
            self.fromHandle = false
            self.userIDToPass = userID
            self.userIDFIRToPass = individualPost["userIDFIR"] as! String
            self.userHandleToPass = individualPost["userHandle"] as! String
            if self.myID != userID && userID > 0 {
                self.performSegue(withIdentifier: "fromDropToUserProfile", sender: self)
            }
        }
    }
    
    func presentParentOptions() {
        self.settingsButton.isSelected = true
        let individualPost = self.parentPost
        let userID = individualPost["userID"] as! Int
        let userIDFIR = individualPost["userIDFIR"] as! String
        let postContent = individualPost["postContent"] as! String
        
        let cell = self.dropTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! PostTableViewCell
//        let cell = header?.contentView as! PostTableViewCell
        cell.contentView.backgroundColor = misc.nativFade
        
        let editPostPopViewController = storyboard?.instantiateViewController(withIdentifier: "EditPostPopViewController") as! EditPostPopViewController
        editPostPopViewController.modalPresentationStyle = .popover
        editPostPopViewController.editPostDelegate = self
        editPostPopViewController.preferredContentSize = CGSize(width: 320, height: 75)
        editPostPopViewController.postID = self.postID
        editPostPopViewController.postContent = postContent
        if self.isAnon {
            editPostPopViewController.postType = "anon"
        } else {
            editPostPopViewController.postType = "pond"
        }
        editPostPopViewController.postSubType = "parent"
        if let editPopoverController = editPostPopViewController.popoverPresentationController {
            editPopoverController.delegate = self
            editPopoverController.sourceView = cell.postContentTextView
            editPopoverController.sourceRect = cell.postContentTextView.bounds
        }
        
        let reportPopViewController = storyboard?.instantiateViewController(withIdentifier: "ReportPopViewController") as! ReportPopViewController
        reportPopViewController.modalPresentationStyle = .popover
        reportPopViewController.preferredContentSize = CGSize(width: 200, height: 200)
        reportPopViewController.userID = userID
        reportPopViewController.userIDFIR = userIDFIR
        reportPopViewController.postContent = postContent 
        reportPopViewController.postID = self.postID
        if self.isAnon {
            reportPopViewController.postType = "anon"
        } else {
            reportPopViewController.postType = "pond"
        }
        if let reportPopoverController = reportPopViewController.popoverPresentationController {
            reportPopoverController.delegate = self
            reportPopoverController.barButtonItem = self.settingsBarButton
        }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if self.myID == userID {
            let editAction = UIAlertAction(title: "Edit", style: .default, handler: { action in
                self.removeObserverForReplies()
                self.isEditingPost = true
                self.settingsButton.isSelected = false
                self.present(editPostPopViewController, animated: true, completion: nil)
            })
            alertController.addAction(editAction)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .default, handler: { action in
                self.settingsButton.isSelected = false
                self.deleteParentPost()
            })
            alertController.addAction(deleteAction)
        }
        
        if self.myID > 0 {
            if let imageURL = individualPost["imageURL"] as? URL {
                let shareFBAction = UIAlertAction(title: "Share on Facebook", style: .default, handler: { action in
                    cell.contentView.backgroundColor = .white
                    self.settingsButton.isSelected = false
                    self.sharePhotoFB(imageURL)
                })
                alertController.addAction(shareFBAction)
                
                let shareTwitterAction = UIAlertAction(title: "Share on Twitter", style: .default, handler: { action in
                    cell.contentView.backgroundColor = .white
                    self.settingsButton.isSelected = false
                    self.sharePhotoTwitter(imageURL)
                })
                alertController.addAction(shareTwitterAction)
                
            } else {
                let shareFBAction = UIAlertAction(title: "Share on Facebook", style: .default, handler: { action in
                    cell.contentView.backgroundColor = .white
                    self.settingsButton.isSelected = false
                    self.shareOnFB(cell.contentView)
                })
                alertController.addAction(shareFBAction)
                
                let shareTwitterAction = UIAlertAction(title: "Share on Twitter", style: .default, handler: { action in
                    cell.contentView.backgroundColor = .white
                    self.settingsButton.isSelected = false
                    self.shareOnTwitter(cell.contentView)
                })
                alertController.addAction(shareTwitterAction)
            }
        }
        
        let reportAction = UIAlertAction(title: "Report", style: .default, handler: { action in
            self.removeObserverForReplies()
            self.present(reportPopViewController, animated: true, completion: nil)
        })
        alertController.addAction(reportAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            cell.contentView.backgroundColor = .white
            self.settingsButton.isSelected = false
        })
        )
        
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: { self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func presentReplyOptions(_ indexPath: IndexPath) {
        let cell = self.dropTableView.cellForRow(at: indexPath) as! PostTableViewCell
        
        let individualPost = self.replyPosts[indexPath.row]
        let postSubID = individualPost["postID"] as! Int
        let postContent = individualPost["postContent"] as! String
        let userID = individualPost["userID"] as! Int
        let userIDFIR = individualPost["userIDFIR"] as! String
        
        if postSubID > 0 {
            let editPostPopViewController = storyboard?.instantiateViewController(withIdentifier: "EditPostPopViewController") as! EditPostPopViewController
            editPostPopViewController.modalPresentationStyle = .popover
            editPostPopViewController.editPostDelegate = self
            editPostPopViewController.preferredContentSize = CGSize(width: 320, height: 75)
            editPostPopViewController.postID = self.postID
            editPostPopViewController.postSubID = postSubID
            editPostPopViewController.postContent = postContent
            if self.isAnon {
                editPostPopViewController.postType = "anon"
            } else {
                editPostPopViewController.postType = "pond"
            }
            editPostPopViewController.postSubType = "reply"
            if let editPopoverController = editPostPopViewController.popoverPresentationController {
                editPopoverController.delegate = self
                editPopoverController.sourceView = cell.postContentTextView
                editPopoverController.sourceRect = cell.postContentTextView.bounds
            }
            
            let reportPopViewController = storyboard?.instantiateViewController(withIdentifier: "ReportPopViewController") as! ReportPopViewController
            reportPopViewController.modalPresentationStyle = .popover
            reportPopViewController.userID = userID
            reportPopViewController.userIDFIR = userIDFIR
            reportPopViewController.postContent = postContent 
            reportPopViewController.preferredContentSize = CGSize(width: 200, height: 200)
            reportPopViewController.postID = postSubID
            if self.isAnon {
                reportPopViewController.postType = "anon"
            } else {
                reportPopViewController.postType = "pond"
            }
            if let reportPopoverController = reportPopViewController.popoverPresentationController {
                reportPopoverController.delegate = self
                reportPopoverController.sourceView = cell.postContentTextView
                reportPopoverController.sourceRect = cell.postContentTextView.bounds
            }
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let reportAction = UIAlertAction(title: "Report", style: .default, handler: { action in
                self.removeObserverForReplies()
                self.present(reportPopViewController, animated: true, completion: nil)
            })
            alertController.addAction(reportAction)
            
            if self.myID == userID {
                let editAction = UIAlertAction(title: "Edit", style: .default, handler: { action in
                    self.removeObserverForReplies()
                    cell.contentView.backgroundColor = .white
                    self.isEditingPost = true
                    self.present(editPostPopViewController, animated: true, completion: nil)
                })
                alertController.addAction(editAction)
                
                let deleteAction = UIAlertAction(title: "Delete", style: .default, handler: { action in
                    cell.contentView.backgroundColor = .white
                    self.deleteReply()
                })
                alertController.addAction(deleteAction)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                cell.contentView.backgroundColor = .white
            })
            )
            
            alertController.view.tintColor = misc.nativColor
            DispatchQueue.main.async(execute: { self.present(alertController, animated: true, completion: nil)
            })
        }
    }
    
    func refreshView() {
        self.settingsButton.isSelected = false
        self.dropTableView.reloadData()
    }
    
    // MARK: - EditPostProtocol (Popover)
    
    func updatePost(_ postContent: String) {
        self.isEditingPost = false
        self.parentPost["postContent"] = postContent
        let timestamp = misc.getTimestamp("mine")
        self.parentPost["timestamp"] = "edited \(timestamp)"
        self.dropTableView.reloadData()
        
        self.editPondParentDelegate?.editPondContent(postContent, timestamp: timestamp)
        
        self.observeReplies()
    }
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.settingsButton.isSelected = false
        self.dropTableView.reloadData()
        self.isEditingPost = false
        self.observeReplies()
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForReplies()
            self.isRemoved = true
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        if offset <= 420 {
            self.scrollToTopButton.removeFromSuperview()
        }
        
        if offset <= 0 {
            self.scrollPosition = "top"
            self.observeReplies()
        } else if (offset == (contentHeight - frameHeight)) {
            self.scrollPosition = "bottom"
            if self.replyPosts.count >= 41 {
                self.getReplies()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        let posts = self.replyPosts
        if posts.count > 1 {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.dropTableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.dropTableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 10
                    
                    let maxCount = posts.count
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow <= lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let post = posts[index]
                        if let picURL = post["picURL"] as? URL {
                            urlsToPrefetch.append(picURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
        textView.font = UIFont.systemFont(ofSize: 14)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.textColor == UIColor.black && textView.text != "" {
            self.sendButton.isEnabled = true
        } else {
            self.sendButton.isEnabled = false
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
            textView.text = "reply..."
            textView.textColor = .lightGray
            self.characterCountLabel.isHidden = true
            self.sendButton.isEnabled = false
            textView.font = UIFont.systemFont(ofSize: 14)
        }
        
        if self.replyPosts.isEmpty {
            if let cell = self.dropTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? NoContentTableViewCell {
                cell.contentView.backgroundColor = .white
            }
        }
    }
    
    func textViewTapped(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.dropTableView)
        let indexPath: IndexPath! = self.dropTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        
        if let textView = sender.view as? UITextView {
            let layoutManager = textView.layoutManager
            var location: CGPoint = sender.location(in: textView)
            location.x -= textView.textContainerInset.left
            location.y -= textView.textContainerInset.top
            
            let charIndex = layoutManager.characterIndex(for: location, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if charIndex < textView.textStorage.length {
                let attributeName = "tappedWord"
                let attributeValue = textView.attributedText.attribute(attributeName, at: charIndex, effectiveRange: nil) as? String
                
                if let tappedWord = attributeValue {
                    if tappedWord.characters.first == "@" {
                        let handleNoAt = misc.handlesWithoutAt(tappedWord)
                        if let handle = handleNoAt.first {
                            if let myHandle = UserDefaults.standard.string(forKey: "myHandle.nativ") {
                                if myHandle.lowercased() != handle.lowercased() {
                                    self.userHandleToPass = handle
                                    self.fromHandle = true
                                    self.performSegue(withIdentifier: "fromDropToUserProfile", sender: self)
                                }
                            }
                        }
                    }
                    
                    if tappedWord.characters.first == "." {
                        if let tagNoDot = misc.tagsWithoutDot(tappedWord).first {
                            UserDefaults.standard.set(true, forKey: "fromTag.nativ")
                            UserDefaults.standard.set(tagNoDot, forKey: "locationTag.nativ")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToPondList"), object: nil)
                        }
                    }
                    
                } else {
                    if indexPath.row == 0 {
                        if let cell = self.dropTableView.cellForRow(at: indexPath) as? PostTableViewCell {
                            cell.contentView.backgroundColor = misc.nativFade
                            self.presentParentOptions()
                        }
                    }
                    
                    if !self.replyPosts.isEmpty && !self.isKeyboardUp {
                        if let cell = dropTableView.cellForRow(at: indexPath) as? PostTableViewCell {
                            cell.contentView.backgroundColor = misc.nativFade
                            self.presentReplyOptions(indexPath)
                        }
                        
                    } else {
                        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
                            
                            if let cell = dropTableView.cellForRow(at: indexPath) as? PostTableViewCell {
                                cell.contentView.backgroundColor = misc.nativFade
                                self.textView.becomeFirstResponder()
                            }
                        }
                    }
                }
                
            }
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        self.isKeyboardUp = true
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if !self.isEditingPost {
                self.dimBackground(true)
                if self.textViewBottomConstraint.constant == 8 {
                    self.textViewBottomConstraint.constant += keyboardSize.height
                    UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
                }
            }
        }
    }
    
    func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if !self.isEditingPost {
                self.textViewBottomConstraint.constant = 8 + keyboardSize.height
                UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
            }
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
        if !self.isEditingPost {
            if self.textViewBottomConstraint.constant != 8 {
                self.textViewBottomConstraint.constant = 8
                UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
            }
        }
    }
    
    func keyboardDidHide(_ notification: Notification) {
        self.isKeyboardUp = false
    }
    
    // MARK: - Notifications
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.unwindToHome), name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshView), name: NSNotification.Name(rawValue: "unselectSettings"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "getDrop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForReplies), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "getDrop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
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
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.dropTableView.frame.origin.y + 8, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: "top")
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.lastContentOffset = 0
        self.dropTableView.setContentOffset(.zero, animated: false)
        self.scrollToTopButton.removeFromSuperview()
    }
    
    func colorTopButtonDown() {
        self.scrollToTopButton.backgroundColor = misc.nativSemiFade
    }
    
    func colorTopButtonUp() {
        self.scrollToTopButton.backgroundColor = UIColor(white: 0, alpha: 0.025)
    }
    
    func dimBackground(_ bool: Bool) {
        if bool {
            self.dimView.alpha = 0.25
        } else {
            self.dimView.alpha = 0
        }
    }
    
    func handleRefreshControl(refreshControl: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            refreshControl.endRefreshing()
        })
    }
    
    func clearArrays() {
        self.urlArray = []
        self.heightAtIndexPath = [:]
        self.postIDArray = []
        self.replyPosts = []
    }
    
    // MARK: - Analytics
    
    func logViewDrop() {
        var name: String
        if self.isAnon {
            name = "viewAnonymousPondReplies"
        } else {
            name = "viewPondReplies"
        }
        FIRAnalytics.logEvent(withName: name, parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": self.postID as NSObject
            ])
    }
    
    func logPondPostShared(_ postID: Int, socialMedia: String) {
        FIRAnalytics.logEvent(withName: "pondPostShared", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "socialMedia": socialMedia as NSObject
            ])
    }
    
    func logAnonPostShared(_ postID: Int, socialMedia: String) {
        FIRAnalytics.logEvent(withName: "anonPostShared", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "socialMedia": socialMedia as NSObject
            ])
    }
    
    func logPondPostUpvoted(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "pondPostUpvoted", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            ])
    }
    
    func logAnonPostUpvoted(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "anonPostUpvoted", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            ])
    }
    
    func logPondReplySent(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "pondReplySent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject
            ])
    }
    
    func logAnonReplySent(_ postID: Int) {
        FIRAnalytics.logEvent(withName: "anonReplySent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject
            ])
    }
    
    func logReplyDeleted(_ postID: Int) {
        if self.isAnon {
            FIRAnalytics.logEvent(withName: "anonReplyDeleted", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": postID as NSObject
                ])
        } else {
            FIRAnalytics.logEvent(withName: "pondReplyDeleted", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": postID as NSObject
                ])
        }
    }
    
    func logParentDeleted() {
        if self.isAnon {
            FIRAnalytics.logEvent(withName: "anonPostDeleted", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postID as NSObject
                ])
        } else {
            FIRAnalytics.logEvent(withName: "pondPostDeleted", parameters: [
                "userID": self.myID as NSObject,
                "userIDFIR": self.myIDFIR as NSObject,
                "postID": self.postID as NSObject
                ])
        }
    }
    
    // MARK: - Firebase
    
    func writeInPostID(_ postID: Int) {
        self.ref.child("users").child(self.myIDFIR).child("inPostID").setValue(postID)
        UserDefaults.standard.set(postID, forKey: "inPostID.nativ")
        UserDefaults.standard.synchronize()
    }
    
    func observeReplies() {
        self.removeObserverForReplies()
        if self.scrollPosition == "top" || self.firstLoad {
            self.isRemoved = false
            let postIDString = "\(self.postID)"
            
            if self.isAnon {
                let anonRef = self.ref.child("anonPosts").child(postIDString)
                anonRef.observe(.value, with: {
                    (snapshot) -> Void in
                    self.getNewPosts()
                })
            } else {
                let pondRef = self.ref.child("posts").child(postIDString)
                pondRef.observe(.value, with: {
                    (snapshot) -> Void in
                    self.getNewPosts()
                })
            }
        }
    }
    
    func removeObserverForReplies() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let postIDString = "\(self.postID)"
        let pondRef = self.ref.child("posts").child(postIDString)
        let anonRef = self.ref.child("anonPosts").child(postIDString)
        pondRef.removeAllObservers()
        anonRef.removeAllObservers()
    }
    
    func writePostShared(_ postID: Int, postType: String) {
        let pondRef = self.ref.child("posts").child("\(postID)").child("parent").child("shareCount")
        let anonRef = self.ref.child("anonPosts").child("\(postID)").child("parent").child("shareCount")
        
        if postType == "pond" {
            pondRef.observeSingleEvent(of: .value, with: {
                (snapshot) -> Void in
                if let shareCount = snapshot.value as? Int {
                    let newCount = shareCount + 1
                    pondRef.setValue(newCount)
                }
            })
        } else {
            anonRef.observeSingleEvent(of: .value, with: {
                (snapshot) -> Void in
                if let shareCount = snapshot.value as? Int {
                    let newCount = shareCount + 1
                    anonRef.setValue(newCount)
                }
            })
        }
    }
    
    func writePostUpvoted(_ postID: Int, postType: String) {
        let pondRef = self.ref.child("posts").child("\(self.postID)").child("points")
        let anonRef = self.ref.child("anonPosts").child("\(self.postID)").child("points")
        
        if postType == "pond" {
            pondRef.observeSingleEvent(of: .value, with: {
                (snapshot) -> Void in
                if let points = snapshot.value as? Int {
                    let newPoints = points + 1
                    pondRef.setValue(newPoints)
                }
            })
        } else {
            anonRef.observeSingleEvent(of: .value, with: {
                (snapshot) -> Void in
                if let points = snapshot.value as? Int {
                    let newPoints = points + 1
                    anonRef.setValue(newPoints)
                }
            })
        }
    }
    
    func writeReplySent (_ replyID: Int, postContent: String) {
        if self.isAnon {
            let anonRef = self.ref.child("anonPosts").child("\(self.postID)").child("\(replyID)")
            anonRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine")])
        } else {
            let pondRef = self.ref.child("posts").child("\(self.postID)").child("\(replyID)")
            pondRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine")])
        }
    }
    
    func writePostDeleted() {
        if self.isAnon {
            let anonRef = self.ref.child("anonPosts").child("\(self.postID)").child("parent")
            anonRef.child("postContent").setValue("[deleted]")
            anonRef.child("timestamp").setValue("\(misc.getTimestamp("mine"))")
        } else {
            let pondRef = self.ref.child("posts").child("\(self.postID)").child("parent")
            pondRef.child("postContent").setValue("[deleted]")
            pondRef.child("timestamp").setValue("\(misc.getTimestamp("mine"))")
        }
    }
    
    // MARK: - AWS
    
    func getNewPosts() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newPostsCount += 1
        }
        
        if self.newPostsCount == 3 || self.firstLoad {
            self.perform(#selector(self.getReplies), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getReplies), with: nil, afterDelay: 0.5)
        }
    }
    
    func setReply(_ postID: Int, postContent: String) -> [String:Any] {
        var picURL: URL
        if let url = UserDefaults.standard.url(forKey: "myPicURL.nativ") {
            picURL = url
        } else {
            picURL = URL(string: "https://hostpostuserprof.s3.amazonaws.com/default_small")!
        }
        let myHandle: String
        
        if let handle = UserDefaults.standard.string(forKey: "myHandle.nativ") {
            myHandle = handle
        } else {
            myHandle = "Me"
        }
        
        if self.isAnon {
            let post: [String:Any] = ["postID": postID, "userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine")]
            return post
            
        } else {
            let post: [String:Any] = ["postID": postID, "userID": self.myID, "userIDFIR": self.myIDFIR, "userHandle": myHandle, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "picURL": picURL]
            return post
        }
    }
    
    func presentSharePostSheet(sender: UITapGestureRecognizer) {
        self.removeObserverForReplies()
        
        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
            let individualPost = self.parentPost
            let position = sender.location(in: self.dropTableView)
            let indexPath: IndexPath! = self.dropTableView.indexPathForRow(at: position)
            self.parentRow = indexPath.row
            
            //        let header = self.dropTableView.headerView(forSection: 0)
            let cell = self.dropTableView.cellForRow(at: indexPath) as! PostTableViewCell
            cell.sharePicImageView.isHighlighted = true
            
            let postContent = individualPost["postContent"] as! String
            let shareCount = individualPost["shareCount"] as! Int
            let newShareCount = shareCount + 1
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let shareFBAction = UIAlertAction(title: "Share on Facebook", style: .default, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                cell.shareCountLabel.text = "\(newShareCount)"
                
                if let imageURL = individualPost["imageURL"] as? URL {
                    self.sharePost(postContent, socialMedia: "Facebook", imageURL: imageURL, orView: nil, newShareCount: newShareCount)
                } else {
                    self.sharePost(postContent, socialMedia: "Facebook", imageURL: nil, orView: cell.contentView, newShareCount: newShareCount)
                }
            })
            alertController.addAction(shareFBAction)
            
            let shareTwitterAction = UIAlertAction(title: "Share on Twitter", style: .default, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                cell.shareCountLabel.text = "\(newShareCount)"
                
                if let imageURL = individualPost["imageURL"] as? URL {
                    self.sharePost(postContent, socialMedia: "Twitter", imageURL: imageURL, orView: nil, newShareCount: newShareCount)
                } else {
                    self.sharePost(postContent, socialMedia: "Twitter", imageURL: nil, orView: cell.contentView, newShareCount: newShareCount)
                }
            })
            alertController.addAction(shareTwitterAction)
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                self.observeReplies()
            })
            )
            
            alertController.view.tintColor = misc.nativColor
            DispatchQueue.main.async(execute: { self.present(alertController, animated: true, completion: nil)
            })
        } else {
            self.displayAlert("Need to Sign In", alertMessage: "In order to share, you need to be signed into an account.")
            return
        }
    }
    
    func sharePost(_ postContent: String, socialMedia: String, imageURL: URL?, orView: UIView?, newShareCount: Int) {
        var postType: String
        if self.isAnon {
            postType = "anon"
        } else {
            postType = "pond"
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/postShared")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(self.postID)&postType=\(postType)&postContent=\(postContent)&socialMedia=\(socialMedia)"
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. The post may not have been shared. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                self.observeReplies()
                                if postType == "pond" {
                                    self.logPondPostShared(self.postID, socialMedia: socialMedia)
                                } else {
                                    self.logAnonPostShared(self.postID, socialMedia: socialMedia)
                                }
                                self.parentPost["shareCount"] = newShareCount
                                self.writePostShared(self.postID, postType: postType)
                                if let url = imageURL {
                                    if socialMedia == "Facebook" {
                                        self.sharePhotoFB(url)
                                    } else {
                                        self.sharePhotoTwitter(url)
                                    }
                                }
                                if let view = orView {
                                    if socialMedia == "Facebook" {
                                        self.shareOnFB(view)
                                    } else {
                                        self.shareOnTwitter(view)
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
    
    func upvotePost() {
        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
            let individualPost = self.parentPost
            
            let didIVote = individualPost["didIVote"] as! String
            let postID = individualPost["postID"] as! Int
            
            if didIVote == "no" && postID > 0 {
                let currentPoints = individualPost["pointsCount"] as! Int
                let newPoints = currentPoints + 1
                self.parentPost["pointsCount"] = newPoints
                self.parentPost["didIVote"] = "yes"
                self.dropTableView.reloadData()
                
                let postID = individualPost["postID"] as! Int
                var postType: String
                if let _ = individualPost["userHandle"] as? String {
                    postType = "pond"
                } else {
                    postType = "anon"
                }
                
                let token = misc.generateToken(16, firebaseID: self.myIDFIR)
                let iv = token.first!
                let tokenString = token.last!
                let key = token[1]
                
                do {
                    let aes = try AES(key: key, iv: iv)
                    let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
                    
                    let sendURL = URL(string: "https://dotnative.io/sendPoint")
                    var sendRequest = URLRequest(url: sendURL!)
                    sendRequest.httpMethod = "POST"
                    
                    let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&postType=\(postType)"
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
                                        self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your upvote may not have gone through. Please report the bug by going to the report section in the menu if this persists.")
                                        return
                                    }
                                    
                                    if status == "success" {
                                        if postType == "pond" {
                                            self.logPondPostUpvoted(postID)
                                        } else {
                                            self.logAnonPostUpvoted(postID)
                                        }
                                        self.writePostUpvoted(postID, postType: postType)
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
    }
    
    func sendReply() {
        let postContent: String = self.textView.text
        let handles = misc.handlesWithoutAt(postContent)
        let tags = misc.tagsWithoutDot(postContent)
        
        if self.isAnon && !handles.isEmpty {
            self.displayAlert("No user tags in anon posts", alertMessage: "You cannot tag a user in an anonymous post. Please remove the text mentioning the user before posting.")
            return
        }
        
        let post = self.setReply(-2, postContent: postContent)
        self.replyPosts.insert(post, at: 1)
        self.dropTableView.reloadData()
        
        self.textView.text = ""
        self.dismissKeyboard()
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            var sendURL: URL!
            if self.isAnon {
                sendURL = URL(string: "https://dotnative.io/sendAnonPondPost")
            } else {
                sendURL = URL(string: "https://dotnative.io/sendPondPost")
            }
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            var sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(self.postID)&postContent=\(postContent)"
            if !handles.isEmpty {
                sendString.append("&userHandles=\(handles)")
            }
            if !tags.isEmpty {
                sendString.append("&locationTag=\(tags)")
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your post may not have been sent. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                if let newPostID = parseJSON["postID"] as? Int {
                                    let post = self.setReply(newPostID, postContent: postContent)
                                    self.replyPosts.remove(at: 1)
                                    self.replyPosts.insert(post, at: 1)
                                    
                                    if self.isAnon {
                                        self.logAnonReplySent(newPostID)
                                    } else {
                                        self.logPondReplySent(newPostID)
                                    }
                                    
                                    self.writeReplySent(newPostID, postContent: postContent)
                                    
                                    let replyCount = self.parentPost["replyCount"] as! Int
                                    let newCount = replyCount + 1
                                    self.editPondParentDelegate?.updatePondReplyCount(newCount)
                                }
                                
                                self.firstLoad = false
                                self.dropTableView.reloadData()
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
    
    func getReplies() {
        self.newPostsCount = 0
        let picSize: String = "small"
        
        var pageNumber: Int
        var lastPostID: Int
        if self.scrollPosition == "bottom" && self.replyPosts.count >= 41 {
            let lastPost = self.replyPosts.last!
            lastPostID = lastPost["postID"] as! Int
            pageNumber = misc.getNextPageNumberNoAd(self.replyPosts)
            self.displayActivity("loading more posts...", indicator: true)
        } else {
            lastPostID = 0
            pageNumber = 0
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            var getURL: URL!
            if self.isAnon {
                getURL = URL(string: "https://dotnative.io/getAnonPondPost")
            } else {
                getURL = URL(string: "https://dotnative.io/getPondPost")
            }
            
            let getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(self.postID)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)"

            var getRequest = URLRequest(url: getURL!)
            getRequest.httpMethod = "POST"
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
                            self.activityView.removeFromSuperview()
                            
                            if status == "error" {
                                self.firstLoad = false
                                self.dropTableView.reloadData()
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load posts. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                var dictKey: String
                                if self.isAnon {
                                    dictKey = "anonPondPosts"
                                } else {
                                    dictKey = "pondPosts"
                                }
                                
                                if let postsArray = parseJSON[dictKey] as? [[String:Any]] {
                                    var replies: [[String:Any]] = []
                                    for (index, individualPost) in postsArray.enumerated() {
                                        
                                        if index == 0 && lastPostID == 0 {
                                            let parent = individualPost
                                            var postType: String
                                            if let _ = parent["userHandle"] as? String {
                                                postType = "pond"
                                            } else {
                                                postType = "anon"
                                            }
                                            
                                            let postID = parent["postID"] as! Int
                                            
                                            let userID = parent["userID"] as! Int
                                            let userIDFIR = parent["firebaseID"] as! String
                                            
                                            var timestamp: String!
                                            let time = parent["timestamp"] as! String
                                            let timeEdited = parent["timestampEdited"] as! String
                                            if time == timeEdited {
                                                let timeFormatted = self.misc.formatTimestamp(time)
                                                timestamp = timeFormatted
                                            } else {
                                                let timeEditedFormatted = self.misc.formatTimestamp(timeEdited)
                                                timestamp = "edited \(timeEditedFormatted)"
                                            }
                                            
                                            let postContent = parent["postContent"] as! String
                                            let pointsCount = parent["pointsCount"] as! Int
                                            let didIVote = parent["didIVote"] as! String
                                            let replyCount = parent["replyCount"] as! Int
                                            let shareCount = parent["shareCount"] as! Int
                                            
                                            let long = individualPost["longitude"] as! String
                                            let longitude: Double = Double(long)!
                                            let lat = individualPost["latitude"] as! String
                                            let latitude: Double = Double(lat)!
                                            
                                            let imageKey = parent["imageKey"] as! String
                                            let imageBucket = parent["imageBucket"] as! String
                                            
                                            if postType == "anon"  {
                                                var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                                if !imageKey.contains("default") {
                                                    let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                    if !self.urlArray.contains(imageURL) {
                                                        self.urlArray.append(imageURL)
                                                    }
                                                    post["imageURL"] = imageURL
                                                }
                                                self.parentPost = post
                                                
                                            } else {
                                                let userName = parent["userName"] as! String
                                                let userHandle = parent["userHandle"] as! String
                                                
                                                let key = parent["key"] as! String
                                                let bucket = parent["bucket"] as! String
                                                let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                                if !self.urlArray.contains(picURL) {
                                                    self.urlArray.append(picURL)
                                                    SDWebImagePrefetcher.shared().prefetchURLs([picURL])
                                                }
                                                
                                                var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "userName": userName, "userHandle": userHandle, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "picURL": picURL, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                                if !imageKey.contains("default") {
                                                    let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                    if !self.urlArray.contains(imageURL) {
                                                        self.urlArray.append(imageURL)
                                                    }
                                                    post["imageURL"] = imageURL
                                                }
                                                self.parentPost = post
                                            }
                                        }
                                        
                                        let postID = individualPost["postID"] as! Int
                                        let userID = individualPost["userID"] as! Int
                                        let userIDFIR = individualPost["firebaseID"] as! String
                                        
                                        var timestamp: String!
                                        let time = individualPost["timestamp"] as! String
                                        let timeEdited = individualPost["timestampEdited"] as! String
                                        if time == timeEdited {
                                            let timeFormatted = self.misc.formatTimestamp(time)
                                            timestamp = timeFormatted
                                        } else {
                                            let timeEditedFormatted = self.misc.formatTimestamp(timeEdited)
                                            timestamp = "edited \(timeEditedFormatted)"
                                        }
                                        
                                        let postContent = individualPost["postContent"] as! String
                                        
                                        if let handle = individualPost["userHandle"] as? String  {
                                            let key = individualPost["key"] as! String
                                            let bucket = individualPost["bucket"] as! String
                                            let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                            if !self.urlArray.contains(picURL) {
                                                self.urlArray.append(picURL)
                                                SDWebImagePrefetcher.shared().prefetchURLs([picURL])
                                            }
                                            
                                            let reply: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "userHandle": handle, "postContent": postContent, "timestamp": timestamp, "picURL": picURL]
                                            replies.append(reply)
                                            
                                        } else {
                                            let reply: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "postContent": postContent, "timestamp": timestamp]
                                            replies.append(reply)
                                        }
                                        
                                    }
                                    
                                    if lastPostID != 0 {
                                        let latestPost = replies.last!
                                        if lastPostID != latestPost["postID"] as! Int {
                                            self.replyPosts.append(contentsOf: replies)
                                            if self.replyPosts.count > 210 {
                                                let difference = self.replyPosts.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.replyPosts = self.replyPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.replyPosts = replies
                                    }
                                    
                                    if !replies.isEmpty {
                                        var firstRows = 5
                                        let maxCount = replies.count
                                        if firstRows >= (maxCount - 1) {
                                            firstRows = maxCount - 1
                                        }
                                        
                                        var urlsToPrefetch: [URL] = []
                                        for index in 0...firstRows {
                                            let reply = replies[index]
                                            if let picURL = reply["picURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                            if let imageURL = reply["imageURL"] as? URL {
                                                urlsToPrefetch.append(imageURL)
                                            }
                                        }
                                        
                                        SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                            self.firstLoad = false
                                            self.dropTableView.reloadData()
                                        })
                                    }  else {
                                        self.firstLoad = false
                                        self.dropTableView.reloadData()
                                    }
                                } else {
                                    self.firstLoad = false
                                    self.dropTableView.reloadData()
                                } // parse dict
                                
                            } // success
                        }) // main
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
    
    func refreshWithDelay() {
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observeReplies), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getReplies), with: nil, afterDelay: 0.5)
        }
    }
    
    func deleteParentPost() {
        let postID = self.parentPost["postID"] as! Int
        let userID = self.parentPost["userID"] as! Int
        
        if self.myID == userID {
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
                
                var postType: String
                if self.isAnon {
                    postType = "anon"
                } else {
                    postType = "pond"
                }
                let action: String = "delete"
                
                let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&action=\(action)&postType=\(postType)"

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
                                    self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your post may not been deleted. Please report the bug by going to the report section in the menu if this persists.")
                                    return
                                }
                                
                                if status == "success" {
                                    self.editPondParentDelegate?.deletePondParent()
                                    self.parentPost["postContent"] = "[deleted]"
                                    self.dropTableView.reloadData()
                                    self.logParentDeleted()
                                    self.writePostDeleted()
                                    _ = self.navigationController?.popViewController(animated: true)
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
    
    func deleteReply() {
        let indexPath = IndexPath(row: self.parentRow, section: 0)
        let cell = self.dropTableView.cellForRow(at: indexPath) as! PostTableViewCell
        let postID = self.replyPosts[self.parentRow]["postID"] as! Int
        let userID = self.replyPosts[self.parentRow]["userID"] as! Int
        
        if self.myID == userID {
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
                
                var postType: String
                if self.isAnon {
                    postType = "anon"
                } else {
                    postType = "pond"
                }
                let action: String = "delete"
                
                let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&action=\(action)&postType=\(postType)"
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
                                    self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your reply may not been deleted. Please report the bug by going to the report section in the menu if this persists.")
                                    return
                                }
                                
                                if status == "success" {
                                    cell.postContentTextView.text = "[deleted]"
                                    self.logReplyDeleted(postID)
                                    self.writeReplySent(postID, postContent: "[deleted]")
                                    if self.replyPosts.count == 1 {
                                        self.replyPosts = []
                                        self.dropTableView.reloadData()
                                    } else {
                                        let indexPath = IndexPath(row: self.parentRow, section: 0)
                                        self.dropTableView.reloadRows(at: [indexPath], with: .fade)
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
    
    // MARK: Twitter
    
    func sharePhotoTwitter(_ imageURL: URL) {
        let imageView = UIImageView()
        imageView.sd_setImage(with: imageURL)
        
        if let image = imageView.image {
            let composer = TWTRComposer()
            composer.setText("@dotnativeApp ")
            composer.setImage(image)
            
            composer.show(from: self) { result in
                if result == TWTRComposerResult.cancelled {
                    print("Tweet cancelled")
                }
                if result == TWTRComposerResult.done {
                    self.displayAlert(":)", alertMessage: "Tweet sent!")
                    return
                }
            }
        }
    }
    
    func shareOnTwitter(_ view: UIView) {
        let image = UIImage(view: view)
        
        let composer = TWTRComposer()
        composer.setText("@dotnativeApp - ")
        composer.setImage(image)
        
        composer.show(from: self) { result in
            if result == TWTRComposerResult.cancelled {
                print("Tweet cancelled")
            }
            if result == TWTRComposerResult.done {
                self.displayAlert(":)", alertMessage: "Tweet sent!")
                return
            }
        }
    }
    
    // MARK: FBSDK
    
    func sharePhotoFB(_ imageURL: URL) {
        let imageView = UIImageView()
        imageView.sd_setImage(with: imageURL)
        
        if let image = imageView.image {
            let photo: FBSDKSharePhoto = FBSDKSharePhoto()
            photo.image = image
            photo.isUserGenerated = true
            let content: FBSDKSharePhotoContent = FBSDKSharePhotoContent()
            content.photos = [photo]
            let dialog: FBSDKShareDialog = FBSDKShareDialog()
            dialog.mode = .native
            if !dialog.canShow() {
                self.displayAlert("Facebook App Needed", alertMessage: "In order to share, you must have the facebook app installed.")
                return
            }
            FBSDKShareDialog.show(from: self, with: content, delegate: nil)
        }
    }
    
    func shareOnFB(_ view: UIView) {
        let image = UIImage(view: view)
        let photo: FBSDKSharePhoto = FBSDKSharePhoto()
        photo.image = image
        photo.isUserGenerated = true
        let content: FBSDKSharePhotoContent = FBSDKSharePhotoContent()
        content.photos = [photo]
        let dialog: FBSDKShareDialog = FBSDKShareDialog()
        dialog.mode = .native
        if !dialog.canShow() {
            self.displayAlert("Facebook App Needed", alertMessage: "In order to share, you must have the facebook app installed.")
            return
        }
        FBSDKShareDialog.show(from: self, with: content, delegate: nil)
    }
    
}

protocol EditPondParentProtocol: class {
    func editPondContent(_ postContent: String, timestamp: String)
    
    func deletePondParent()
    
    func updatePondReplyCount(_ replyCount: Int)
    
    func updatePondPointCount(_ pointsCount: Int)
}

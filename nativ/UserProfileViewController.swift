//
//  UserProfileViewController.swift
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

class UserProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate, UITextFieldDelegate, EditPondParentProtocol {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    var userID: Int = -2
    var userIDFIR: String = "-2"
    var userHandle: String = "this person"
    var chatID: String = "-2"
    var scrollPosition: String = "top"
    var firstLoad: Bool = true
    var segueSender = "userProfile"
    var isFriend: String = "Z"
    var isRemoved: Bool = false
    var newPostsCount: Int = 0
    var fromHandle: Bool = false 
    var lastContentOffset: CGFloat = 0

    var parentRow: Int = 0
    var imageURLToPass: URL!
    var postContentToPass: String!
    var parentPostToPass: [String:Any] = [:]
    
    var urlArray: [URL] = []
    var postIDArray: [Int] = []
    var heightAtIndexPath: [IndexPath:CGFloat] = [:]
    var userInfo: [String:Any] = [:]
    var userPosts:[[String:Any]] = []
    
    let loadingImageArray: [UIImage] = [UIImage(named: "loading1")!, UIImage(named: "loading2")!, UIImage(named: "loading3")!, UIImage(named: "loading4")!, UIImage(named: "loading5")!, UIImage(named: "loading6")!, UIImage(named: "loading7")!, UIImage(named: "loading7")!]
    
    let misc = Misc()
    var backButton = UIButton()
    var settingsButton = UIButton()
    var settingsBarButton = UIBarButtonItem()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    
    var ref = FIRDatabase.database().reference()
    
    var dimView = UIView()
    
    @IBOutlet weak var userProfileTableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        if let chatMessage = self.messageTextField.text {
            if self.isFriend == "F" {
                self.sendMessage(chatMessage)
            }
        }
    }
    
    @IBOutlet weak var userProfileTableViewTop: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Profile"
        
        self.settingsButton.setImage(UIImage(named: "settingsUnselected"), for: .normal)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .selected)
        self.settingsButton.setImage(UIImage(named: "settingsSelected"), for: .highlighted)
        self.settingsButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.settingsButton.addTarget(self, action: #selector(self.presentUserOptions), for: .touchUpInside)
        self.settingsBarButton.customView = self.settingsButton
        self.navigationItem.rightBarButtonItem = self.settingsBarButton
        
        if self.segueSender == "userProfile" && self.isFriend == "F" {
            self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
            let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeft))
            swipeLeft.direction = .left
            self.view.addGestureRecognizer(swipeLeft)
        }
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.userProfileTableView.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.userProfileTableView.addSubview(refreshControl)
        
        self.userProfileTableView.delegate = self
        self.userProfileTableView.dataSource = self
        self.userProfileTableView.rowHeight = UITableViewAutomaticDimension
        self.userProfileTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.userProfileTableView.showsVerticalScrollIndicator = false
        
        self.sendButton.isEnabled = false
        if self.segueSender == "userProfile" {
            self.setBackButton()
        }
        
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.userProfileTableView.addSubview(self.dimView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            self.unwindToHome()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
        } else {
            self.logViewUserProfile()
            
            if self.segueSender == "userProfile" {
                self.messageTextField.isHidden = true
                self.sendButton.isHidden = true
                self.userProfileTableViewTop.constant = 0
                if self.isFriend == "F" {
                    self.segmentedControl.isHidden = false
                    self.segmentedControl.selectedSegmentIndex = 0
                    self.navigationItem.titleView = self.segmentedControl
                    self.segmentedControl.sizeToFit()
                } else {
                    self.segmentedControl.isHidden = true
                }
            } else {
                self.segmentedControl.isHidden = true

                if self.isFriend == "F" {
                    self.messageTextField.isHidden = false
                    self.sendButton.isHidden = false
                    self.userProfileTableViewTop.constant = 46
                    self.messageTextField.delegate = self
                    self.messageTextField.placeholder = "send \(self.userHandle) a message"
                    self.chatID = misc.setChatID(self.myID, userID: self.userID)
                } else {
                    self.messageTextField.isHidden = true
                    self.sendButton.isHidden = true
                    self.userProfileTableViewTop.constant = 0
                    self.messageTextField.isUserInteractionEnabled = false
                    self.sendButton.isEnabled = false
                    if self.isFriend == "B"  {
                        self.messageTextField.placeholder = "you have been blocked"
                    } else  if self.isFriend == "BB" {
                        self.messageTextField.placeholder = "blocked"
                    } else {
                        self.messageTextField.placeholder = "must be friends to chat"
                    }
                }
            }
            
            self.setNotifications()
            self.observeUserProfile()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.userProfileTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.removeNotifications()
        self.removeObserverForUserProfile()
        self.dismissKeyboard()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.urlArray = []
        self.postIDArray = []
        self.userInfo = [:]
        self.userPosts = []
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        self.urlArray = []
        self.postIDArray = []
        self.userInfo = [:]
        self.userPosts = []
        misc.clearWebImageCache()
        self.getUserProfile()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.userInfo.isEmpty {
            return 1
        }
        
        if !userInfo.isEmpty && self.userPosts.isEmpty {
            return 2
        }
        
        if self.isFriend == "B" || self.isFriend == "BB" {
            return 2
        }
        
        return self.userPosts.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (self.userInfo.isEmpty && indexPath.row == 0) || self.isFriend == "B" || self.isFriend == "BB" || (self.userPosts.isEmpty && indexPath.row == 1) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noUserProfileCell", for: indexPath) as! NoContentTableViewCell
            cell.noContentLabel.numberOfLines = 0
            cell.noContentLabel.textColor = .lightGray
            
            if indexPath.row == 0 {
                if self.firstLoad {
                    cell.noContentLabel.text = "loading profile..."
                } else if self.isFriend == "B" {
                    cell.noContentLabel.text = "Sorry, this person has blocked you."
                } else if self.isFriend == "BB" {
                    cell.noContentLabel.text = "You have blocked this person."
                } else {
                    if self.fromHandle {
                        cell.noContentLabel.text = "Sorry, we couldn't find this person. Please try again, and note that handles are case sensitive. Please report this bug if it persists"
                    } else {
                        cell.noContentLabel.text = "Sorry, we broke something. Unable to see profile at this time."
                    }
                }
            } else {
                if self.firstLoad {
                    cell.noContentLabel.text = "loading profile..."
                } else {
                    cell.noContentLabel.text = "This person has no public posts"
                }
            }
            
            return cell
        }
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userInfoCell", for: indexPath) as! UserInfoTableViewCell
            
            let model = UIDevice.current.modelName
            if model.contains("iPhone") {
                if model.lowercased().contains("plus") {
                    cell.userPicWidth.constant = 175
                    cell.userPicHeight.constant = 175
                } else if model.contains("6") || model.contains("7") || model.contains("8") {
                    cell.userPicWidth.constant = 150
                    cell.userPicHeight.constant = 150
                } else {
                    cell.userPicWidth.constant = 125
                    cell.userPicHeight.constant = 125
                }
            }
            
            let picURL = self.userInfo["picURL"] as! URL
            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
            cell.userPicImageView.sd_setImage(with: picURL)
            cell.userPicImageView.layoutIfNeeded()
            
            cell.userNameLabel.text = self.userInfo["userName"] as? String
            
            let userHandle = self.userInfo["userHandle"] as! String
            cell.userHandleLabel.text = "@\(userHandle)"
            
            let pointsCount = self.userInfo["pointsCount"] as! Int
            cell.pointsCountLabel.text = "\(pointsCount) points"
            
            cell.userDescriptionLabel.numberOfLines = 0
            cell.userDescriptionLabel.text = self.userInfo["userDescription"] as? String
            
            if self.isFriend == "F" {
                cell.friendRequestButton.setImage(UIImage(named: "acceptedSelected"), for: .normal)
                cell.friendRequestButton.setImage(UIImage(named: "acceptedSelected"), for: .highlighted)
                cell.friendRequestButton.setImage(UIImage(named: "acceptedSelected"), for: .selected)
                cell.friendRequestButton.setImage(UIImage(named: "acceptedSelected"), for: .disabled)
                cell.friendRequestButton.isEnabled = false
                cell.friendRequestLabel.text = "Friends ✓"
                cell.friendRequestLabel.textColor = misc.nativColor
            } else if self.isFriend == "S" {
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .normal)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .highlighted)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .selected)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .disabled)
                cell.friendRequestButton.isEnabled = false
                cell.friendRequestLabel.text = "Added"
                cell.friendRequestLabel.textColor = misc.nativColor
            } else if self.isFriend == "R" {
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .normal)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .highlighted)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .selected)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .disabled)
                cell.friendRequestButton.addTarget(self, action: #selector(self.sendFriendRequest), for: .touchUpInside)
                cell.friendRequestButton.isEnabled = true
                cell.friendRequestLabel.text = "Added you; Add them too"
                cell.friendRequestLabel.textColor = misc.nativColor
            } else if self.isFriend == "BB" || self.isFriend == "B" {
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .normal)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .highlighted)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .selected)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .disabled)
                cell.friendRequestButton.isEnabled = false
                cell.friendRequestLabel.text = "Blocked"
                cell.friendRequestLabel.textColor = .red
            } else {
                cell.friendRequestButton.setImage(UIImage(named: "addFriendUnselected"), for: .normal)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .highlighted)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .selected)
                cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .disabled)
                cell.friendRequestButton.addTarget(self, action: #selector(self.sendFriendRequest), for: .touchUpInside)
                cell.friendRequestButton.isEnabled = true
                cell.friendRequestLabel.text = "Add to your Flow"
                cell.friendRequestLabel.textColor = misc.nativColor
            }
            
            return cell
            
        } else {
            var cell: PostTableViewCell
            let individualPost = self.userPosts[indexPath.row - 1]
            if let imageURL = individualPost["imageURL"] as? URL {
                cell = tableView.dequeueReusableCell(withIdentifier: "pondUserImageCell", for: indexPath) as! PostTableViewCell
                let placeholder = UIImage.animatedImage(with: self.loadingImageArray, duration: 0.33)
                let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                    cell.postImageView.image = image
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.setNeedsLayout()
                }
                cell.postImageView.contentMode = .scaleAspectFit
                cell.postImageView.sd_setImage(with: imageURL, placeholderImage: placeholder, options: .progressiveDownload, completed: block)
                let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                cell.postImageView.addGestureRecognizer(tapToViewImage)
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "pondUserCell", for: indexPath) as! PostTableViewCell
            }
            
            let userID = individualPost["userID"] as! Int
            let didIVote = individualPost["didIVote"] as! String
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
            
            cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
            cell.userPicImageView.clipsToBounds = true
            let picURL = individualPost["picURL"] as! URL
            cell.userPicImageView.sd_setImage(with: picURL)
            cell.userNameLabel.text = individualPost["userName"] as? String
            let handle = individualPost["userHandle"] as! String
            cell.userHandleLabel.text = "@\(handle)"
            
            let pointsCount = individualPost["pointsCount"] as! Int
            cell.pointsLabel.text  = misc.setCount(pointsCount)
            
            let postContent = individualPost["postContent"] as! String
            cell.postContentTextView.attributedText = misc.stringWithColoredTags(postContent, time: "default", fontSize: 18, timeSize: 18)
            
            cell.timestampLabel.text = individualPost["timestamp"] as? String
            
            let shareCount = individualPost["shareCount"] as! Int
            cell.shareCountLabel.text = misc.setCount(shareCount)
            let tapSpacerToShare = UITapGestureRecognizer(target: self, action: #selector(self.presentSharePostSheet))
            cell.shareSpacerLabel.addGestureRecognizer(tapSpacerToShare)
            
            let replyCount = individualPost["replyCount"] as! Int
            cell.replyCountLabel.text = misc.setCount(replyCount)
            
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !self.userPosts.isEmpty && indexPath.row > 0 {
            let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
            cell.replyPicImageView.isHighlighted = true
            cell.whiteView.backgroundColor = misc.nativFade
            let individualPost = self.userPosts[indexPath.row - 1]
            let postID = individualPost["postID"] as! Int
            if postID > 0 {
                self.parentPostToPass = individualPost
                self.performSegue(withIdentifier: "fromUserProfileToDrop", sender: self)
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromUserProfileToImage" {
            if let imageViewController = segue.destination as? ImageViewController {
                imageViewController.imageURL = self.imageURLToPass
            }
        }
        
        if segue.identifier == "fromUserProfileToDrop" {
            if let dropViewController = segue.destination as? DropViewController {
                dropViewController.parentPost = self.parentPostToPass
                dropViewController.postID = self.parentPostToPass["postID"] as! Int
                if let _ = self.parentPostToPass["userHandle"] as? String {
                    dropViewController.isAnon = false
                } else {
                    dropViewController.isAnon = true
                }
                dropViewController.segueSender = "pondList"
                dropViewController.editPondParentDelegate = self
            }
        }
    }
    
    func presentImage(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.userProfileTableView)
        let indexPath: IndexPath! = self.userProfileTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        let individualPost = self.userPosts[indexPath.row - 1]
        
        let postContent = individualPost["postContent"] as! String
        let timestamp = individualPost["timestamp"] as! String
        let handle = individualPost["userHandle"] as! String
        let contentToPass = "@\(handle), \(timestamp): \(postContent)"
        
        if let url = individualPost["imageURL"] as? URL {
            self.imageURLToPass = url
            self.postContentToPass = contentToPass
            self.performSegue(withIdentifier: "fromUserProfileToImage", sender: self)
        }
    }
    
    func unwindToPondMap() {
        self.performSegue(withIdentifier: "unwindFromUserProfileToPondMap", sender: self)
    }
    
    func unwindToPondList() {
        self.performSegue(withIdentifier: "unwindFromUserProfileToPondList", sender: self)
    }
    
    func unwindToDropList() {
        self.performSegue(withIdentifier: "unwindFromUserProfileToDropList", sender: self)
    }
    
    func unwindToFriendList() {
        self.performSegue(withIdentifier: "unwindFromUserProfileToFriendList", sender: self)
    }
    
    func unwindToNotifications() {
        self.performSegue(withIdentifier: "unwindFromUserProfileToNotifications", sender: self)
    }
    
    func unwindToHome() {
        switch self.segueSender {
        case "pondMap", "pondList", "dropList":
            self.navigationController?.popViewController(animated: true)
        case "mapDrop":
            self.unwindToPondMap()
        case "listDrop":
            self.unwindToPondList()
        case "drop":
            self.unwindToDropList()
        case "notification":
            self.unwindToNotifications()
        default:
            self.unwindToFriendList()
        }
    }
    
    func presentUserOptions(_ sender: UIButton) {
        self.settingsButton.isSelected = true
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if self.isFriend == "F" {
            let unfriendAction = UIAlertAction(title: "Unfriend", style: .default, handler: { action in
                self.logUnFriended()
                self.editFriendRequest("unfriend")
                self.settingsButton.isSelected = false
            }
            )
            alertController.addAction(unfriendAction)
        }
        
        if self.isFriend == "S" {
            let removeFlowAction = UIAlertAction(title: "Remove from Flow", style: .default, handler: { action in
                self.logRemovedFromFlow()
                self.editFriendRequest("withdraw")
                self.settingsButton.isSelected = false
            }
            )
            alertController.addAction(removeFlowAction)
        }
        
        if self.isFriend != "BB" && self.isFriend != "B" {
            let blockAction = UIAlertAction(title: "Block", style: .default, handler: { action in
                self.logUserBlocked()
                self.editFriendRequest("block")
                self.settingsButton.isSelected = false
            })
            alertController.addAction(blockAction)
        }
        
        if self.isFriend == "BB" {
            let unblockAction = UIAlertAction(title: "Unblock", style: .default, handler: { action in
                self.logUserUnBlocked()
                self.editFriendRequest("unblock")
                self.settingsButton.isSelected = false
            })
            alertController.addAction(unblockAction)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            self.settingsButton.isSelected = false
        })
        )
        
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: {
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func swipeLeft() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToChat"), object: nil)
    }
    
    // MARK: - EditPondParent Protocol
    
    func editPondContent(_ postContent: String, timestamp: String) {
        self.userPosts[self.parentRow - 1]["postContent"] = postContent
        self.userPosts[self.parentRow - 1]["timestamp"] = "edited \(timestamp)"
    }
    
    func deletePondParent() {
        if self.userPosts.count == 1 {
            self.userPosts = []
        } else {
            self.userPosts.remove(at: self.parentRow - 1)
        }
    }
    
    func updatePondReplyCount(_ replyCount: Int) {
        self.userPosts[self.parentRow - 1]["replyCount"] = replyCount
    }
    
    func updatePondPointCount(_ pointsCount: Int) {
        self.userPosts[self.parentRow - 1]["pointsCount"] = pointsCount
        self.userPosts[self.parentRow - 1]["didIVote"] = "yes"
    }
    
    
    // MARK: - Popover
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.settingsButton.isSelected = false
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForUserProfile()
            self.isRemoved = true
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        if offset == 0 {
            self.scrollPosition = "top"
            self.observeUserProfile()
        } else if (offset == (contentHeight - frameHeight)) {
            self.scrollPosition = "bottom"
            if self.userPosts.count >= 42 {
                self.getUserProfile()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        let posts = self.userPosts
        if !posts.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.userProfileTableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.userProfileTableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
                    let maxCount = posts.count + 1
                    if nextLastRow > (maxCount - 1) {
                        nextLastRow = maxCount - 1
                    }
                    
                    if nextLastRow > lastRow {
                        nextLastRow = lastRow
                    }
                    
                    var urlsToPrefetch: [URL] = []
                    for index in lastRow...nextLastRow {
                        let post = posts[index - 1]
                        if let picURL = post["picURL"] as? URL {
                            urlsToPrefetch.append(picURL)
                        }
                        if let imageURL = post["imageURL"] as? URL {
                            urlsToPrefetch.append(imageURL)
                        }
                    }
                    SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch)
                }
            }
        }
        self.lastContentOffset = scrollView.contentOffset.y
    }
    
    // MARK: TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        guard let text = textField.text else { return true }
        
        if text.characters.count >= 1 {
            self.sendButton.isEnabled = true
        } else {
            self.sendButton.isEnabled = false
        }
        
        let length = text.characters.count + string.characters.count - range.length
        return length <= 191
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.dismissKeyboard()
    }
    
    func sortCriteriaDidChange(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 1 {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "turnToChat"), object: nil)
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        self.dimBackground(true)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
    }
    
    // MARK: - Notifications
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.unwindToHome), name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForUserProfile), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
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
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.userProfileTableView.frame.origin.y + 8, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: "top")
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.lastContentOffset = 0
        self.userProfileTableView.setContentOffset(.zero, animated: false)
        self.scrollToTopButton.removeFromSuperview()
    }
    
    func setBackButton() {
        self.backButton.setImage(UIImage(named: "backButton"), for: .normal)
        self.backButton.setTitle(" Added", for: .normal)
        self.backButton.addTarget(self, action: #selector(self.unwindToFriendList), for: .touchUpInside)
        self.backButton.setTitleColor(misc.nativColor, for: .normal)
        self.backButton.sizeToFit()
        self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: self.backButton), animated: false)
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
    
    // MARK: - Analytics
    
    func logViewUserProfile() {
        FIRAnalytics.logEvent(withName: "viewUserProfile", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logAdded() {
        FIRAnalytics.logEvent(withName: "addedToFlow", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logRemovedFromFlow() {
        FIRAnalytics.logEvent(withName: "removedFromFlow", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logFriended() {
        FIRAnalytics.logEvent(withName: "addedToFlowBackFriends", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logUnFriended() {
        FIRAnalytics.logEvent(withName: "unfriendedUser", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logUserBlocked() {
        FIRAnalytics.logEvent(withName: "blockedUser", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "friendID": self.userID as NSObject,
            "friendIDFIR": self.userIDFIR as NSObject
            ])
    }
    
    func logUserUnBlocked() {
        FIRAnalytics.logEvent(withName: "unblockedUser", parameters: [
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
    
    func logPondPostShared(_ postID: Int, socialMedia: String) {
        FIRAnalytics.logEvent(withName: "pondPostShared", parameters: [
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
    
    // MARK: Firebase
    
    func writeRequestAction(_ userIDFIR:String) {
        self.ref.child("users").child(userIDFIR).child("friendList").child("addedMe").child(self.myIDFIR).setValue(true)
        self.ref.child("users").child(self.myIDFIR).child("friendList").child("added").child(self.userIDFIR).setValue(true)
    }
    
    func writeAcceptAction(_ userIDFIR: String) {
        self.ref.child("users").child(userIDFIR).child("friendList").child("added").child(myIDFIR).removeValue()
        self.ref.child("users").child(self.myIDFIR).child("friendList").child("addedMe").child(userIDFIR).removeValue()

        self.ref.child("users").child(self.myIDFIR).child("friendList").child("friends").child(userIDFIR).setValue(true)
        self.ref.child("users").child(userIDFIR).child("friendList").child("friends").child(self.myIDFIR).setValue(true)
    }
    
    func writeUnFriend(_ userIDFIR: String) {
        self.ref.child("users").child(self.myIDFIR).child("friendList").child("friends").child(userIDFIR).removeValue()
        self.ref.child("users").child(userIDFIR).child("friendList").child("friends").child(self.myIDFIR).removeValue()
    }
    
    func writeChatMessage(_ message: String, messageID: Int) {
        let userRef = self.ref.child("users")
        userRef.child(self.userIDFIR).child("friendList").child("lastMessage").setValue(["userID": self.myID, "message": message])
        
        let chatRef = self.ref.child("chats").child(self.chatID).child("messages")
        chatRef.child("\(messageID)").setValue(["message": message, "timestamp": misc.getTimestamp("UTC"), "senderID": self.myID])
    }
    
    func observeUserProfile() {
        if self.firstLoad || self.scrollPosition == "top" {
            self.isRemoved = false
            let postRef = self.ref.child("users").child(self.userIDFIR).child("posts")
            postRef.observe(.value, with: {
                (snapshot) -> Void in
                self.getNewPosts()
            })
        }
    }
    
    func removeObserverForUserProfile() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let postRef = self.ref.child("users").child(self.userIDFIR).child("posts")
        postRef.removeAllObservers()
    }
    
    func writePostShared(_ postID: Int) {
        let pondRef = self.ref.child("posts").child("\(postID)").child("parent").child("shareCount")
        pondRef.observeSingleEvent(of: .value, with: {
            (snapshot) -> Void in
            if let shareCount = snapshot.value as? Int {
                let newCount = shareCount + 1
                pondRef.setValue(newCount)
            }
        })
    }
    
    func writePostUpvoted(_ postID: Int) {
        let pondRef = self.ref.child("posts").child("\(postID)").child("points")
        pondRef.observeSingleEvent(of: .value, with: {
            (snapshot) -> Void in
            if let points = snapshot.value as? Int {
                let newPoints = points + 1
                pondRef.setValue(newPoints)
            }
        })
    }
    
    // MARK: - AWS
    
    func getNewPosts() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newPostsCount += 1
        }
        
        if self.newPostsCount == 3 || self.firstLoad {
            self.perform(#selector(self.getUserProfile), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getUserProfile), with: nil, afterDelay: 0.5)
        }
    }
    
    func presentSharePostSheet(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.userProfileTableView)
        let indexPath: IndexPath! = self.userProfileTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        
        let cell = self.userProfileTableView.cellForRow(at: indexPath) as! PostTableViewCell
        cell.sharePicImageView.isHighlighted = true
        
        let individualPost = self.userPosts[indexPath.row - 1]
        let postID = individualPost["postID"] as! Int
        let postContent = individualPost["postContent"] as! String
        
        let shareCount = individualPost["shareCount"] as! Int
        let newShareCount = shareCount + 1
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let shareFBAction = UIAlertAction(title: "Share on Facebook", style: .default, handler: { action in
            cell.sharePicImageView.isHighlighted = false
            cell.shareCountLabel.text = "\(newShareCount)"
            
            if let imageURL = individualPost["imageURL"] as? URL {
                self.sharePhotoFB(imageURL)
            } else {
                self.shareOnFB(cell.whiteView)
            }
            self.sharePost(postID, postContent: postContent, socialMedia: "Facebook")
            self.userPosts[indexPath.row - 1]["shareCount"] = newShareCount
        })
        alertController.addAction(shareFBAction)
        
        let shareTwitterAction = UIAlertAction(title: "Share on Twitter", style: .default, handler: { action in
            cell.sharePicImageView.isHighlighted = false
            cell.shareCountLabel.text = "\(newShareCount)"
            
            if let imageURL = individualPost["imageURL"] as? URL {
                self.sharePhotoTwitter(imageURL)
            } else {
                self.shareOnTwitter(cell.whiteView)
            }
            self.sharePost(postID, postContent: postContent, socialMedia: "Twitter")
            self.userPosts[indexPath.row - 1]["shareCount"] = newShareCount
            
        })
        alertController.addAction(shareTwitterAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            cell.sharePicImageView.isHighlighted = false
        })
        )
        
        alertController.view.tintColor = misc.nativColor
        DispatchQueue.main.async(execute: { self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func sharePost(_ postID: Int, postContent: String, socialMedia: String) {
        let postType: String = "pond"
        
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
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&postID=\(postID)&postType=\(postType)&postContent=\(postContent)&socialMedia=\(socialMedia)"
            
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
                                self.logPondPostShared(postID, socialMedia: socialMedia)
                                self.writePostShared(postID)
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
    
    func upvotePost(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.userProfileTableView)
        let indexPath: IndexPath! = self.userProfileTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        
        let individualPost = self.userPosts[indexPath.row - 1]
        let didIVote = individualPost["didIVote"] as! String
        let postID = individualPost["postID"] as! Int
        
        if didIVote == "no" && postID > 0 {
            let currentPoints = individualPost["pointsCount"] as! Int
            let newPoints = currentPoints + 1
            self.userPosts[indexPath.row - 1]["pointsCount"] = newPoints
            self.userPosts[indexPath.row - 1]["didIVote"] = "yes"
            self.userProfileTableView.reloadRows(at: [indexPath], with: .none)
            
            let postID = individualPost["postID"] as! Int
            let postType: String = "pond"
            
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
                                    self.logPondPostUpvoted(postID)
                                    self.writePostUpvoted(postID)
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
    
    func editFriendRequest(_ action: String) {
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let actionURL = URL(string: "https://dotnative.io/sendFriendRequest")
            var actionRequest = URLRequest(url: actionURL!)
            actionRequest.httpMethod = "POST"
            
            let actionString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(self.userID)&action=\(action)"
            
            actionRequest.httpBody = actionString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: actionRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert(":(", alertMessage: "Sorry, no internet. Please try again later.")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your response may not have been sent. Please report the bug in by going to the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                switch action {
                                case "unfriend":
                                    self.writeUnFriend(self.userIDFIR)
                                    self.isFriend = "N"
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "removeFriend"), object: nil)
                                    self.displayAlert("Unfriended", alertMessage: "You have unfriended this person.")
                                case "block":
                                    self.isFriend = "BB"
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "setFirstLoadFriendList"), object: nil)
                                    self.displayAlert("Blocked", alertMessage: "You have blocked this person. Sorry that some people are just not cool. Don't let it ruin your day!")
                                    self.messageTextField.isUserInteractionEnabled = false
                                    self.sendButton.isEnabled = false
                                    self.messageTextField.placeholder = "blocked"
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "setIsFriendBB"), object: nil)
                                default:
                                    self.isFriend = "N"
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "setFirstLoadFriendList"), object: nil)
                                    if action == "withdraw" {
                                        self.displayAlert("Removed from Flow", alertMessage: "You have removed this person from your Flow. Their public posts will no longer show up in the added section of the Flow.")
                                    }
                                    if action == "unblock" {
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "setIsFriendN"), object: nil)
                                        self.displayAlert("Unblocked", alertMessage: "You have unblocked this person.")
                                        self.messageTextField.isUserInteractionEnabled = true
                                        self.messageTextField.placeholder = "send \(self.userHandle) a message"
                                    }
                                }
                                self.messageTextField.isHidden = true
                                self.sendButton.isHidden = true
                                self.segmentedControl.isHidden = true
                                self.userProfileTableViewTop.constant = 0
                                if let cell = self.userProfileTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UserInfoTableViewCell {
                                    cell.friendRequestButton.isSelected = false
                                }
                                self.userProfileTableView.reloadData()
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
    
    func sendFriendRequest(_ sender: UIButton) {
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = self.userProfileTableView.cellForRow(at: indexPath) as! UserInfoTableViewCell
        cell.friendRequestButton.isEnabled = false
        
        var action: String
        if self.isFriend == "R" {
            action = "accept"
        } else {
            action = "request"
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let actionURL = URL(string: "https://dotnative.io/sendFriendRequest")
            var actionRequest = URLRequest(url: actionURL!)
            actionRequest.httpMethod = "POST"
            
            let actionString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(self.userID)&action=\(action)"
            
            actionRequest.httpBody = actionString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: actionRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    self.displayAlert(":(", alertMessage: "Sorry, no internet. Please try again later to add friend.")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            
                            if status == "error" {
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your request may not have gone through. Please report the bug in by going to the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                DispatchQueue.main.async(execute: {
                                    if self.isFriend == "R" {
                                        self.logFriended()
                                        self.writeAcceptAction(self.userIDFIR)
                                        self.displayAlert("Yay!", alertMessage: "You're now friends. You can chat now :)")
                                        cell.friendRequestButton.isEnabled = true
                                        cell.friendRequestButton.isSelected = false
                                        self.isFriend = "F"
                                        if self.segueSender == "userProfile" {
                                            self.segmentedControl.isHidden = false
                                            self.segmentedControl.selectedSegmentIndex = 0
                                            self.navigationItem.titleView = self.segmentedControl
                                            self.segmentedControl.sizeToFit()
                                            self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
                                            let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeft))
                                            swipeLeft.direction = .left
                                            self.view.addGestureRecognizer(swipeLeft)
                                        } else {
                                            self.messageTextField.isHidden = false
                                            self.sendButton.isHidden = false
                                            self.userProfileTableViewTop.constant = 46
                                            self.messageTextField.delegate = self
                                            self.messageTextField.placeholder = "send \(self.userHandle) a message"
                                            self.chatID = self.misc.setChatID(self.myID, userID: self.userID)
                                        }
                                        
                                    } else {
                                        self.logAdded()
                                        self.writeRequestAction(self.userIDFIR)
                                        self.displayAlert("Added to Flow", alertMessage: "You've added the person to your Flow. Their public posts will now show up in the friend/added segment of the Flow.")
                                        cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .normal)
                                        cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .highlighted)
                                        cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .selected)
                                        cell.friendRequestButton.setImage(UIImage(named: "addFriendSelected"), for: .disabled)
                                        cell.friendRequestButton.isEnabled = false
                                        self.isFriend = "S"
                                    }
                                    
                                    self.userProfileTableView.reloadData()
                                })
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
    
    func getUserProfile() {
        self.newPostsCount = 0
        let limitInfo: String = "no"
        let userPicSize: String = "large"
        let picSize: String = "small"
        
        var lastPostID: Int
        if self.scrollPosition == "bottom" && self.userPosts.count >= 42 {
            let lastPost = self.userPosts.last!
            lastPostID = lastPost["postID"] as! Int
            self.displayActivity("loading more posts...", indicator: true)
        } else {
            lastPostID = 0
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let getProfURL = URL(string: "https://dotnative.io/getUserProfile")
            let getProfRequest = NSMutableURLRequest(url: getProfURL!)
            getProfRequest.httpMethod = "POST"
            
            var getString: String
            if self.fromHandle && self.firstLoad {
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userHandle=\(self.userHandle)&limitInfo=\(limitInfo)&userPicSize=\(userPicSize)&size=\(picSize)&lastPostID=\(lastPostID)"
            } else {
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&userID=\(self.userID)&limitInfo=\(limitInfo)&userPicSize=\(userPicSize)&size=\(picSize)&lastPostID=\(lastPostID)"
            }
            
            getProfRequest.httpBody = getString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: getProfRequest as URLRequest) {
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
                        print(parseJSON)    
                        DispatchQueue.main.async(execute: {
                            self.activityView.removeFromSuperview()
                            
                            if status == "error" {
                                self.firstLoad = false
                                self.userProfileTableView.reloadData()
                                self.displayAlert("Oops", alertMessage: "We've encountered an error and can't load this profile. Please report the bug in by going to the report section of the menu.")
                                return
                            }
                            
                            if status == "success" {
                                self.userIDFIR = parseJSON["firebaseID"] as! String
                                self.userID = parseJSON["userID"] as! Int
                                self.chatID = self.misc.setChatID(self.myID, userID: self.userID)
                                
                                let isFriend = parseJSON["isFriend"] as! String
                                self.isFriend = isFriend
                                if self.segueSender == "userProfile" {
                                    self.messageTextField.isHidden = true
                                    self.sendButton.isHidden = true
                                    self.userProfileTableViewTop.constant = 0
                                    if self.isFriend == "F" {
                                        self.segmentedControl.isHidden = false
                                        self.segmentedControl.selectedSegmentIndex = 0
                                        self.navigationItem.titleView = self.segmentedControl
                                        self.segmentedControl.sizeToFit()
                                    } else {
                                        self.segmentedControl.isHidden = true 
                                    }
                                } else {
                                    self.segmentedControl.isHidden = true
                                    
                                    if self.isFriend == "F" {
                                        self.messageTextField.isHidden = false
                                        self.sendButton.isHidden = false
                                        self.userProfileTableViewTop.constant = 46
                                        self.messageTextField.delegate = self
                                        self.messageTextField.placeholder = "send \(self.userHandle) a message"
                                        self.chatID = self.misc.setChatID(self.myID, userID: self.userID)
                                    } else {
                                        self.messageTextField.isHidden = true
                                        self.sendButton.isHidden = true
                                        self.userProfileTableViewTop.constant = 0
                                        self.messageTextField.isUserInteractionEnabled = false
                                        self.sendButton.isEnabled = false
                                        if self.isFriend == "B"  {
                                            self.messageTextField.placeholder = "you have been blocked"
                                        } else  if self.isFriend == "BB" {
                                            self.messageTextField.placeholder = "blocked"
                                        } else {
                                            self.messageTextField.placeholder = "must be friends to chat"
                                        }
                                    }
                                }
                                
                                let userName = parseJSON["userName"] as! String
                                let userHandle = parseJSON["userHandle"] as! String

                                let pointsCount = parseJSON["pointsCount"] as! Int
                                let userDescription = parseJSON["userDescription"] as! String
                                
                                let key = parseJSON["key"] as! String
                                let bucket = parseJSON["bucket"] as! String
                                let picURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
                                if !self.urlArray.contains(picURL) {
                                    self.urlArray.append(picURL)
                                    SDWebImagePrefetcher.shared().prefetchURLs([picURL])
                                }
                                
                                let user: [String:Any] = ["userName" : userName, "userHandle" : userHandle, "pointsCount": pointsCount, "userDescription": userDescription, "picURL": picURL]
                                self.userInfo = user
                                
                                if let postsArray = parseJSON["pondPosts"] as? [[String:Any]] {
                                    var posts: [[String:Any]] = []
                                    for individualPost in postsArray {
                                        
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
                                        let pointsCount = individualPost["pointsCount"] as! Int
                                        let didIVote = individualPost["didIVote"] as! String
                                        let replyCount = individualPost["replyCount"] as! Int
                                        let shareCount = individualPost["shareCount"] as! Int
                                        
                                        let long = individualPost["longitude"] as! String
                                        let longitude = Double(long)!
                                        let lat = individualPost["latitude"] as! String
                                        let latitude = Double(lat)!
                                        
                                        let imageKey = individualPost["imageKey"] as! String
                                        let imageBucket = individualPost["imageBucket"] as! String
                                        
                                        let userName = individualPost["userName"] as! String
                                        let userHandle = individualPost["userHandle"] as! String
                                        
                                        let key = individualPost["key"] as! String
                                        let bucket = individualPost["bucket"] as! String
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
                                        
                                        posts.append(post)
                                    }
                                    
                                    if lastPostID != 0 {
                                        let latestPost = posts.last!
                                        if lastPostID != latestPost["postID"] as! Int {
                                            self.userPosts.append(contentsOf: posts)
                                            if self.userPosts.count > 210 {
                                                let difference = self.userPosts.count - 210
                                                let indicesToRemove = 0...(difference-1)
                                                self.userPosts = self.userPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                            }
                                        }
                                    } else {
                                        self.userPosts = posts
                                    }
                                    
                                    if !posts.isEmpty {
                                        var firstRows = 3
                                        let maxCount = posts.count
                                        if firstRows > (maxCount - 1) {
                                            firstRows = maxCount - 1
                                        }
                                        
                                        var urlsToPrefetch: [URL] = []
                                        for index in 0...firstRows {
                                            let post = posts[index]
                                            if let picURL = post["picURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                            if let picURL = post["imageURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                        }
                                        
                                        SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                            self.firstLoad = false
                                            self.userProfileTableView.reloadData()
                                        })
                                    }  else {
                                        self.firstLoad = false
                                        self.userProfileTableView.reloadData()
                                    }
                                } else {
                                    self.firstLoad = false
                                    self.userProfileTableView.reloadData()
                                }// parse dict
                                
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug in by going to the report section of the menu.")
            return
        }
    }
    
    func sendMessage (_ chatMessage: String) {
        self.dismissKeyboard()
        self.messageTextField.text = ""
        self.sendButton.isEnabled = false
        
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
                                self.messageTextField.placeholder = "send another message"
                                if let messageID = parseJSON["chatID"] as? Int {
                                    self.writeChatMessage(chatMessage, messageID: messageID)
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
    
    func refreshWithDelay() {
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observeUserProfile), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getUserProfile), with: nil, afterDelay: 0.5)
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

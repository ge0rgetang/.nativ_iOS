//
//  PondListViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import FirebaseAnalytics
import FirebaseDatabase
import GoogleMobileAds
import SDWebImage
import CryptoSwift
import FBSDKShareKit
import TwitterKit
import SideMenu
import MIBadgeButton_Swift

class PondListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, EditPondParentProtocol, SendImagePostProtocol {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var segment: String = "pond" {
        didSet {
            if self.segment == "trendingList" {
                self.pondListTableView.separatorStyle = UITableViewCellSeparatorStyle.singleLine
            } else {
                self.pondListTableView.separatorStyle = UITableViewCellSeparatorStyle.none
            }
        }
    }
    var firstLoad: Bool = true
    var firstLoadConstraints: Bool = true
    var isKeyboardUp: Bool = false
    var scrollPosition: String = "top"
    var newPostsCount: Int = 0
    var parentRow: Int = 0
    var isRemoved = false
    var textViewText: String = "post around you - tag with .place or @userHandle"
    var isEditingLocation = false
    var isTextSaved: Bool = false
    
    var fromTag: Bool = false
    
    var radius: Double = 0.5
    var needToUpdateRadius: Bool = false
    var timeDel: Int = 0
    
    var locationManager: CLLocationManager!
    var longitude: Double = -122.258542
    var latitude: Double = 37.871906
    var locationText: String = "here"
    
    var parentPostToPass: [String:Any] = [:]
    var userIDToPass: Int = -2
    var userIDFIRToPass: String = "-2"
    var userHandleToPass: String = "-2"
    var imageToPass: UIImage!
    var imageURLToPass: URL!
    var postContentToPass: String!
    var fromHandle: Bool = false
    
    var urlArray: [URL] = []
    var postIDArray: [Int] = []
    var pondHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var anonHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var hotHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var trendingHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var friendHeightAtIndexPath: [IndexPath:CGFloat] = [:]
    var pondPosts: [[String:Any]] = []
    var anonPosts: [[String:Any]] = []
    var hotPosts: [[String:Any]] = []
    var trendingList: [[String:Any]] = []
    var trendingPosts: [[String:Any]] = []
    var tagsToRemove: [String] = []
    var friendPosts: [[String:Any]] = []
    var lastContentOffset: CGFloat = 0
        
    let misc = Misc()
    var activityView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var activityLabel = UILabel()
    var scrollToTopButton = UIButton()
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    var dimView = UIView()
    var nativeExpressAdArray = [GADNativeExpressAdView]()
    
    var ref = FIRDatabase.database().reference()
    
    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var myLocationBarButton: UIBarButtonItem!
    @IBAction func myLocationBarButtonTapped(_ sender: Any) {
        self.checkAuthorizationStatus()
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if let long = self.locationManager.location?.coordinate.longitude {
                self.longitude = long
            }
            if let lat = self.locationManager.location?.coordinate.latitude {
                self.latitude = lat
            }
            self.firstLoad = true
            if self.locationText != "here" {
                self.clearArrays()
            }
            self.locationTextField.text = ""
            self.locationTextField.text = "here"
            self.getLocation(self.locationTextField.text!)
        }
    }
    
    @IBOutlet weak var mapListSegmentedControl: UISegmentedControl!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    @IBOutlet weak var pondListTableView: UITableView!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBAction func cameraButtonTapped(_ sender: Any) {
        self.selectPicSource()
    }
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var characterCountLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonTapped(_ sender: Any) {
        if (self.segment == "pond" || self.segment == "anon") && self.textView.textColor == .black && self.textView.text != "" {
            self.sendPost()
        }
    }
    
    @IBOutlet weak var cameraLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var sendTrailingConstraint: NSLayoutConstraint!
    
    @IBAction func unwindToPondList(_ segue: UIStoryboardSegue){
        if let pondMapViewController = segue.source as? PondMapViewController {
            self.firstLoadConstraints = true
            self.segment = pondMapViewController.segment
            self.locationText = pondMapViewController.locationText
            self.longitude = pondMapViewController.longitude
            self.latitude = pondMapViewController.latitude
            self.pondPosts = pondMapViewController.pondPosts
            self.anonPosts = pondMapViewController.anonPosts
            self.hotPosts = pondMapViewController.hotPosts
            self.friendPosts = pondMapViewController.friendPosts
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager = CLLocationManager()
        self.checkAuthorizationStatus()
        self.navigationItem.title = "Flow"
        self.navigationItem.titleView = self.locationTextField

        self.mapListSegmentedControl.selectedSegmentIndex = 1
        self.mapListSegmentedControl.addTarget(self, action: #selector(self.mapListDidChange), for: .valueChanged)
        
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
        self.locationTextField.delegate = self
        self.locationTextField.placeholder = "here, zip, city"
        
        self.textView.delegate = self
        misc.formatTextView(self.textView)
        misc.setTextViewPlaceholder(self.textView, placeholder: "post around you - tag with .place or @userHandle")
        self.sendButton.isEnabled = false
        self.characterCountLabel.isHidden = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 160.934
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        self.pondListTableView.delegate = self
        self.pondListTableView.dataSource = self
        self.pondListTableView.rowHeight = UITableViewAutomaticDimension
        self.pondListTableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.pondListTableView.backgroundColor = misc.softGrayColor
        self.pondListTableView.showsVerticalScrollIndicator = false
        self.pondListTableView.separatorInset = UIEdgeInsets.zero
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefreshControl), for: .valueChanged)
        self.pondListTableView.addSubview(refreshControl)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.pondListTableView.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        let swipeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeRight))
        swipeRight.direction = .right
        self.pondListTableView.addGestureRecognizer(swipeRight)
        swipeRight.cancelsTouchesInView = false
        
        let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeft))
        swipeLeft.direction = .left
        self.pondListTableView.addGestureRecognizer(swipeLeft)
        swipeLeft.cancelsTouchesInView = false

        self.setSideMenu()
        self.setMenuBarButton()
        
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.pondListTableView.addSubview(self.dimView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.mapListSegmentedControl.selectedSegmentIndex = 1
        if self.isTextSaved && (self.segment == "pond" || self.segment == "anon") {
            self.isTextSaved = false
        } else {
            self.setTextViewPlaceholder()
        }
        
        self.locationTextField.text = self.locationText
        
        self.fromTag = UserDefaults.standard.bool(forKey: "fromTag.nativ")
        if self.fromTag {
            UserDefaults.standard.set(false, forKey: "fromTag.nativ")
            UserDefaults.standard.synchronize()
            self.fromTag = false
            
            self.segmentedControl.selectedSegmentIndex = 3
            if let tag = UserDefaults.standard.string(forKey: "locationTag.nativ") {
                self.segment = "trending"
                self.trendingPosts = []
                self.firstLoad = true
                self.textView.text = ".\(tag)"
                self.textView.textColor = .black
                self.textView.font = UIFont.systemFont(ofSize: 18.0)
            } else {
                self.segment = "trendingList"
                self.setTextViewConstraints()
            }
        } else {
            switch self.segment {
            case "pond":
                self.segmentedControl.selectedSegmentIndex = 0
            case "anon":
                self.segmentedControl.selectedSegmentIndex = 1
            case "hot":
                self.segmentedControl.selectedSegmentIndex = 2
            case "trendingList", "trending":
                self.segmentedControl.selectedSegmentIndex = 3
            case "friend":
                self.segmentedControl.selectedSegmentIndex = 4
            default:
                self.segmentedControl.selectedSegmentIndex = 0
            }
            self.setTextViewConstraints()
        }
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "signedOut"), object: nil)
            
            self.textView.isUserInteractionEnabled = false
            misc.setTextViewPlaceholder(self.textView, placeholder: "Sign in to post!")
            self.sendButton.isEnabled = false
            self.cameraButton.isEnabled = false
        } else {
            if self.textView.textColor == .lightGray {
                self.setTextViewPlaceholder()
            }
            self.textView.isUserInteractionEnabled = true
            self.cameraButton.isEnabled = true 
        }
        
        self.locationTextField.text = self.locationText
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            self.locationManager.startUpdatingLocation()
        } else {
            if let text = self.locationTextField.text {
                if text.lowercased() != "here" {
                    self.getLocation(text)
                }
            }
        }
        
        self.logViewPondList()
        misc.setSideMenuIndex(0)
        self.updateBadge()
        self.setNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.checkAuthorizationStatus()
        self.pondListTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPond()
        self.dismissKeyboard()
        if self.urlArray.count >= 210 {
            self.clearArrays()
            if let url = self.imageURLToPass {
                SDWebImagePrefetcher.shared().prefetchURLs([url])
            }
        }
        
        if (self.segment == "pond" || self.segment == "anon") && self.textView.textColor == .black {
            self.isTextSaved = true
        }
        
        self.removeNotifications()
    }
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        NotificationCenter.default.removeObserver(self)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPond()
        self.clearArrays()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.firstLoad = true
        self.clearArrays()
        misc.clearWebImageCache()
        self.observePond()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trendingList":
            posts = self.trendingList
        case "trending":
            posts = self.trendingPosts
        case "friend":
            posts = self.friendPosts
        default:
            posts = []
        }
        
        if posts.isEmpty {
            return 1
        } else {
            return posts.count 
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // if no posts
        if (self.segment == "pond" && self.pondPosts.isEmpty) || (self.segment == "anon" && self.anonPosts.isEmpty) || (self.segment == "hot" && self.hotPosts.isEmpty) || (self.segment == "trendingList" && self.trendingList.isEmpty) || (self.segment == "trending" && self.trendingPosts.isEmpty) || (self.segment == "friend" && self.friendPosts.isEmpty) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "noPondCell", for: indexPath) as! NoContentTableViewCell
            if self.firstLoad {
                cell.noContentLabel.text = "loading..."
            } else {
                switch self.segment {
                case "pond":
                    cell.noContentLabel.text = "Sorry, no posts around you found. Try another location in the location field above. You can also type a message below and be the first :)"
                case "anon":
                    cell.noContentLabel.text = "Sorry, no anonymous posts around you found. Try another location in the location field above. You can also type a message below and be the first :)"
                case "hot":
                    cell.noContentLabel.text = "Sorry, no hot posts over the past few days found. You can try to post yourself and see if it gets popular!"
                case "trendingList":
                    cell.noContentLabel.text = "Sorry, no trending tags in the area. You can tag posts with .place when writing a post (ex .campus, .thisCafe, .localGym)"
                case "trending":
                    cell.noContentLabel.text = "Sorry, no posts with that tag found in the area. Try another tag or another location. Leave the bottom field empty to view a list of trending tags."
                case "friend":
                    if self.myID <= 0 {
                        cell.noContentLabel.text = "Please sign in to add people to your Flow."
                    } else {
                        cell.noContentLabel.text = "No friends/people you've added have made public posts. Tap on the menu button in the top left and go to the chats/friends section to search for and add friends :)"
                    }
                default:
                    cell.noContentLabel.text = "oops we messed up"
                }
            }
            return cell
        }
        
        // sorting based on selected segment
        var individualPost: [String:Any]
        switch self.segment {
        case "pond":
            individualPost = self.pondPosts[indexPath.row]
        case "anon":
            individualPost = self.anonPosts[indexPath.row]
        case "hot":
            individualPost = self.hotPosts[indexPath.row]
        case "trendingList":
            individualPost = self.trendingList[indexPath.row]
        case "trending":
            individualPost = self.trendingPosts[indexPath.row]
        case "friend":
            individualPost = self.friendPosts[indexPath.row]
        default:
            individualPost = [:]
        }
        
        // sorting based on ad, trending, normal
        var postID: Int
        if let id = individualPost["postID"] as? Int {
            postID = id
        } else {
            postID = 0
        }
        
        if postID == -2 {
            // ad
            let cell = tableView.dequeueReusableCell(withIdentifier: "adCell", for: indexPath)
            let ads = self.nativeExpressAdArray
            var ad: GADNativeExpressAdView
            let index = self.getAdIndex(indexPath.row)
            if index > ads.count - 1 {
                ad = ads.first!
            } else {
                ad =  ads[index]
            }
            
            for subview in cell.contentView.subviews {
                subview.removeFromSuperview()
            }
            cell.contentView.addSubview(ad)
            ad.center = CGPoint(x: cell.contentView.frame.midX, y: cell.contentView.frame.midY - 2)
            return cell
            
        } else if self.segment == "trendingList" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "trendingListCell", for: indexPath) as! TrendingTableViewCell
            let trendingTag = individualPost["tag"] as! String
            cell.trendingTagLabel.text = ".\(trendingTag)"
            cell.backgroundColor = .white
            let count = individualPost["info"] as! Int
            let countFormatted = misc.setCount(count)
            cell.infoLabel.text = "\(countFormatted) mention(s)"
            return cell
            
        } else {
            // normal posts
            var cell: PostTableViewCell
            switch self.segment {
            case "pond", "friend":
                if let imageURL = individualPost["imageURL"] as? URL {
                    cell = tableView.dequeueReusableCell(withIdentifier: "pondListImageCell", for: indexPath) as! PostTableViewCell
                    let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                        cell.postImageView.image = image
                        cell.setNeedsLayout()
                    }
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.postImageView.sd_setImage(with: imageURL, placeholderImage: nil, options: .progressiveDownload, completed: block)
                    let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                    cell.postImageView.addGestureRecognizer(tapToViewImage)
                } else {
                    cell = tableView.dequeueReusableCell(withIdentifier: "pondListCell", for: indexPath) as! PostTableViewCell
                }
            case "anon":
                if let imageURL = individualPost["imageURL"] as? URL {
                    cell = tableView.dequeueReusableCell(withIdentifier: "anonListImageCell", for: indexPath) as! PostTableViewCell
                    let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                        cell.postImageView.image = image
                        cell.setNeedsLayout()
                    }
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.postImageView.sd_setImage(with: imageURL, placeholderImage: nil, options: .progressiveDownload, completed: block)
                    let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                    cell.postImageView.addGestureRecognizer(tapToViewImage)
                } else {
                    cell = tableView.dequeueReusableCell(withIdentifier: "anonListCell", for: indexPath) as! PostTableViewCell
                }
            case "hot", "trending":
                if let imageURL = individualPost["imageURL"] as? URL {
                    if let _ = individualPost["userHandle"] as? String {
                        cell = tableView.dequeueReusableCell(withIdentifier: "pondListImageCell", for: indexPath) as! PostTableViewCell
                    } else {
                        cell = tableView.dequeueReusableCell(withIdentifier: "anonListImageCell", for: indexPath) as! PostTableViewCell
                    }
                    let block: SDExternalCompletionBlock = { (image, error, cacheType, url) -> Void in
                        cell.postImageView.image = image
                        cell.setNeedsLayout()
                    }
                    cell.postImageView.contentMode = .scaleAspectFill
                    cell.postImageView.sd_setImage(with: imageURL, placeholderImage: nil, options: .progressiveDownload, completed: block)
                    let tapToViewImage = UITapGestureRecognizer(target: self, action: #selector(self.presentImage))
                    cell.postImageView.addGestureRecognizer(tapToViewImage)
                } else {
                    if let _ = individualPost["userHandle"] as? String {
                        cell = tableView.dequeueReusableCell(withIdentifier: "pondListCell", for: indexPath) as! PostTableViewCell
                    } else {
                        cell = tableView.dequeueReusableCell(withIdentifier: "anonListCell", for: indexPath) as! PostTableViewCell
                    }
                }
            default:
                cell = tableView.dequeueReusableCell(withIdentifier: "pondListCell", for: indexPath) as! PostTableViewCell
            }
            
            let userID = individualPost["userID"] as! Int
            let didIVote = individualPost["didIVote"] as! String
            let postContent = individualPost["postContent"] as! String

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
            
            if let handle = individualPost["userHandle"] as? String {
                cell.userPicImageView.layer.cornerRadius = cell.userPicImageView.frame.size.width/2
                cell.userPicImageView.clipsToBounds = true
                let picURL = individualPost["picURL"] as! URL
                cell.userPicImageView.sd_setImage(with: picURL)
                cell.userNameLabel.text = individualPost["userName"] as? String
                cell.userHandleLabel.text = "@\(handle)"
                cell.postContentTextView.attributedText = misc.stringWithColoredTags(postContent, time: "default", fontSize: 18, timeSize: 12)

                if userID != self.myID && self.myID > 0 {
                    let tapPicToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                    let tapNameToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                    let tapHandleToViewUser = UITapGestureRecognizer(target: self, action: #selector(self.presentUserProfile))
                    cell.userPicImageView.addGestureRecognizer(tapPicToViewUser)
                    cell.userNameLabel.addGestureRecognizer(tapNameToViewUser)
                    cell.userHandleLabel.addGestureRecognizer(tapHandleToViewUser)
                }
            } else {
                cell.postContentTextView.attributedText = misc.anonStringWithColoredTags(postContent, time: "default", fontSize: 18, timeSize: 12)
            }
            
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
            
            cell.whiteView.backgroundColor = UIColor.white
            cell.whiteView.layer.masksToBounds = false
            cell.whiteView.layer.cornerRadius = 2.5
            cell.whiteView.layer.shadowOffset = CGSize(width: -1, height: 1)
            cell.whiteView.layer.shadowOpacity = 0.42
            cell.whiteView.sizeToFit()
            
            if !self.postIDArray.contains(postID) {
                cell.whiteView.alpha = 0
                UIView.animate(withDuration: 0.1, animations: {
                    cell.whiteView.alpha = 1
                })
                self.postIDArray.append(postID)
            }
            
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let height = cell.frame.size.height
        switch self.segment {
        case "pond":
            self.pondHeightAtIndexPath.updateValue(height, forKey: indexPath)
        case "anon":
            self.anonHeightAtIndexPath.updateValue(height, forKey: indexPath)
        case "hot":
            self.hotHeightAtIndexPath.updateValue(height, forKey: indexPath)
        case "trending":
            self.trendingHeightAtIndexPath.updateValue(height, forKey: indexPath)
        case "friend":
            self.friendHeightAtIndexPath.updateValue(height, forKey: indexPath)
        default:
            return
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !self.firstLoad {
            var heightAtIndexPath: [IndexPath:CGFloat]
            
            switch self.segment {
            case "pond":
                heightAtIndexPath = self.pondHeightAtIndexPath
            case "anon":
                heightAtIndexPath = self.anonHeightAtIndexPath
            case "hot":
                heightAtIndexPath = self.hotHeightAtIndexPath
            case "trending":
                heightAtIndexPath = self.trendingHeightAtIndexPath
            case "friend":
                heightAtIndexPath = self.friendHeightAtIndexPath
            default:
                return UITableViewAutomaticDimension
            }
            
            if let height = heightAtIndexPath[indexPath] {
                return height
            } else {
                return UITableViewAutomaticDimension
            }
        }
        
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trending":
            posts = self.trendingPosts
        case "friend":
            posts = self.friendPosts
        default:
            posts = []
        }
        
        if !posts.isEmpty {
            let individualPost = posts[indexPath.row]
            let postID = individualPost["postID"] as! Int
            if postID == -2 {
                return 140
            } else {
                return UITableViewAutomaticDimension
            }
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.parentRow = indexPath.row
        
        if self.segment == "trendingList" {
            if !self.trendingList.isEmpty && !self.isKeyboardUp {
                let cell = tableView.cellForRow(at: indexPath) as! TrendingTableViewCell
                self.textView.textColor = misc.nativColor
                cell.backgroundColor = misc.nativFade
                let individualTag = self.trendingList[indexPath.row]
                let trendingTag = individualTag["tag"] as! String
                self.displayActivity("searching for .\(trendingTag)", indicator: true, button: false)
                self.textView.text = ".\(trendingTag)"
                self.textView.font = UIFont.systemFont(ofSize: 18)
                self.setTextViewConstraints()
                self.segment = "trending"
                self.firstLoad = true
                self.observePond()
            }
        } else {
            var posts: [[String:Any]]
            switch self.segment {
            case "pond":
                posts = self.pondPosts
            case "anon":
                posts = self.anonPosts
            case "hot":
                posts = self.hotPosts
            case "trending":
                posts = self.trendingPosts
            case "friend":
                posts = self.friendPosts
            default:
                return
            }
            
            let individualPost = posts[indexPath.row]
            let postID = individualPost["postID"] as! Int
            if !posts.isEmpty && !self.isKeyboardUp && postID > 0 {
                let cell = tableView.cellForRow(at: indexPath) as! PostTableViewCell
                cell.replyPicImageView.isHighlighted = true
                cell.whiteView.backgroundColor = misc.nativFade
                if postID > 0 {
                    self.parentPostToPass = individualPost
                    self.performSegue(withIdentifier: "fromPondListToDrop", sender: self)
                }
            }
        }
        
        if  ((self.segment == "pond" && self.pondPosts.isEmpty) || (self.segment == "anon" && self.anonPosts.isEmpty)) && self.myID > 0 {
            if let cell = tableView.cellForRow(at: indexPath) as? NoContentTableViewCell {
                cell.noContentLabel.backgroundColor = misc.nativFade
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "fromPondListToPondMap" {
            if let pondMapViewController = segue.destination as? PondMapViewController {
                pondMapViewController.segment = self.segment
                if self.locationTextField.textColor != .lightGray && self.locationTextField.text != "" {
                    pondMapViewController.locationText = self.locationTextField.text!
                }
                pondMapViewController.longitude = self.longitude
                pondMapViewController.latitude = self.latitude
                pondMapViewController.radius = self.radius
                pondMapViewController.timeDel = self.timeDel
                pondMapViewController.pondPosts = self.pondPosts
                pondMapViewController.anonPosts = self.anonPosts
                pondMapViewController.hotPosts = self.hotPosts
                pondMapViewController.trendingList = self.trendingList
                pondMapViewController.friendPosts = self.friendPosts
            }
        }
        
        if segue.identifier == "fromPondListToDrop" {
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
        
        if segue.identifier == "fromPondListToUserProfile" {
            if let userProfileViewController = segue.destination as? UserProfileViewController {
                userProfileViewController.fromHandle = self.fromHandle
                userProfileViewController.segueSender = "pondList"
                userProfileViewController.userID = self.userIDToPass
                userProfileViewController.userIDFIR = self.userIDFIRToPass
                userProfileViewController.userHandle = "@\(self.userHandleToPass)"
                userProfileViewController.chatID = misc.setChatID(self.myID, userID: self.userIDToPass)
            }
        }
        
        if segue.identifier == "fromPondListToImagePost" {
            if let imagePostViewController = segue.destination as? ImagePostViewController {
                imagePostViewController.segment = self.segment
                imagePostViewController.image = self.imageToPass
                imagePostViewController.longitude = self.longitude
                imagePostViewController.latitude = self.latitude
                if self.textView.textColor != .lightGray {
                    imagePostViewController.text = self.textViewText
                }
            }
        }
        
        if segue.identifier == "fromPondListToImage" {
            if let imageViewController = segue.destination as? ImageViewController {
                imageViewController.imageURL = self.imageURLToPass
            }
        }
    }
    
    func presentImage(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.pondListTableView)
        let indexPath: IndexPath! = self.pondListTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        var individualPost: [String:Any]
        switch self.segment {
        case "pond":
            individualPost = self.pondPosts[indexPath.row]
        case "anon":
            individualPost = self.anonPosts[indexPath.row]
        case "hot":
            individualPost = self.hotPosts[indexPath.row]
        case "trending":
            individualPost = self.trendingPosts[indexPath.row]
        case "friend":
            individualPost = self.friendPosts[indexPath.row]
        default:
            return
        }
        
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
            self.performSegue(withIdentifier: "fromPondListToImage", sender: self)
        }
    }
    
    func presentUserProfile(sender: UITapGestureRecognizer) {
        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            self.displayAlert("Need to Sign In", alertMessage: "In order to view a profile, you need to login/sign up. Click the menu icon on the top left and go to the sign up section. There's only one step to sign up! :)")
            return
        } else {
            let position = sender.location(in: self.pondListTableView)
            let indexPath: IndexPath! = self.pondListTableView.indexPathForRow(at: position)
            self.parentRow = indexPath.row
            var individualPost: [String:Any]
            switch self.segment {
            case "pond":
                individualPost = self.pondPosts[indexPath.row]
            case "anon":
                individualPost = self.anonPosts[indexPath.row]
            case "hot":
                individualPost = self.hotPosts[indexPath.row]
            case "trending":
                individualPost = self.trendingPosts[indexPath.row]
            case "friend":
                individualPost = self.friendPosts[indexPath.row]
            default:
                return
            }
            
            self.fromHandle = false
            let userID = individualPost["userID"] as! Int
            self.userIDToPass = userID
            self.userIDFIRToPass = individualPost["userIDFIR"] as! String
            self.userHandleToPass = individualPost["userHandle"] as! String
            if self.myID != userID && userID > 0 {
                self.performSegue(withIdentifier: "fromPondListToUserProfile", sender: self)
            }
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
            SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view, forMenu: UIRectEdge.left)
        }
    }
    
    func presentSideMenu() {
        self.present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    func presentPondMap() {
        UIView.setAnimationsEnabled(false)
        self.performSegue(withIdentifier: "fromPondListToPondMap", sender: self)
        UIView.setAnimationsEnabled(true)
    }
    
    // MARK: - EditPondParent Protocol
    
    func editPondContent(_ postContent: String, timestamp: String) {
        switch self.segment {
        case "pond":
            self.pondPosts[self.parentRow]["postContent"] = postContent
            self.pondPosts[self.parentRow]["timestamp"] = "edited \(timestamp)"
        case "anon":
            self.anonPosts[self.parentRow]["postContent"] = postContent
            self.anonPosts[self.parentRow]["timestamp"] = "edited \(timestamp)"
        case "hot":
            self.hotPosts[self.parentRow]["postContent"] = postContent
            self.hotPosts[self.parentRow]["timestamp"] = "edited \(timestamp)"
        case "trending":
            self.trendingPosts[self.parentRow]["postContent"] = postContent
            self.trendingPosts[self.parentRow]["timestamp"] = "edited \(timestamp)"
        case "friend":
            self.friendPosts[self.parentRow]["postContent"] = postContent
            self.friendPosts[self.parentRow]["timestamp"] = "edited \(timestamp)"
        default:
            return
        }
        self.pondListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    func deletePondParent() {
        switch self.segment {
        case "pond":
            if self.pondPosts.count == 1 {
                self.pondPosts = []
            } else {
                self.pondPosts.remove(at: self.parentRow)
            }
        case "anon":
            if self.anonPosts.count == 1 {
                self.anonPosts = []
            } else {
                self.anonPosts.remove(at: self.parentRow)
            }
        case "hot":
            if self.hotPosts.count == 1 {
                self.hotPosts = []
            } else {
                self.hotPosts.remove(at: self.parentRow)
            }
        case "trending":
            if self.trendingPosts.count == 1 {
                self.trendingPosts = []
            } else {
                self.trendingPosts.remove(at: self.parentRow)
            }
        case "friend":
            if self.friendPosts.count == 1 {
                self.friendPosts = []
            } else {
                self.friendPosts.remove(at: self.parentRow)
            }
        default:
            return
        }
        self.pondListTableView.reloadData()
    }
    
    func updatePondReplyCount(_ replyCount: Int) {
        switch self.segment {
        case "pond":
            self.pondPosts[self.parentRow]["replyCount"] = replyCount
        case "anon":
            self.anonPosts[self.parentRow]["replyCount"] = replyCount
        case "hot":
            self.hotPosts[self.parentRow]["replyCount"] = replyCount
        case "trending":
            self.trendingPosts[self.parentRow]["replyCount"] = replyCount
        case "friend":
            self.friendPosts[self.parentRow]["replyCount"] = replyCount
        default:
            return
        }
        self.pondListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    func updatePondPointCount(_ pointsCount: Int) {
        switch self.segment {
        case "pond":
            self.pondPosts[self.parentRow]["pointsCount"] = pointsCount
            self.pondPosts[self.parentRow]["didIVote"] = "yes"
        case "anon":
            self.anonPosts[self.parentRow]["pointsCount"] = pointsCount
            self.anonPosts[self.parentRow]["didIVote"] = "yes"
        case "hot":
            self.hotPosts[self.parentRow]["pointsCount"] = pointsCount
            self.hotPosts[self.parentRow]["didIVote"] = "yes"
        case "trending":
            self.trendingPosts[self.parentRow]["pointsCount"] = pointsCount
            self.trendingPosts[self.parentRow]["didIVote"] = "yes"
        case "friend":
            self.friendPosts[self.parentRow]["pointsCount"] = pointsCount
            self.friendPosts[self.parentRow]["didIVote"] = "yes"
        default:
            return
        }
        self.pondListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
    }
    
    // MARK: - SendImagePostProtocol
    
    func insertImagePost(_ post: [String : Any]) {
        self.setTextViewPlaceholder()   
        switch self.segment {
        case "pond":
            self.pondPosts.insert(post, at: 0)
        case "anon":
            self.anonPosts.insert(post, at: 0)
        default:
            return
        }
        self.pondListTableView.reloadData()
    }
    
    // MARK: - Location
    
    func checkAuthorizationStatus() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
            self.locationTextField.text = "Berkeley, CA"
            self.locationText = "Berkeley, CA"
            
            
        case .restricted, .denied :
            let alertController = UIAlertController(title: "Location Access Disabled", message: "Please enable location so we can bring you nearby posts and groups. Thanks!", preferredStyle: .alert)
            
            let openSettingsAction = UIAlertAction(title: "Settings", style: .default) { action in
                if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
            alertController.addAction(openSettingsAction)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
            self.locationTextField.text = "Berkeley, CA"
            self.locationText = "Berkeley, CA"
            
        default:
            self.locationTextField.text = self.locationText
        }        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            self.locationTextField.text = "here"
            self.locationManager.startUpdatingLocation()
        } else {
            self.locationTextField.text = "Berkeley, CA"
            self.locationText = "Berkeley, CA"
            self.getLocation(self.locationTextField.text!)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.getLocation(self.locationTextField.text!)
    }
    
    func getLocation(_ locationText: String) {
        let geocoder = CLGeocoder()
        if locationText.lowercased().trimSpace() != "here" {
            geocoder.geocodeAddressString(locationText, completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    self.displayLocationError(error!)
                    return
                }
                if let placemark = placemarks?.first {
                    self.setLocation(placemark, locationText: locationText)
                    self.resetRadius(2.5, t: 0)
                }
            })
            
        } else {
            geocoder.reverseGeocodeLocation(self.locationManager.location!, completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    self.displayLocationError(error!)
                    return
                }
                if let placemark = placemarks?.first {
                    self.setLocation(placemark, locationText: "here")
                    self.resetRadius(0.5, t: 0)
                }
            })
            
        }
    }
    
    func setLocation(_ placemark: CLPlacemark, locationText: String) {
        let decimalSet = CharacterSet.decimalDigits
        let decimalRange = locationText.rangeOfCharacter(from: decimalSet)
        
        if locationText != "here" {
            if let city = placemark.locality {
                var placemarkLocation = placemark.location!.coordinate
                self.longitude = placemarkLocation.longitude.roundToDecimalPlace(8)
                self.latitude = placemarkLocation.latitude.roundToDecimalPlace(8)
                if let state = placemark.administrativeArea {
                    if decimalRange != nil {
                        self.locationTextField.text = locationText
                        self.locationText = locationText
                    } else {
                        let locationString: String = "\(city), \(state)"
                        self.locationTextField.text = locationString
                        self.locationText = locationString
                    }
                } else {
                    if decimalRange != nil {
                        self.locationTextField.text = locationText
                        self.locationText = locationText
                    } else {
                        self.locationTextField.text = city
                        self.locationText = city
                    }
                }
            } else {
                let status = CLLocationManager.authorizationStatus()
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    self.locationTextField.text = "here"
                    var location = self.locationManager.location!.coordinate
                    self.longitude = location.longitude.roundToDecimalPlace(8)
                    self.latitude = location.latitude.roundToDecimalPlace(8)
                } else {
                    self.locationTextField.text = "Berkeley, CA"
                    self.locationText = "Berkeley, CA"
                    self.longitude = -122.258542
                    self.latitude = 37.871906
                }
                self.displayAlert("Invalid Location", alertMessage: "Please enter a valid city, zip, or here (with location services enabled)")
                return
            }
        } else {
            self.locationTextField.text = "here"
            self.locationText = "here"
            var location = self.locationManager.location!.coordinate
            self.longitude = location.longitude.roundToDecimalPlace(8)
            self.latitude = location.latitude.roundToDecimalPlace(8)
        }
        
        self.observePond()
    }
    
    func displayLocationError(_ error: Error) {
        if let clerror = error as? CLError {
            let errorCode = clerror.errorCode
            switch errorCode {
            case 1:
                self.displayAlert("Oops", alertMessage: "Location services denied. Please enable them if you want to see different locations.")
            case 2:
                self.displayAlert("uhh, Houston, we have a problem", alertMessage: "Sorry, could not connect to le internet or you've made too many location requests in a short amount of time. Please wait and try again. :(")
            case 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17:
                self.displayAlert("Oops", alertMessage: clerror.localizedDescription)
            default:
                self.displayAlert("Oops", alertMessage: "Invalid Location. Please try another zip, city, or tap the right button for this location.")
            }
        } else {
            self.displayAlert("Oops", alertMessage: "Invalid Location. Please try another zip, city, or tap the right button for this location.")
        }
        return
    }
    
    func resetRadius(_ r: Double, t: Int) {
        self.radius = r
        self.timeDel = t
    }
    
    func getMinMaxLongLat(_ distanceMiles: Double) -> [Double] {
        let delta = (distanceMiles*5280)/(364173*cos(self.longitude))
        let scaleFactor = 0.01447315953478432289213674551561
        let minLong = self.longitude - delta
        let maxLong = self.longitude + delta
        let minLat = self.latitude - (distanceMiles*scaleFactor)
        let maxLat = self.latitude + (distanceMiles*scaleFactor)
        return [minLong, maxLong, minLat, maxLat]
    }
    
    // MARK: - TextField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.textColor == .black {
            self.locationText = textField.text!
        }
        textField.text = ""
        self.isEditingLocation = true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let status = CLLocationManager.authorizationStatus()
        if textField.text == "" {
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.locationText.lowercased().trimSpace() == "here" {
                textField.text = "here"
            } else {
                textField.text = self.locationText
            }
        }
        
        if textField.text != self.locationText {
            self.firstLoad = true
            self.clearArrays()
            
            if textField.text?.lowercased().trimSpace() == "here" && !(status == .authorizedWhenInUse || status == .authorizedAlways) {
                textField.text = "Berkeley, CA"
                self.locationText = "Berkeley, CA"
                self.displayAlert("Location Services Disabled", alertMessage: "We cannot find your location since location services have not been authorized. Please go to settings to authorize or type a different place.")
                return
            } else {
                self.logViewDifferentLocation()
                self.getLocation(self.locationTextField.text!)
            }
        }
    }
    
    // MARK: - TextView
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            if self.segment == "trendingList" || self.segment == "trending" {
                textView.textColor = misc.nativColor
            } else {
                textView.textColor = UIColor.black
            }
        }
        textView.font = UIFont.systemFont(ofSize: 18)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.textColor == UIColor.black && textView.text != "" {
            self.sendButton.isEnabled = true
            if self.segment == "trendingList" || self.segment == "trending" {
                self.segment = "trending"
            }
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
            self.setTextViewPlaceholder()
            self.characterCountLabel.isHidden = true
            self.sendButton.isEnabled = false
            if self.segment == "trendingList" || self.segment == "trending" {
                self.segment = "trendingList"
                self.pondListTableView.reloadData()
                self.firstLoad = true
                self.observePond()
            }
        } else {
            if self.segment == "trendingList" || self.segment == "trending" {
                self.segment = "trending"
                self.displayActivity("searching tag(s)", indicator: true, button: false)
                self.firstLoad = true
                self.observePond()
            }

        }
        
        if (self.pondPosts.isEmpty && self.segment == "pond") || (self.anonPosts.isEmpty && self.segment == "anon") {
            if let cell = self.pondListTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? NoContentTableViewCell {
                cell.backgroundColor = misc.softGrayColor
            }
        }
    }
    
    func setTextViewPlaceholder() {
        self.textView.textColor = .lightGray
        self.sendButton.isEnabled = false
        self.textView.font = UIFont.systemFont(ofSize: 14)

        if self.myID <= 0 || self.myIDFIR == "0000000000000000000000000000" {
            misc.setTextViewPlaceholder(self.textView, placeholder: "Sign in to post!")
            self.textView.isUserInteractionEnabled = false
        } else {
            switch self.segment {
            case "pond":
                self.textView.isUserInteractionEnabled = true
                misc.setTextViewPlaceholder(self.textView, placeholder: "post around you - tag with @userHandle and/or .somePlace")
            case "anon":
                self.textView.isUserInteractionEnabled = true
                misc.setTextViewPlaceholder(self.textView, placeholder: "anonymous post around you - tag with .somePlace")
            case "hot":
                self.textView.isUserInteractionEnabled = false
                misc.setTextViewPlaceholder(self.textView, placeholder: "switch to public or anonymous segments to post")
            case "trendingList", "trending":
                self.textView.isUserInteractionEnabled = true
                misc.setTextViewPlaceholder(self.textView, placeholder: "enter specific tag(s) or leave empty to view list")
            case "friend":
                self.textView.isUserInteractionEnabled = false
                misc.setTextViewPlaceholder(self.textView, placeholder: "switch to public or anonymous sections to post")
            default:
                self.segment = "pond"
                self.textView.isUserInteractionEnabled = true
                misc.setTextViewPlaceholder(self.textView, placeholder: "post around you - tag with @userHandle and/or .somePlace")
            }
        }
    }
    
    func setTextViewConstraints() {
        switch self.segment {
        case "pond", "anon":
            self.cameraLeadingConstraint.constant = -8
            self.textViewBottomConstraint.constant = 8
            self.sendTrailingConstraint.constant = 8
            self.cameraButton.isHidden = false
            self.sendButton.isHidden = false
            if !self.firstLoadConstraints {
                UIView.animate(withDuration: 0.15, animations: { self.view.layoutIfNeeded() })
            }
        case "hot", "friend":
            let textViewHeight = self.textView.frame.size.height
            self.cameraLeadingConstraint.constant = -47
            self.textViewBottomConstraint.constant = -textViewHeight - 16
            self.sendTrailingConstraint.constant = -31
            self.cameraButton.isHidden = true
            self.sendButton.isHidden = true
            if !self.firstLoadConstraints {
                UIView.animate(withDuration: 0.15, animations: { self.view.layoutIfNeeded() })
            }
        case "trendingList", "trending":
            self.cameraLeadingConstraint.constant = -47
            self.textViewBottomConstraint.constant = 8
            self.sendTrailingConstraint.constant = -31
            self.cameraButton.isHidden = true
            self.sendButton.isHidden = true
            if !self.firstLoadConstraints {
                UIView.animate(withDuration: 0.15, animations: { self.view.layoutIfNeeded() })
            }
        default:
            self.cameraLeadingConstraint.constant = -8
            self.textViewBottomConstraint.constant = 8
            self.sendTrailingConstraint.constant = 8
            self.cameraButton.isHidden = false
            self.sendButton.isHidden = false
            if !self.firstLoadConstraints {
                UIView.animate(withDuration: 0.15, animations: { self.view.layoutIfNeeded() })
            }
        }
        
        self.firstLoadConstraints = false 
    }
    
    func textViewTapped(sender: UITapGestureRecognizer) {
        let position = sender.location(in: self.pondListTableView)
        let indexPath: IndexPath! = self.pondListTableView.indexPathForRow(at: position)
        self.parentRow = indexPath.row
        var individualPost: [String:Any]
        switch self.segment {
        case "pond":
            individualPost = self.pondPosts[indexPath.row]
        case "anon":
            individualPost = self.anonPosts[indexPath.row]
        case "hot":
            individualPost = self.hotPosts[indexPath.row]
        case "trending":
            individualPost = self.trendingPosts[indexPath.row]
        case "friend":
            individualPost = self.friendPosts[indexPath.row]
        default:
            return
        }
        
        if let textView = sender.view as? UITextView {
            let layoutManager = textView.layoutManager
            var position: CGPoint = sender.location(in: textView)
            position.x -= textView.textContainerInset.left
            position.y -= textView.textContainerInset.top
            
            let charIndex = layoutManager.characterIndex(for: position, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
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
                                    self.performSegue(withIdentifier: "fromPondListToUserProfile", sender: self)
                                }
                            }
                        }
                    }
                    
                    if tappedWord.characters.first == "." {
                        self.textView.textColor = misc.nativColor
                        self.textView.text = tappedWord
                        self.textView.font = UIFont.systemFont(ofSize: 18)
                        self.segment = "trending"
                        self.segmentedControl.selectedSegmentIndex = 3
                        self.trendingPosts = []
                        self.displayActivity("searching for \(tappedWord)", indicator: true, button: false)
                        self.firstLoad = true
                        self.observePond()
                    }
                } else {
                    if !self.isKeyboardUp {
                        let cell = self.pondListTableView.cellForRow(at: indexPath) as! PostTableViewCell
                        cell.replyPicImageView.isHighlighted = true
                        cell.whiteView.backgroundColor = misc.nativFade
                        let postID = individualPost["postID"] as! Int
                        if postID > 0 {
                            self.parentPostToPass = individualPost
                            self.performSegue(withIdentifier: "fromPondListToDrop", sender: self)
                        }
                    }
                }
                
            }
        }
    }
    
    // MARK: - ImagePicker
    
    func imagePickerController(_ picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: Any]) {
        
        if let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.imageToPass = selectedImage
            if self.textView.textColor != .lightGray {
                self.textViewText = self.textView.text!
            }
        } else {
            print("Oops")
        }
        
        self.performSegue(withIdentifier: "fromPondListToImagePost", sender: self)
        self.dismiss(animated: false, completion: {
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
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
    
    // MARK: - Sort Options
    
    func mapListDidChange(_ sender: UISegmentedControl) {
        self.presentPondMap()
    }
    
    func sortCriteriaDidChange(_ sender: UISegmentedControl) {
        self.dismissKeyboard()
        self.resetRadius(0.5, t: 0)
        self.firstLoad = true
        let text = self.locationTextField.text
        if text == "" {
            let status = CLLocationManager.authorizationStatus()
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationTextField.text = "here"
                self.locationText = "here"
            } else {
                self.locationTextField.text = "Berkeley, CA"
                self.locationText = "Berkeley, CA"
            }
        }
        
        self.scrollToTop()
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
        
        switch sender.selectedSegmentIndex {
        case 0:
            self.segment = "pond"
            self.logViewPondNew()
            self.textView.isUserInteractionEnabled = true
            self.textView.autocapitalizationType = .sentences
        case 1:
            self.segment = "anon"
            self.logViewPondAnon()
            self.textView.isUserInteractionEnabled = true
            self.textView.autocapitalizationType = .sentences
        case 2:
            self.segment = "hot"
            self.logViewPondHot()
            self.textView.isUserInteractionEnabled = false
            self.textView.autocapitalizationType = .sentences
        case 3:
            self.segment = "trendingList"
            self.trendingPosts = []
            self.logViewPondTrending()
            self.textView.isUserInteractionEnabled = true
            self.textView.autocapitalizationType = .none
        case 4:
            self.segment = "friend"
            self.logViewPondFriend()
            self.textView.isUserInteractionEnabled = false
            self.textView.autocapitalizationType = .sentences
        default:
            return
        }
        
        self.observePond()
        self.setTextViewPlaceholder()
        self.setTextViewConstraints()
        self.pondListTableView.reloadData()
    }
    
    func swipeLeft() {
        let currentIndex = self.segmentedControl.selectedSegmentIndex
        if currentIndex >= 0 && currentIndex < 4 {
            self.resetRadius(0.5, t: 0)
            self.firstLoad = true
            let text = self.locationTextField.text
            if text == "" {
                let status = CLLocationManager.authorizationStatus()
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationTextField.text = "here"
                    self.locationText = "here"
                } else {
                    self.locationTextField.text = "Berkeley, CA"
                    self.locationText = "Berkeley, CA"
                }
            }
            
            self.scrollToTop()
            _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
            
            switch currentIndex {
            case 0:
                self.segmentedControl.selectedSegmentIndex = 1
                self.segment = "anon"
                self.logViewPondAnon()
                self.textView.isUserInteractionEnabled = true
                self.textView.autocapitalizationType = .sentences
            case 1:
                self.segmentedControl.selectedSegmentIndex = 2
                self.segment = "hot"
                self.logViewPondHot()
                self.textView.isUserInteractionEnabled = false
                self.textView.autocapitalizationType = .sentences
            case 2:
                self.segmentedControl.selectedSegmentIndex = 3
                self.trendingPosts = []
                self.segment = "trendingList"
                self.logViewPondTrending()
                self.textView.isUserInteractionEnabled = true
                self.textView.autocapitalizationType = .none
            case 3:
                self.segmentedControl.selectedSegmentIndex = 4
                self.segment = "friend"
                self.logViewPondFriend()
                self.textView.isUserInteractionEnabled = false
                self.textView.autocapitalizationType = .sentences
            default:
                return
            }
            
            self.observePond()
            self.setTextViewPlaceholder()
            self.setTextViewConstraints()
            self.pondListTableView.reloadData()
        }
        
    }
    
    func swipeRight() {
        let currentIndex = self.segmentedControl.selectedSegmentIndex
        if currentIndex <= 4 && currentIndex > 0 {
            self.dismissKeyboard()
            self.resetRadius(0.5, t: 0)
            self.firstLoad = true
            let text = self.locationTextField.text
            if text == "" {
                let status = CLLocationManager.authorizationStatus()
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationTextField.text = "here"
                    self.locationText = "here"
                } else {
                    self.locationTextField.text = "Berkeley, CA"
                    self.locationText = "Berkeley, CA"
                }
            }
            
            self.scrollToTop()
            _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scrollToTop), userInfo: nil, repeats: false)
            
            switch currentIndex {
            case 4:
                self.segmentedControl.selectedSegmentIndex = 3
                self.trendingPosts = []
                self.segment = "trendingList"
                self.logViewPondTrending()
                self.textView.isUserInteractionEnabled = false
                self.textView.autocapitalizationType = .none
            case 3:
                self.segmentedControl.selectedSegmentIndex = 2
                self.segment = "hot"
                self.logViewPondHot()
                self.textView.isUserInteractionEnabled = false
                self.textView.autocapitalizationType = .sentences
            case 2:
                self.segmentedControl.selectedSegmentIndex = 1
                self.segment = "anon"
                self.logViewPondAnon()
                self.textView.isUserInteractionEnabled = true
                self.textView.autocapitalizationType = .sentences
            case 1:
                self.segmentedControl.selectedSegmentIndex = 0
                self.segment = "pond"
                self.logViewPondNew()
                self.textView.isUserInteractionEnabled = true
                self.textView.autocapitalizationType = .sentences
            default:
                return
            }
            
            self.observePond()
            self.setTextViewPlaceholder()
            self.setTextViewConstraints()
            self.pondListTableView.reloadData()
        }
    }
    
    // MARK: - ScrollView
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isRemoved {
            self.removeObserverForPond()
            self.isRemoved = true
        }
        
        let offset = scrollView.contentOffset.y
        let frameHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trending":
            posts = self.trendingPosts
        case "friend":
            posts = self.friendPosts
        default:
            return
        }
        
        if offset <= 420 {
            self.scrollToTopButton.removeFromSuperview()
        }
        
        if offset <= 0 {
            self.scrollPosition = "top"
            self.resetRadius(0.5, t: 0)
            self.observePond()
        } else if offset == (contentHeight - frameHeight) {
            self.scrollPosition = "bottom"
            if posts.count >= 43 {
                self.getPondList()
            }
        } else {
            self.scrollPosition = "middle"
        }
        
        // prefetch images on scroll down
        if !posts.isEmpty {
            if self.lastContentOffset < scrollView.contentOffset.y {
                let visibleCells = self.pondListTableView.visibleCells
                if let lastCell = visibleCells.last {
                    let lastIndexPath = self.pondListTableView.indexPath(for: lastCell)
                    let lastRow = lastIndexPath!.row
                    var nextLastRow = lastRow + 5
                    
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
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.locationTextField.resignFirstResponder()
        self.textView.resignFirstResponder()
        self.view.endEditing(true)
        if self.parentRow == 0 && self.pondPosts.isEmpty {
            let indexPath = IndexPath(row: 0, section: 0)
            if let cell = self.pondListTableView.cellForRow(at: indexPath) as? NoContentTableViewCell {
                cell.noContentLabel.backgroundColor = .white
            }
        }
    }
    
    func keyboardWillShow(_ notification: Notification) {
        self.isKeyboardUp = true
        self.dimBackground(true)
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if !self.isEditingLocation && self.textViewBottomConstraint.constant == 8 && (self.segment == "pond" || self.segment == "anon" || self.segment == "trendingList" || self.segment == "trending") {
                self.textViewBottomConstraint.constant += keyboardSize.height
                UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
            }
        }
    }
    
    func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if !self.isEditingLocation {
                self.textViewBottomConstraint.constant = 8 + keyboardSize.height
                UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
            }
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
        self.isEditingLocation = false
        if self.textViewBottomConstraint.constant != 8 && (self.segment == "pond" || self.segment == "anon" || self.segment == "trendingList" || self.segment == "trending") {
            self.textViewBottomConstraint.constant = 8
            UIView.animate(withDuration: 1.0, animations: { self.view.layoutIfNeeded() })
        }
    }
    
    func keyboardDidHide(_ notification: Notification) {
        self.isKeyboardUp = false
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollToTop), name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForPond), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "scrollToTop"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
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
            self.firstLoad = false
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    func displayActivity(_ message: String, indicator: Bool, button: Bool) {
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
        
        if button {
            self.addScrollToTop()
        }
    }
    
    func addScrollToTop() {
        self.scrollToTopButton.removeFromSuperview()
        self.scrollToTopButton = UIButton(frame: CGRect(x: self.view.frame.midX - 27.5, y: self.pondListTableView.frame.origin.y, width: 55, height: 30))
        self.scrollToTopButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.025).cgColor
        self.scrollToTopButton.addTarget(self, action: #selector(self.scrollToTop), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonUp), for: .touchUpInside)
        self.scrollToTopButton.addTarget(self, action: #selector(self.colorTopButtonDown), for: .touchDown)
        misc.makeTopButtonFancy(self.scrollToTopButton, title: "top")
        self.view.addSubview(self.scrollToTopButton)
    }
    
    func scrollToTop() {
        self.lastContentOffset = 0
        self.pondListTableView.setContentOffset(.zero, animated: false)
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
    
    func clearArrays() {
        self.urlArray = []
        self.pondHeightAtIndexPath = [:]
        self.anonHeightAtIndexPath = [:]
        self.hotHeightAtIndexPath = [:]
        self.trendingHeightAtIndexPath = [:]
        self.friendHeightAtIndexPath = [:]
        self.pondPosts = []
        self.anonPosts = []
        self.hotPosts = []
        self.trendingList = []
        self.trendingPosts = []
        self.friendPosts = []
        self.postIDArray = []
    }
    
    func handleRefreshControl(refreshControl: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            refreshControl.endRefreshing()
        })
    }
    
    // MARK: - Analytics
    
    func logViewPondList() {
        FIRAnalytics.logEvent(withName: "viewPondList", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondNew() {
        FIRAnalytics.logEvent(withName: "viewPondListNew", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondAnon() {
        FIRAnalytics.logEvent(withName: "viewPondListAnon", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondHot() {
        FIRAnalytics.logEvent(withName: "viewPondListHot", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondTrending() {
        FIRAnalytics.logEvent(withName: "viewPondListTrending", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondFriend() {
        FIRAnalytics.logEvent(withName: "viewPondListFriend", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewDifferentLocation() {
        FIRAnalytics.logEvent(withName: "viewDifferentLocation", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "location": self.locationTextField.text! as NSObject
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
    
    func logPondPostSent(_ postID: Int, longitude: Double, latitude: Double) {
        FIRAnalytics.logEvent(withName: "pondPostSent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "longitude": longitude as NSObject,
            "latitude": latitude as NSObject
            ])
    }
    
    func logAnonPostSent(_ postID: Int, longitude: Double, latitude: Double) {
        FIRAnalytics.logEvent(withName: "anonPostSent", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject,
            "postID": postID as NSObject,
            "longitude": longitude as NSObject,
            "latitude": latitude as NSObject
            ])
    }
    
    // MARK: - Firebase
    
    func observePond() {
        self.removeObserverForPond()
        if self.scrollPosition  == "top" || self.firstLoad || self.needToUpdateRadius {
            self.isRemoved = false
            
            let range = self.getMinMaxLongLat(self.radius)
            let minLong = range[0]
            let maxLong = range[1]
            let minLat = range[2]
            let maxLat = range[3]
            
            let pondRef = self.ref.child("posts")
            let anonRef = self.ref.child("anonPosts")
            let tagRef = self.ref.child("locationTags")
            let myFriendRef = self.ref.child("users").child(self.myIDFIR).child("lastFriendPost")
            
            switch self.segment {
            case "pond":
                pondRef.queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                    (snapshot) -> Void in
                    
                    pondRef.queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: {
                        (snapshot) -> Void in
                        self.getNewPosts()
                    })
                })
                
            case "anon":
                anonRef.queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                    (snapshot) -> Void in
                    
                    anonRef.queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: {
                        (snapshot) -> Void in
                        self.getNewPosts()
                    })
                })
                
            case "hot":
                var minPoints: Int
                if self.hotPosts.count >= 5 {
                    minPoints = hotPosts[5]["pointsCount"] as! Int
                } else {
                    if !self.hotPosts.isEmpty {
                        minPoints = hotPosts.last?["pointsCount"] as! Int
                    } else {
                        minPoints = 0
                    }
                }
                
                pondRef.queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                    (snapshot) -> Void in
                    
                    pondRef.queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: {
                        (snapshot) -> Void in
                        
                        pondRef.queryOrdered(byChild: "points").queryStarting(atValue: minPoints).observe(.value, with: {
                            (snapshot) -> Void in
                            self.getNewPosts()
                        })
                    })
                })
                
                anonRef.queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                    (snapshot) -> Void in
                    
                    anonRef.queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: {
                        (snapshot) -> Void in
                        
                        anonRef.queryOrdered(byChild: "points").queryStarting(atValue: minPoints).observe(.value, with: {
                            (snapshot) -> Void in
                            self.getNewPosts()
                        })
                    })
                })
                
            case "trendingList":
                if !self.trendingList.isEmpty {
                    var tagArray: [String] = []
                    if self.trendingList.count >= 5 {
                        let tag0 = self.trendingList[0]["tag"] as! String
                        let tag1 = self.trendingList[1]["tag"] as! String
                        let tag2 = self.trendingList[2]["tag"] as! String
                        let tag3 = self.trendingList[3]["tag"] as! String
                        let tag4 = self.trendingList[4]["tag"] as! String
                        tagArray.append(tag0)
                        tagArray.append(tag1)
                        tagArray.append(tag2)
                        tagArray.append(tag3)
                        tagArray.append(tag4)
                    } else {
                        for individualTrend in self.trendingList {
                            let tag = individualTrend["tag"] as! String
                            tagArray.append(tag)
                        }
                    }
                    self.tagsToRemove = tagArray
                    
                    for tag in tagArray {
                        tagRef.child(tag).queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                            (snapshot) -> Void in
                            
                            tagRef.child(tag).queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: { (snapshot) -> Void in
                                self.getNewPosts()
                            })
                        })
                    }
                    
                } else {
                    self.getPondList()
                }
                
            case "trending":
                if let text = self.textView.text {
                    let stringNoDotArray = misc.stringWithoutDot(text)
                    self.tagsToRemove = stringNoDotArray
                    
                    for tag in stringNoDotArray {
                        if tag != "" && !misc.checkSpecialCharacters(tag) {
                            tagRef.child(tag).queryOrdered(byChild: "longitude").queryStarting(atValue: minLong).queryEnding(atValue: maxLong).observe(.value, with: {
                                (snapshot) -> Void in
                                
                                tagRef.child(tag).queryOrdered(byChild: "latitude").queryStarting(atValue: minLat).queryEnding(atValue: maxLat).observe(.value, with: { (snapshot) -> Void in
                                    self.getNewPosts()
                                })
                            })
                        } else {
                            self.radius = 2.5
                            self.trendingPosts = []
                            self.getNewPosts()
                        }
                    }
                }
                
            case "friend":
                if self.myID <= 0 {
                    self.firstLoad = false
                    self.pondListTableView.reloadData()
                } else {
                    myFriendRef.observe(.value, with: {
                        (snapshot) -> Void in
                        self.getNewPosts()
                    })
                }
                
            default:
                self.displayAlert("Segment Error", alertMessage: "We messed up. Try another segment. Please report this bug if it persists.")
                return
            }
        }
    }
    
    func removeObserverForPond() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        let pondRef = self.ref.child("posts")
        pondRef.removeAllObservers()
        
        let anonymousRepliesRef = self.ref.child("anonPosts")
        anonymousRepliesRef.removeAllObservers()
        
        let tagRef = self.ref.child("locationTags")
        tagRef.removeAllObservers()
        for tag in self.tagsToRemove {
            tagRef.child(tag).removeAllObservers()
        }
        self.tagsToRemove = []
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
        let pondRef = self.ref.child("posts").child("\(postID)").child("points")
        let anonRef = self.ref.child("anonPosts").child("\(postID)").child("points")
        
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
    
    func writePostSent (_ postID: Int, postType: String, longitude: Double, latitude: Double, postContent: String, tags: [String]) {
        if postType == "pond" {
            let friendRef = self.ref.child("friendList").child("friends")
            var userIDFIRArray: [String] = []
            friendRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                if let friendArray = snapshot.value as? [[String:Any]] {
                    for friend in friendArray {
                        if let key = friend.keys.first {
                            userIDFIRArray.append(key)
                        }
                    }
                }
            })
            for userIDFIR in userIDFIRArray {
                let friendRef = self.ref.child("users").child(userIDFIR).child("lastFriendPost")
                friendRef.setValue(postID)
            }
            
            let pondRef = self.ref.child("posts").child("\(postID)")
            pondRef.child("longitude").setValue(longitude)
            pondRef.child("latitude").setValue(latitude)
            pondRef.child("points").setValue(0)
            pondRef.child("tags").setValue(tags)
            pondRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let myPondRef = self.ref.child("users").child(self.myIDFIR).child("posts").child("\(postID)")
            myPondRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let locationRef = self.ref.child("locationTags")
            for tag in tags {
                let tagRef = locationRef.child(tag).child("\(postID)_pond")
                tagRef.child("longitude").setValue(longitude)
                tagRef.child("latitude").setValue(latitude)
                tagRef.child("postInfo").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine")])
            }
            
        } else {
            let anonRef = self.ref.child("anonPosts").child("\(postID)")
            anonRef.child("longitude").setValue(longitude)
            anonRef.child("latitude").setValue(latitude)
            anonRef.child("points").setValue(0)
            anonRef.child("tags").setValue(tags)
            anonRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let myAnonRef = self.ref.child("users").child(self.myIDFIR).child("anonPosts").child("\(postID)")
            myAnonRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let locationRef = self.ref.child("locationTags")
            for tag in tags {
                let tagRef = locationRef.child(tag).child("\(postID)_anon")
                tagRef.child("longitude").setValue(longitude)
                tagRef.child("latitude").setValue(latitude)
                tagRef.child("postInfo").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine")])
            }
        }
    }
    
    // MARK: - Ads
    
    func loadAds() {
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trending":
            posts = self.trendingPosts
        case "friend":
            posts = self.friendPosts
        default:
            posts = []
        }
        
        let count = posts.count
        let adCount = count/40
        for _ in 0..<adCount {
            let adSize = GADAdSizeFromCGSize(CGSize(width: self.view.frame.size.width - 16, height: 132))
            let ad = GADNativeExpressAdView(adSize: adSize)
            ad?.adUnitID = "ca-app-pub-3615009076081464/9104211830"
            ad?.rootViewController = self
            let request = GADRequest()
            request.testDevices = ["e3d4c57ec74eb09b126b470353436b8e"]
            let birthArray = misc.getMyBirthComponents()
            if !birthArray.contains(-2) {
                var components = DateComponents()
                components.month = birthArray[0]
                components.day = birthArray[1]
                components.year = birthArray[2]
                request.birthday = Calendar.current.date(from: components)
            }
            if let gender = UserDefaults.standard.string(forKey: "gender.nativ") {
                if gender == "male" {
                    request.gender = .male
                }
                if gender == "female" {
                    request.gender = .female
                }
            }
            ad?.layer.masksToBounds = false
            ad?.layer.cornerRadius = 2.5
            ad?.layer.shadowOffset = CGSize(width: -1, height: 1)
            ad?.layer.shadowOpacity = 0.42
            ad?.load(request)
            self.nativeExpressAdArray.append(ad!)
        }
    }
    
    func getAdIndex(_ row: Int) -> Int {
        if row <= 40 {
            return 0
        } else if row <= 80 {
            return 1
        } else if row <= 120 {
            return 2
        } else if row <= 160 {
            return 3
        } else if row <= 200 {
            return 4
        } else {
            return 0
        }
    }
    
    // MARK: - AWS
    
    func getNewPosts() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        if !self.firstLoad {
            self.newPostsCount += 1
        }
        
        if self.newPostsCount == 3 || self.firstLoad {
            self.perform(#selector(self.getPondList), with: nil, afterDelay: 0.1)
        } else if self.needToUpdateRadius {
            self.needToUpdateRadius = false
        } else {
            self.perform(#selector(self.getPondList), with: nil, afterDelay: 0.5)
        }
    }
    
    func setPost(_ postID: Int, postContent: String) -> [String:Any] {
        var picURL: URL
        if let url = UserDefaults.standard.url(forKey: "myPicURL.nativ") {
            picURL = url
        } else {
            picURL = URL(string: "https://hostpostuserprof.s3.amazonaws.com/default_small")!
        }
        let myName: String
        let myHandle: String
        
        if let name = UserDefaults.standard.string(forKey: "myName.nativ") {
            myName = name
        } else {
            myName = "Me"
        }
        
        if let handle = UserDefaults.standard.string(forKey: "myHandle.nativ") {
            myHandle = handle
        } else {
            myHandle = "Me"
        }
        
        switch self.segment {
        case "pond":
            let post: [String:Any] = ["postID": postID, "userID": self.myID, "userIDFIR": self.myIDFIR, "userName": myName, "userHandle": myHandle, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "replyCount": 0, "pointsCount": 0, "didIVote": "no", "picURL": picURL, "shareCount": 0, "longitude": self.longitude, "latitude": self.latitude]
            return post
            
        case "anon":
            let post: [String:Any] = ["postID": postID, "userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "replyCount": 0, "pointsCount": 0, "didIVote": "no", "shareCount": 0, "longitude": self.longitude, "latitude": self.latitude]
            return post
            
        default:
            return [:]
        }
    }
    
    func presentSharePostSheet(sender: UITapGestureRecognizer) {
        self.removeObserverForPond()
        
        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
            let position = sender.location(in: self.pondListTableView)
            let indexPath: IndexPath! = self.pondListTableView.indexPathForRow(at: position)
            self.parentRow = indexPath.row
            
            let cell = self.pondListTableView.cellForRow(at: indexPath) as! PostTableViewCell
            cell.sharePicImageView.isHighlighted = true
            
            var individualPost: [String:Any]
            switch self.segment {
            case "pond":
                individualPost = self.pondPosts[indexPath.row]
            case "anon":
                individualPost = self.anonPosts[indexPath.row]
            case "hot":
                individualPost = self.hotPosts[indexPath.row]
            case "trending":
                individualPost = self.trendingPosts[indexPath.row]
            case "friend":
                individualPost = self.friendPosts[indexPath.row]
            default:
                return
            }
            let postID = individualPost["postID"] as! Int
            let postContent = individualPost["postContent"] as! String
            var postType: String
            if let _ = individualPost["userHandle"] as? String {
                postType = "pond"
            } else {
                postType = "anon"
            }
            
            let shareCount = individualPost["shareCount"] as! Int
            let newShareCount = shareCount + 1
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let shareFBAction = UIAlertAction(title: "Share on Facebook", style: .default, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                
                if let imageURL = individualPost["imageURL"] as? URL {
                    self.sharePost(postID, postType: postType, postContent: postContent, socialMedia: "Facebook", imageURL: imageURL, orView: nil, newShareCount: newShareCount)
                } else {
                    self.sharePost(postID, postType: postType, postContent: postContent, socialMedia: "Facebook", imageURL: nil, orView: cell.whiteView, newShareCount: newShareCount)
                }
            })
            alertController.addAction(shareFBAction)
            
            let shareTwitterAction = UIAlertAction(title: "Share on Twitter", style: .default, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                
                if let imageURL = individualPost["imageURL"] as? URL {
                    self.sharePost(postID, postType: postType, postContent: postContent, socialMedia: "Twitter", imageURL: imageURL, orView: nil, newShareCount: newShareCount)
                } else {
                    self.sharePost(postID, postType: postType, postContent: postContent, socialMedia: "Twitter", imageURL: nil, orView: cell.whiteView, newShareCount: newShareCount)
                }
            })
            alertController.addAction(shareTwitterAction)
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                cell.sharePicImageView.isHighlighted = false
                self.observePond()
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

    func sharePost(_ postID: Int, postType: String, postContent: String, socialMedia: String, imageURL: URL?, orView: UIView?, newShareCount: Int) {
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
                                self.observePond()
                                if postType == "pond" {
                                    self.logPondPostShared(postID, socialMedia: socialMedia)
                                } else {
                                    self.logAnonPostShared(postID, socialMedia: socialMedia)
                                }
                                self.writePostShared(postID, postType: postType)
                                switch self.segment {
                                case "pond":
                                    self.pondPosts[self.parentRow]["shareCount"] = newShareCount
                                case "anon":
                                    self.anonPosts[self.parentRow]["shareCount"] = newShareCount
                                case "hot":
                                    self.hotPosts[self.parentRow]["shareCount"] = newShareCount
                                case "trending":
                                    self.trendingPosts[self.parentRow]["shareCount"] = newShareCount
                                case "friend":
                                    self.friendPosts[self.parentRow]["shareCount"] = newShareCount
                                default:
                                    return
                                }
                                self.pondListTableView.reloadRows(at: [IndexPath(row: self.parentRow, section: 0)], with: .none)
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
    
    func upvotePost(sender: UITapGestureRecognizer) {
        if self.myID > 0 && self.myIDFIR != "0000000000000000000000000000" {
            let position = sender.location(in: self.pondListTableView)
            let indexPath: IndexPath! = self.pondListTableView.indexPathForRow(at: position)
            self.parentRow = indexPath.row
            
            var individualPost: [String:Any]
            switch self.segment {
            case "pond":
                individualPost = self.pondPosts[indexPath.row]
            case "anon":
                individualPost = self.anonPosts[indexPath.row]
            case "hot":
                individualPost = self.hotPosts[indexPath.row]
            case "trending":
                individualPost = self.trendingPosts[indexPath.row]
            case "friend":
                individualPost = self.friendPosts[indexPath.row]
            default:
                return
            }
            
            let didIVote = individualPost["didIVote"] as! String
            let postID = individualPost["postID"] as! Int
            
            if didIVote == "no" && postID > 0 {
                let currentPoints = individualPost["pointsCount"] as! Int
                let newPoints = currentPoints + 1
                switch self.segment {
                case "pond":
                    self.pondPosts[indexPath.row]["pointsCount"] = newPoints
                    self.pondPosts[indexPath.row]["didIVote"] = "yes"
                case "anon":
                    self.anonPosts[indexPath.row]["pointsCount"] = newPoints
                    self.anonPosts[indexPath.row]["didIVote"] = "yes"
                case "hot":
                    self.hotPosts[indexPath.row]["pointsCount"] = newPoints
                    self.hotPosts[indexPath.row]["didIVote"] = "yes"
                case "trending":
                    self.trendingPosts[indexPath.row]["pointsCount"] = newPoints
                    self.trendingPosts[indexPath.row]["didIVote"] = "yes"
                case "friend":
                    self.friendPosts[indexPath.row]["pointsCount"] = newPoints
                    self.friendPosts[indexPath.row]["didIVote"] = "yes"
                default:
                    return
                }
                self.pondListTableView.reloadRows(at: [indexPath], with: .none)
                
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
    
    func sendPost() {
        let postID: Int = 0
        let postContent: String = self.textView.text
        let handles = misc.handlesWithoutAt(postContent)
        let tags = misc.tagsWithoutDot(postContent)
        let isPicSet: String = "no"
        
        if self.segment == "anon" && !handles.isEmpty {
            self.displayAlert("No user tags in anon posts", alertMessage: "You cannot tag a user in an anonymous post. Please remove the text mentioning the user before posting.")
            return
        }
        
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
                                self.displayAlert("Oops", alertMessage: "Sorry, we messed up. Your post has not been sent. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                if let newPostID = parseJSON["postID"] as? Int {
                                    let post = self.setPost(newPostID, postContent: postContent)
                                    
                                    if self.segment == "pond" {
                                        self.logPondPostSent(newPostID, longitude: self.longitude, latitude: self.latitude)
                                        self.pondPosts.insert(post, at: 0)
                                    } else {
                                        self.logAnonPostSent(newPostID, longitude: self.longitude, latitude: self.latitude)
                                        self.anonPosts.insert(post, at: 0)
                                    }
                                    
                                    self.writePostSent(newPostID, postType: self.segment, longitude: self.longitude, latitude: self.latitude, postContent: postContent, tags: tags)
                                    self.textView.text = ""
                                    self.dismissKeyboard()
                                }
                                
                                self.pondListTableView.reloadData()
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
    
    func getPondList() {
        self.newPostsCount = 0
        let postID: Int = 0
        let picSize: String = "small"
        let isExact: String = "no"
        let hours: Int = 168

        var lastPostID: Int
        var pageNumber: Int
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trending":
            posts = self.trendingPosts
        case "friend":
            posts = self.friendPosts
        default:
            posts = [["postID": 0]]
        }
        if self.scrollPosition == "bottom" && posts.count >= 43 {
            let lastPost = posts.last!
            lastPostID = lastPost["postID"] as! Int
            pageNumber = misc.getNextPageNumber(posts)
            self.displayActivity("loading more posts...", indicator: true, button: true)
        } else {
            lastPostID = 0
            pageNumber = 0
        }
        
        var sort: String
        if self.segment == "hot" {
            sort = "hot"
        } else {
            sort = "new"
        }
        
        var isMine: String
        if self.segment == "friend" {
            isMine = "friend"
        } else {
            isMine = "no"
        }
        
        let token = misc.generateToken(16, firebaseID: self.myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            var getURL: URL!
            var getString: String
            switch self.segment {
            case "pond":
                getURL = URL(string: "https://dotnative.io/getPondPost")
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&isMine=\(isMine)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=\(isExact)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&radius=\(self.radius)&timeDel=\(self.timeDel)"
            case "anon":
                getURL = URL(string: "https://dotnative.io/getAnonPondPost")
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&isMine=\(isMine)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=\(isExact)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&radius=\(self.radius)&timeDel=\(self.timeDel)"
            case "hot":
                getURL = URL(string: "https://dotnative.io/getMixedPost")
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=\(isExact)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&isMine=\(isMine)&radius=\(self.radius)&timeDel=\(self.timeDel)"
            case "trendingList":
                var radius = self.radius
                if radius < 1.5 {
                    radius = 1.5
                }
                getURL = URL(string: "https://dotnative.io/getTrendingTags")
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&longitude=\(self.longitude)&latitude=\(self.latitude)&radius=\(radius)&timeDel=\(self.timeDel)&hours=\(hours)"
            case "trending":
                getURL = URL(string: "https://dotnative.io/getMixedPost")
                let text = self.textView.text!
                let tagArray = misc.stringWithoutDot(text)
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&isMine=\(isMine)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=yes&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&radius=2.5&timeDel=\(self.timeDel)"
                if !tagArray.isEmpty {
                    getString.append("&locationTag=\(tagArray)")
                }
            case "friend":
                getURL = URL(string: "https://dotnative.io/getPondPost")
                getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&isMine=\(isMine)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=\(isExact)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&radius=\(self.radius)&timeDel=\(self.timeDel)"
            default:
                return
            }

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
                                self.pondListTableView.reloadData()
                                self.displayAlert("Oops", alertMessage: "We encountered and error. Please report the bug by going to the report section in the menu if this persists.")
                                return
                            }
                            
                            if status == "success" {
                                var dictKey: String
                                switch self.segment {
                                case "pond":
                                    dictKey = "pondPosts"
                                case "anon":
                                    dictKey = "anonPondPosts"
                                case "hot":
                                    dictKey = "posts"
                                case "trendingList":
                                    dictKey = "locationTags"
                                case "trending":
                                    dictKey = "posts"
                                case "friend":
                                    dictKey = "pondPosts"
                                default:
                                    return
                                }
                                
                                if let radius = parseJSON["radius"] as? Double {
                                    if self.radius != radius {
                                        self.needToUpdateRadius = true
                                        self.firstLoad = false
                                        self.observePond()
                                    } else {
                                        self.needToUpdateRadius = false
                                    }
                                    self.radius = radius
                                }
                                
                                if let timeDel = parseJSON["timeDel"] as? Int {
                                    self.timeDel = timeDel
                                }
                                
                                if let postsArray = parseJSON[dictKey] as? [[String:Any]] {
                                    var posts: [[String:Any]] = []
                                    for individualPost in postsArray {
                                        if self.segment == "trendingList" {
                                            let tag = individualPost["locationTag"] as! String
                                            let info = individualPost["tagCount"] as! Int 
                                            let post: [String:Any] = ["tag": tag, "info": info]
                                            posts.append(post)
                                            
                                        } else {
                                            var postType: String
                                            if let _ = individualPost["userHandle"] as? String {
                                                postType = "pond"
                                            } else {
                                                postType = "anon"
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
                                            
                                            if postType == "anon"  {
                                                var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                                if !imageKey.contains("default") {
                                                    let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                    if !self.urlArray.contains(imageURL) {
                                                        self.urlArray.append(imageURL)
                                                    }
                                                    post["imageURL"] = imageURL
                                                }
                                                posts.append(post)
                                                
                                            } else {
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
                                        }
                                    }
                                    
                                    let ad = ["postID": -2]
                                    var i: Int = 1
                                    for _ in posts {
                                        if i%40 == 0 {
                                            posts.insert(ad, at: i-1)
                                        }
                                        i = i+1
                                    }
                                    
                                    if lastPostID != 0 {
                                        let latestPost = posts.last!
                                        if lastPostID != latestPost["postID"] as! Int {
                                            switch self.segment {
                                            case "pond":
                                                self.pondPosts.append(contentsOf: posts)
                                                if self.pondPosts.count > 210 {
                                                    let difference = self.pondPosts.count - 210
                                                    let indicesToRemove = 0...(difference-1)
                                                    self.pondPosts = self.pondPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                                }
                                            case "anon":
                                                self.anonPosts.append(contentsOf: posts)
                                                if self.anonPosts.count > 210 {
                                                    let difference = self.anonPosts.count - 210
                                                    let indicesToRemove = 0...(difference-1)
                                                    self.anonPosts = self.anonPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                                }
                                            case "hot":
                                                self.hotPosts.append(contentsOf: posts)
                                                if self.hotPosts.count > 210 {
                                                    let difference = self.hotPosts.count - 210
                                                    let indicesToRemove = 0...(difference-1)
                                                    self.hotPosts = self.hotPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                                }
                                            case "trendingList":
                                                self.trendingList = posts
                                            case "trending":
                                                self.trendingPosts.append(contentsOf: posts)
                                                if self.trendingPosts.count > 210 {
                                                    let difference = self.trendingPosts.count - 210
                                                    let indicesToRemove = 0...(difference-1)
                                                    self.trendingPosts = self.trendingPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                                }
                                            case "friend":
                                                self.friendPosts.append(contentsOf: posts)
                                                if self.friendPosts.count > 210 {
                                                    let difference = self.friendPosts.count - 210
                                                    let indicesToRemove = 0...(difference-1)
                                                    self.friendPosts = self.friendPosts.enumerated().filter{!indicesToRemove.contains($0.offset)}.map{$0.element}
                                                }
                                            default:
                                                return
                                            }
                                        }
                                    } else {
                                        switch self.segment {
                                        case "pond":
                                            self.pondPosts = posts
                                        case "anon":
                                             self.anonPosts = posts
                                        case "hot":
                                            self.hotPosts = posts
                                        case "trendingList":
                                            self.trendingList = posts
                                        case "trending":
                                            self.trendingPosts = posts
                                        case "friend":
                                            self.friendPosts = posts
                                        default:
                                            return
                                        }
                                    }
                                    
                                    self.loadAds()
                                    
                                    if !posts.isEmpty {
                                        var firstRows = 4
                                        let maxCount = posts.count
                                        if firstRows >= (maxCount - 1) {
                                            firstRows = maxCount - 1
                                        }
                                        
                                        var urlsToPrefetch: [URL] = []
                                        for index in 0...firstRows {
                                            let post = posts[index]
                                            if let picURL = post["picURL"] as? URL {
                                                urlsToPrefetch.append(picURL)
                                            }
                                            if let imageURL = post["imageURL"] as? URL {
                                                urlsToPrefetch.append(imageURL)
                                            }
                                        }
                                        
                                        SDWebImagePrefetcher.shared().prefetchURLs(urlsToPrefetch, progress: nil, completed: { (completed, skipped) in
                                            self.firstLoad = false
                                            self.pondListTableView.reloadData()
                                        })
                                    } else {
                                        self.firstLoad = false
                                        self.pondListTableView.reloadData()
                                    }
                                } else {
                                    self.firstLoad = false
                                    self.pondListTableView.reloadData()
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
            self.displayAlert("Token Error", alertMessage: "We messed up. Please report the bug by going to the report section in the menu if this persists.")
            return
        }
    }
    
    func refreshWithDelay() {
        if self.scrollPosition == "top" {
            self.perform(#selector(self.observePond), with: nil, afterDelay: 0.1)
        } else {
            self.perform(#selector(self.getPondList), with: nil, afterDelay: 0.5)
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

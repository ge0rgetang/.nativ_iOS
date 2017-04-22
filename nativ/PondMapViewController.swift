//
//  PondMapViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift
import SDWebImage
import SideMenu
import MIBadgeButton_Swift
import DTMHeatmap

class PondMapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate {

    // MARK: - Outlets/Variables
    
    var myID: Int = 0
    var myIDFIR: String = "0000000000000000000000000000"
    
    var segment: String = "pond"
    var firstLoad: Bool = true
    var firstLoadConstraints: Bool = true
    var isKeyboardUp: Bool = false
    var newPostsCount: Int = 0
    var parentRow: Int = 0
    var isEditingLocation: Bool = false
    var isCenterSelected: Bool = true
    
    var radius: Double = 0.5
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
    
    var urlArray: [URL] = []
    var postIDArray: [Int] = []
    var pondPosts: [[String:Any]] = []
    var anonPosts: [[String:Any]] = []
    var hotPosts: [[String:Any]] = []
    var trendingList: [[String:Any]] = []
    var tagsToRemove: [String] = []
    var tagArrayForHeatMap: [[String:Any]] = []
    var friendPosts: [[String:Any]] = []
    
    let misc = Misc()
    var badgeButton = MIBadgeButton()
    var badgeBarButton = UIBarButtonItem()
    var dimView = UIView()
    var centerPin = MKPointAnnotation()
    var recenterButton = UIButton()
    var buttonLabel = UILabel()
    
    var heatMap = DTMHeatmap()
    
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
            self.setMapCenter()
            self.getLocation(self.locationTextField.text!)
        }
    }
    
    @IBOutlet weak var mapListSegmentedControl: UISegmentedControl!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var radiusSegmentedControl: UISegmentedControl!
    
    @IBAction func unwindToPondMap(_ segue: UIStoryboardSegue){}
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager = CLLocationManager()
        self.checkAuthorizationStatus()
        self.navigationItem.title = "Flow"
        self.navigationItem.titleView = self.locationTextField
        
        self.mapListSegmentedControl.selectedSegmentIndex = 0
        self.mapListSegmentedControl.addTarget(self, action: #selector(self.mapListDidChange), for: .valueChanged)
       
        self.radiusSegmentedControl.selectedSegmentIndex = 0
        self.radiusSegmentedControl.addTarget(self, action: #selector(self.radiusSegmentDidChange), for: .valueChanged)
        
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControl.addTarget(self, action: #selector(self.sortCriteriaDidChange), for: .valueChanged)
        self.locationTextField.delegate = self
        self.locationTextField.placeholder = "here, zip, city"
        
        self.mapView.delegate = self
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 160.934
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        self.setSideMenu()
        self.setMenuBarButton()
        
        self.dimView.isUserInteractionEnabled = false
        self.dimView.backgroundColor = .black
        self.dimView.alpha = 0
        self.dimView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.mapView.addSubview(self.dimView)
        
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didDragMap))
        dragGesture.delegate = self
        self.mapView.addGestureRecognizer(dragGesture)
        
        self.setMapCenter()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.mapListSegmentedControl.selectedSegmentIndex = 0
        self.setRadiusSegmentBasedOnRadius()
        self.locationTextField.text = self.locationText
        
        switch self.segment {
        case "pond":
            self.segmentedControl.selectedSegmentIndex = 0
        case "anon":
            self.segmentedControl.selectedSegmentIndex = 1
        case "hot":
            self.segmentedControl.selectedSegmentIndex = 2
        case "trendingList":
            self.segmentedControl.selectedSegmentIndex = 3
        case "friend":
            self.segmentedControl.selectedSegmentIndex = 4
        default:
            self.segmentedControl.selectedSegmentIndex = 0
        }
        
        let myInfo = misc.setMyID()
        self.myID = myInfo[1] as! Int
        self.myIDFIR = myInfo[2] as! String
        
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
        
        self.logViewPondMap()
        misc.setSideMenuIndex(0)
        self.setNotifications()
        self.updateBadge()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.mapView.remove(self.heatMap)
        self.setHeatMapData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.locationManager.stopUpdatingLocation()
        self.removeObserverForPond()
        self.dismissKeyboard()
        if self.urlArray.count >= 210 {
            self.clearArrays()
        }
        if self.locationTextField.text != "" {
            self.locationText = self.locationTextField.text!
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
    
    // MARK: - MapView
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        let reuseID = "skinnyDip"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            annotationView?.pinTintColor = misc.nativColor
            annotationView?.canShowCallout = true
            annotationView?.isEnabled = true
            annotationView?.isUserInteractionEnabled = true
            annotationView?.animatesDrop = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return DTMHeatmapRenderer.init(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.annotationTapped))
        view.addGestureRecognizer(tap)
    }
    
    func annotationTapped(gesture: UITapGestureRecognizer) {
        if self.isCenterSelected {
            self.mapView.deselectAnnotation(self.centerPin, animated: true)
            self.isCenterSelected = false
        } else {
            self.mapView.selectAnnotation(self.centerPin, animated: true)
            self.isCenterSelected = true
        }
    }
    
    func setMapCenter() {
        self.recenterButton.removeFromSuperview()
        self.buttonLabel.removeFromSuperview()
        
        let center = CLLocationCoordinate2DMake(self.latitude, self.longitude)
        let radiusMeters = self.radius * 1609.34
        let region = MKCoordinateRegionMakeWithDistance(center, radiusMeters, radiusMeters)
        self.mapView.setRegion(region, animated: true)
        
        self.mapView.removeAnnotation(self.centerPin)
        self.centerPin = MKPointAnnotation()
        self.centerPin.coordinate = center
        self.centerPin.title = "Flow Center"
        self.mapView.addAnnotation(self.centerPin)
        self.mapView.selectAnnotation(self.centerPin, animated: true)
        self.isCenterSelected = true
    }
    
    func setHeatMapData() {
        var posts: [[String:Any]]
        switch self.segment {
        case "pond":
            posts = self.pondPosts
        case "anon":
            posts = self.anonPosts
        case "hot":
            posts = self.hotPosts
        case "trendingList":
            posts = self.tagArrayForHeatMap 
        case "friend":
            posts = self.friendPosts
        default:
            return
        }
        
        self.heatMap = DTMHeatmap()
        var dict: [AnyHashable:Any] = [:]
        for post in posts {
            let postID = post["postID"] as! Int
            if postID > 0 {
                let longitude = post["longitude"] as! Double
                let latitude = post["latitude"] as! Double
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                var mapPoint = MKMapPointForCoordinate(coordinate)
                
                let type = "{MKMapPoint=dd}"
                let value = NSValue(bytes: &mapPoint, objCType: type)
                dict[value] = 1
            }
        }
        
        self.mapView.remove(self.heatMap)
        self.heatMap.setData(dict)
        self.mapView.add(self.heatMap)
    }
    
    // NOTE: displays labels on map
    
//    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
//        for view in views {
//            let annotation = view.annotation!
//            let subtitle = annotation.subtitle!
//            if let sub = subtitle {
//                if let dict = self.convertToDict(sub) {
//                    let postID = dict["postID"] as! Int
//                    if !self.postIDArray.contains(postID) {
//                        view.alpha = 0
//                        UIView.animate(withDuration: 0.1, animations: {
//                            view.alpha = 1
//                        })
//                        self.postIDArray.append(postID)
//                    }
//                }
//            }
//        }
//    }
    
//    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
//        let annotation = view.annotation!
//        let subtitle = annotation.subtitle!
//        if let dict = self.convertToDict(subtitle!) {
//            let postID = dict["postID"] as! Int
//            
//                var posts: [[String:Any]]
//                switch self.segment {
//                case "pond":
//                    posts = self.pondPosts
//                case "anon":
//                    posts = self.anonPosts
//                case "hot":
//                    posts = self.hotPosts
//                case "trendingList", "trending":
//                    posts = self.trendingPosts
//                case "friend":
//                    posts = self.friendPosts
//                default:
//                    return
//            }
//            
//            if !posts.isEmpty && !self.isKeyboardUp {
//                for (index, post) in posts.enumerated() {
//                    if postID == post["postID"] as! Int {
//                        self.parentRow = index
//                        if postID > 0 {
//                            self.parentPostToPass = post
//                            self.performSegue(withIdentifier: "fromPondMapToDrop", sender: self)
//                        }
//                        break
//                    }
//                }
//            }
//            
//            
//            if  ((self.segment == "pond" && self.pondPosts.isEmpty) || (self.segment == "anon" && self.anonPosts.isEmpty)) && self.myID > 0 {
//                self.textView.becomeFirstResponder()
//            }
//        }
//        
        
//    }
    
//    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
//        let center = mapView.centerCoordinate
////        self.longitude = center.longitude
////        self.latitude = center.latitude
//        
//        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
//        let convertPoint = CGPoint(x: mapView.frame.size.width/2, y: 0)
//        let topCenterCoordinate = mapView.convert(convertPoint, toCoordinateFrom: mapView)
//        let topCenterLocation = CLLocation(latitude: topCenterCoordinate.latitude, longitude: topCenterCoordinate.longitude)
//        
//        let radiusM = centerLocation.distance(from: topCenterLocation)
//        let radiusMi = radiusM/1609.34
//        print(radiusM)
//        print(radiusMi)
//        
//        let geocoder = CLGeocoder()
//        geocoder.reverseGeocodeLocation(centerLocation, completionHandler: {(placemarks, error) -> Void in
//            if let placemark = placemarks?.first {
//                self.setLocation(placemark, locationText: "map")
//            }
//        })
//        
//        if mapView.camera.altitude < 6022.79442596758 {
//            mapView.camera.altitude = 6022.79442596758
//        }
//        
//        if scaledRadius < 1.5 {
//            self.radius = 1.5
//            self.setMapCenter()
//        }
//        
//        self.observePond()
//    }
    
//    func setAnnotations() {
//        var posts: [[String:Any]]
//        switch self.segment {
//        case "pond":
//            posts = self.pondPosts
//        case "anon":
//            posts = self.anonPosts
//        case "hot":
//            posts = self.hotPosts
//        case "trendingList", "trending":
//            posts = self.trendingPosts
//        case "friend":
//            posts = self.friendPosts
//        default:
//            return
//        }
//        
//        var annotatedPosts: [[String:Any]]
//        let model = UIDevice.current.modelName
//        if model.contains("iPhone") {
//            if model.lowercased().contains("plus") {
//                annotatedPosts = self.iterateAnnotationArray(posts, i: 6)
//            } else if model.contains("6") || model.contains("7") || model.contains("8") {
//                annotatedPosts = self.iterateAnnotationArray(posts, i: 5)
//            } else {
//                annotatedPosts = self.iterateAnnotationArray(posts, i: 4)
//            }
//            
//            self.mapView.removeAnnotations(self.mapView.annotations)
//            if annotatedPosts.isEmpty {
//                let annotation = MKPointAnnotation()
//                let center = CLLocationCoordinate2DMake(self.latitude, self.longitude)
//                annotation.coordinate = center
//                
//                var title: String
//                switch self.segment {
//                case "pond":
//                    title = "Sorry, no posts around you found. Try another location in the location field above. You can also type a message below and be the first :)"
//                case "anon":
//                    title = "Sorry, no anonymous posts around you found. Try another location in the location field above. You can also type a message below and be the first :)"
//                case "hot":
//                    title = "Sorry, no hot posts over the past few days found. You can try to post yourself and see if it gets popular!"
//                case "trendingList":
//                    title = "Sorry, no trending tags in the area. You can tag posts with .place when writing a post (ex .campus, .thisCafe, .localGym)"
//                case "trending":
//                    title = "Sorry, no posts with that tag found. Try another or leave the bottom field empty to view a list of trending tags."
//                case"friend":
//                    if self.myID <= 0 {
//                        title = "Please sign in to view friend posts."
//                    } else {
//                        title = "No friends have made public posts. Tap on the menu button in the top left and go to the chats/friends section to search for and add friends :)"
//                    }
//                default:
//                    return
//                }
//                annotation.title = title
//                let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "skinnyDip")
//                self.mapView.addAnnotation(annotationView.annotation!)
//                
//            } else {
//                for post in annotatedPosts {
//                    let postID = post["postID"] as! Int
//                    if postID > 0 {
//                        let longitude = post["longitude"] as! Double
//                        let latitude = post["latitude"] as! Double
//                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//                        
//                        let postContent = post["postContent"] as! String
//                        let timestamp = post["timestamp"] as! String
//                        
//                        var title: String
//                        if let handle = post["userHandle"] as? String {
//                            title = "@\(handle) \(timestamp) \(postContent)"
//                        } else {
//                            title = "\(timestamp) \(postContent)"
//                        }
//                        
//                        let annotation = MKPointAnnotation()
//                        annotation.coordinate = coordinate
//                        annotation.title = title
//                        annotation.subtitle = "{\"postID\":\"\(postID)\", \"timestamp\":\"\(timestamp)\"}"
//                        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "skinnyDip")
//                        self.mapView.addAnnotation(annotationView.annotation!)
//                    }
//                }
//            }
//        }
//        
//        self.setHeatMapData(posts)
//    
//    }
    
//    func iterateAnnotationArray(_ posts: [[String:Any]], i: Int) -> [[String:Any]] {
//        var count: Int
//        if posts.count < i {
//            count = posts.count
//        } else {
//            count = i
//        }
//        
//        let annotationSlice = posts.prefix(count)
//        let annotationArray: [[String:Any]] = Array(annotationSlice)
//        return annotationArray
//    }
    
    // MARK: - Map Drag 
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func didDragMap(gesture: UIGestureRecognizer) {
        if gesture.state == .ended {
            self.perform(#selector(self.addRecenter), with: nil, afterDelay: 0.15)
        }
    }
    
    func addRecenter() {
        self.recenterButton.removeFromSuperview()
        self.buttonLabel.removeFromSuperview()
        
        self.recenterButton = UIButton(frame: CGRect(x: self.mapView.center.x  - 25, y: self.mapView.center.y - 34, width: 50, height: 50))
        self.recenterButton.layer.backgroundColor = UIColor(white: 0, alpha: 0.15).cgColor
        self.recenterButton.layer.cornerRadius = self.recenterButton.frame.size.width/2
        self.recenterButton.clipsToBounds = true
        self.recenterButton.imageView?.contentMode = .scaleAspectFit
        self.recenterButton.setImage(UIImage(named: "recenter"), for: .normal)
        self.recenterButton.addTarget(self, action: #selector(self.recenterAction), for: .touchUpInside)
        self.view.addSubview(self.recenterButton)

        self.buttonLabel = UILabel(frame: CGRect(x: self.mapView.center.x - 52.5, y: self.mapView.center.y + 25, width: 105, height: 20))
        self.buttonLabel.text = "tap to recenter"
        self.buttonLabel.textColor = misc.nativColor
        self.buttonLabel.layer.backgroundColor = UIColor(white: 0, alpha: 0.15).cgColor
        self.buttonLabel.textAlignment = .center
        self.buttonLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.view.addSubview(self.buttonLabel)
    }
    
    func recenterAction() {
        self.recenterButton.removeFromSuperview()
        self.buttonLabel.removeFromSuperview()
        
        let center = self.mapView.centerCoordinate
        self.longitude = center.longitude
        self.latitude = center.latitude
        
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
            if let placemark = placemarks?.first {
                self.setLocation(placemark, locationText: "map")
            }
        })
        self.setMapCenter()
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
    
    func unwindToPondList() {
        self.performSegue(withIdentifier: "unwindFromPondMapToPondList", sender: self)
    }
    
    // MARK: - SendImagePostProtocol
    
    func insertImagePost(_ post: [String : Any]) {
        switch self.segment {
        case "pond":
            self.pondPosts.insert(post, at: 0)
        case "anon":
            self.anonPosts.insert(post, at: 0)
        default:
            return
        }
    }
    
    // MARK: - Location
    
    func checkAuthorizationStatus() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
            self.locationTextField.text = "Berkeley, CA"
            
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
            self.locationTextField.text = "Berkeley, Ca"
            
        default:
            self.locationTextField.text = self.locationText
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            self.locationTextField.text = self.locationText
            self.locationManager.startUpdatingLocation()
        } else {
            self.locationTextField.text = "Berkeley, CA"
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
                    self.resetRadius(5, t: 0)
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
                }
            })
            
        }
    }
    
    func setLocation(_ placemark: CLPlacemark, locationText: String) {
        let decimalSet = CharacterSet.decimalDigits
        let decimalRange = locationText.rangeOfCharacter(from: decimalSet)
        
        if locationText != "here" {
            if let city = placemark.locality {
                let placemarkLocation = placemark.location!.coordinate
                self.longitude = placemarkLocation.longitude
                self.latitude = placemarkLocation.latitude
                if let state = placemark.administrativeArea {
                    if decimalRange != nil {
                        self.locationTextField.text = locationText
                    } else {
                        let locationString: String = "\(city), \(state)"
                        self.locationTextField.text = locationString
                    }
                } else {
                    if decimalRange != nil {
                        self.locationTextField.text = locationText
                    } else {
                        self.locationTextField.text = city
                    }
                }
            } else {
                let status = CLLocationManager.authorizationStatus()
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    self.locationTextField.text = "here"
                    let location = self.locationManager.location!.coordinate
                    self.longitude = location.longitude
                    self.latitude = location.latitude
                } else {
                    self.locationTextField.text = "Berkeley, CA"
                    self.longitude = -122.258542
                    self.latitude = 37.871906
                }
                self.displayAlert("Invalid Location", alertMessage: "Please enter a valid city, zip, or here (with location services enabled)")
                return
            }
        } else {
            self.locationTextField.text = "here"
            let location = self.locationManager.location!.coordinate
            self.longitude = location.longitude
            self.latitude = location.latitude
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
            self.locationText = textField.text!
            self.firstLoad = true
            self.clearArrays()
            
            if textField.text?.lowercased().trimSpace() == "here" && !(status == .authorizedWhenInUse || status == .authorizedAlways) {
                textField.text = "Berkeley, CA"
                self.displayAlert("Location Services Disabled", alertMessage: "We cannot find your location since location services have not been authorized. Please go to settings to authorize or type a different place.")
                return
            } else {
                self.logViewDifferentLocation()
                self.getLocation(self.locationTextField.text!)
            }
        }
    }
    
    // MARK: - Sort Options
    
    func mapListDidChange(_ sender: UISegmentedControl) {
        self.unwindToPondList()
    }
    
    func sortCriteriaDidChange(_ sender: UISegmentedControl) {
        self.dismissKeyboard()
        self.resetRadius(0.5, t: 0)
        self.firstLoad = true
        let locationText = self.locationTextField.text
        if locationText == "" {
            let status = CLLocationManager.authorizationStatus()
            if locationText == "" {
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationTextField.text = "here"
                } else {
                    self.locationTextField.text = "Berkeley, CA"
                }
            }
        }
        
        switch sender.selectedSegmentIndex {
        case 0:
            self.segment = "pond"
            self.logViewPondNew()
        case 1:
            self.segment = "anon"
            self.logViewPondAnon()
        case 2:
            self.segment = "hot"
            self.logViewPondHot()
        case 3:
            self.segment = "trendingList"
            self.logViewPondTrending()
        case 4:
            self.segment = "friend"
            self.logViewPondFriend()
        default:
            return
        }
        
        self.mapView.remove(self.heatMap)
        self.setHeatMapData()
        self.observePond()
    }
    
    func radiusSegmentDidChange(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.resetRadius(0.5, t: 0)
        case 1:
            self.resetRadius(1.0, t: 0)
        case 2:
            self.resetRadius(2.5, t: 0)
        default:
            self.resetRadius(5.0, t: 0)
        }
        
        self.setMapCenter()
        self.observePond()
    }
    
    func setRadiusSegmentBasedOnRadius() {
        let rad = self.radius
        
        if rad <= 0.75 {
            self.radiusSegmentedControl.selectedSegmentIndex = 0
            self.radius = 0.5
        } else if  rad > 0.75 && rad <= 1.5 {
            self.radiusSegmentedControl.selectedSegmentIndex = 1
            self.radius = 1.0
        } else if rad > 1.5 && rad <= 3.5 {
            self.radiusSegmentedControl.selectedSegmentIndex = 2
            self.radius = 2.5
        } else {
            self.radiusSegmentedControl.selectedSegmentIndex = 3
            self.radius = 5.0
        }
    }
    
    // MARK: - Keyboard
    
    func dismissKeyboard() {
        self.locationTextField.resignFirstResponder()
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(_ notification: Notification) {
        self.isKeyboardUp = true
        self.dimBackground(true)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        self.dimBackground(false)
        self.isEditingLocation = false
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateBadge), name: NSNotification.Name(rawValue: "didReceiveNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshWithDelay), name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeObserverForPond), name: NSNotification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "addFirebaseObservers"), object: nil)
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
            self.firstLoad = false
            self.present(alertController, animated: true, completion: nil)
        })
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
    
    func convertToDict(_ str: String) -> [String:Any]? {
        if let data = str.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    func clearArrays() {
        self.urlArray = []
        self.pondPosts = []
        self.anonPosts = []
        self.hotPosts = []
        self.friendPosts = []
        self.postIDArray = []
        self.trendingList = []
    }
    
    // MARK: - Analytics
    
    func logViewPondMap() {
        FIRAnalytics.logEvent(withName: "viewPondMap", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondNew() {
        FIRAnalytics.logEvent(withName: "viewPondMapNew", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondAnon() {
        FIRAnalytics.logEvent(withName: "viewPondMapAnon", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondHot() {
        FIRAnalytics.logEvent(withName: "viewPondMapHot", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondTrending() {
        FIRAnalytics.logEvent(withName: "viewPondMapTrending", parameters: [
            "userID": self.myID as NSObject,
            "userIDFIR": self.myIDFIR as NSObject
            ])
    }
    
    func logViewPondFriend() {
        FIRAnalytics.logEvent(withName: "viewPondMapFriend", parameters: [
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
            
        case "friend":
            if self.myID > 0 {
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
    
    func removeObserverForPond() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        let pondRef = self.ref.child("posts")
        pondRef.removeAllObservers()
        
        let anonRef = self.ref.child("anonPosts")
        anonRef.removeAllObservers()
        
        let tagRef = self.ref.child("locationTags")
        tagRef.removeAllObservers()
        for tag in self.tagsToRemove {
            tagRef.child(tag).removeAllObservers()
        }
    }
    
    func writePostSent (_ postID: Int, postType: String, longitude: Double, latitude: Double, postContent: String, tags: [String]) {
        if postType == "pond" {
            let pondRef = self.ref.child("posts").child("\(postID)")
            pondRef.child("longitude").setValue(longitude)
            pondRef.child("latitude").setValue(latitude)
            pondRef.child("points").setValue(0)
            pondRef.child("tags").setValue(tags)
            pondRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let myPondRef = self.ref.child("users").child(self.myIDFIR).child("posts").child("\(postID)")
            myPondRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
        } else {
            let anonRef = self.ref.child("anonPosts").child("\(postID)")
            anonRef.child("longitude").setValue(longitude)
            anonRef.child("latitude").setValue(latitude)
            anonRef.child("points").setValue(0)
            anonRef.child("tags").setValue(tags)
            anonRef.child("parent").setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
            
            let myAnonRef = self.ref.child("users").child(self.myIDFIR).child("anonPosts").child("\(postID)")
            myAnonRef.setValue(["userID": self.myID, "userIDFIR": self.myIDFIR, "postContent": postContent, "timestamp": misc.getTimestamp("mine"), "shareCount": 0])
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
        } else {
            self.perform(#selector(self.getPondList), with: nil, afterDelay: 0.5)
        }
    }
    
    func getPondList() {
        self.newPostsCount = 0
        let postID: Int = 0
        let picSize: String = "small"
        let isExact: String = "yes"
        let lastPostID: Int = 0
        let pageNumber: Int = 0
        
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
                if self.firstLoad || self.trendingList.isEmpty {
                    getURL = URL(string: "https://dotnative.io/getTrendingTags")
                    getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&longitude=\(self.longitude)&latitude=\(self.latitude)&radius=\(self.radius)&timeDel=\(self.timeDel)&hours=72"
                } else {
                    getURL = URL(string: "https://dotnative.io/getMixedPost")
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
                    getString = "iv=\(iv)&token=\(cipherText)&myID=\(self.myID)&isMine=\(isMine)&longitude=\(self.longitude)&latitude=\(self.latitude)&postID=\(postID)&sort=\(sort)&isExact=\(isExact)&size=\(picSize)&lastPostID=\(lastPostID)&pageNumber=\(pageNumber)&radius=\(self.radius)&timeDel=\(self.timeDel)&locationTag=\(tagArray)"
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
                            
                            if status == "error" {
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
                                    if self.firstLoad || self.trendingList.isEmpty {
                                        dictKey = "locationTags"
                                    } else {
                                        dictKey = "posts"
                                    }
                                case "trending":
                                    dictKey = "posts"
                                case "friend":
                                    dictKey = "pondPosts"
                                default:
                                    return
                                }
                                
                                if let timeDel = parseJSON["timeDel"] as? Int {
                                    self.timeDel = timeDel
                                }
                                
                                if let postsArray = parseJSON[dictKey] as? [[String:Any]] {
                                    var posts: [[String:Any]] = []
                                    for individualPost in postsArray {
                                        if self.segment == "trendingList" && (self.firstLoad || self.trendingList.isEmpty) {
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
                                            let longitude: Double = Double(long)!
                                            let lat = individualPost["latitude"] as! String
                                            let latitude: Double = Double(lat)!
                                            
                                            let imageKey = individualPost["imageKey"] as! String
                                            let imageBucket = individualPost["imageBucket"] as! String
                                            
                                            if postType == "anon"  {
                                                var post: [String:Any] = ["postID": postID, "userID": userID, "userIDFIR": userIDFIR, "postContent": postContent, "timestamp": timestamp, "replyCount": replyCount, "pointsCount": pointsCount, "didIVote": didIVote, "shareCount": shareCount, "longitude": longitude, "latitude": latitude]
                                                if !imageKey.contains("default") {
                                                    let imageURL = URL(string: "https://\(imageBucket).s3.amazonaws.com/\(imageKey)")!
                                                    if !self.urlArray.contains(imageURL) {
                                                        self.urlArray.append(imageURL)
                                                        SDWebImagePrefetcher.shared().prefetchURLs([imageURL])
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
                                                        SDWebImagePrefetcher.shared().prefetchURLs([imageURL])
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
                                        if i%20 == 0 {
                                            posts.insert(ad, at: i-1)
                                        }
                                        i = i+1
                                    }
                                    switch self.segment {
                                    case "pond":
                                        self.pondPosts = posts
                                    case "anon":
                                        self.anonPosts = posts
                                    case "hot":
                                        self.hotPosts = posts
                                    case "trendingList":
                                        if self.firstLoad || self.trendingList.isEmpty {
                                            self.trendingList = posts
                                        } else {
                                            self.tagArrayForHeatMap = posts 
                                        }
                                    case "friend":
                                        self.friendPosts = posts
                                    default:
                                        return
                                    }
                                }
                                
                                if self.segment == "trendingList" && self.firstLoad {
                                    self.firstLoad = false
                                    self.getPondList()
                                }
                                self.firstLoad = false
                                self.mapView.remove(self.heatMap)
                                self.setHeatMapData()
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
    
    func refreshWithDelay() {
        self.perform(#selector(self.observePond), with: nil, afterDelay: 0.1)
    }
    
}

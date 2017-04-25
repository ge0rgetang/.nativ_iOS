//
//  Misc.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import Foundation
import UIKit
import FirebaseAnalytics
import FirebaseDatabase
import CryptoSwift
import SDWebImage

class Misc: NSObject {
    
    let nativColor = UIColor(red: 70/255.0, green: 140/255.0, blue: 115/255.0, alpha: 1)
    let nativSemiFade = UIColor(red: 70/255.0, green: 140/255.0, blue: 115/255.0, alpha: 0.5)
    let nativFade = UIColor(red: 70/255.0, green: 140/255.0, blue: 115/255.0, alpha: 0.15)
    let nativSideMenu = UIColor(red: 70/255.0, green: 140/255.0, blue: 115/255.0, alpha: 0.3)
    let softGrayColor = UIColor(red: 240/255.0, green: 240/255.0, blue: 240/255.0, alpha: 1)
    
    func generateToken(_ length: Int, firebaseID: String) -> [String] {
        let characters: NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let characterLength = UInt32(characters.length)
        
        var random = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(characterLength)
            var nextChar = characters.character(at: Int(rand))
            random += NSString(characters: &nextChar, length: 1) as String
        }
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: 30, to: now)
        let later = formatter.string(from: date!)
        
        let token = firebaseID + later
        
        let key = "vLhLbQexoJ9D2WVUJcH18tvYw7IxcgNF"
        
        return [random, key, token]
    }
    
    func setMyID() -> [Any] {
        var isUserLoggedIn: Bool
        var myID: Int
        var myIDFIR: String
        
        isUserLoggedIn = UserDefaults.standard.bool(forKey: "isUserLoggedIn.nativ")
        myID = UserDefaults.standard.integer(forKey: "myID.nativ")
        if let firebaseID = UserDefaults.standard.string(forKey: "myIDFIR.nativ") {
            myIDFIR = firebaseID
        } else {
            myIDFIR = "0000000000000000000000000000"
        }
        
        return [isUserLoggedIn, myID, myIDFIR]
    }
    
    func checkSpecialCharacters(_ string: String) -> Bool {
        let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ0123456789")
        if string.rangeOfCharacter(from: set.inverted) != nil {
            return true
        } else {
            return false
        }
    }
    
    func truncateName(_ name: String) -> String {
        let spaceCharacter = CharacterSet.whitespaces
        let nameTrim: String = name.trimSpace()
        if nameTrim.rangeOfCharacter(from: spaceCharacter) != nil {
            let nameArray = name.components(separatedBy: " ")
            let firstName: String = nameArray.first!
            let lastName: String = nameArray.last!
            let lastNameArray = Array(lastName.characters)
            let lastNameInitial = lastNameArray[0]
            let nameTrunc = "\(firstName)" + " " + "\(lastNameInitial)"
            return nameTrunc
        } else {
            return nameTrim
        }
    }
    
    func makeButtonFancy(_ button: UIButton, title: String, view: UIView) {
        let attributedTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.white])
        let defaultTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: self.nativColor])
        button.backgroundColor = view.backgroundColor
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = self.nativColor.cgColor
        button.setAttributedTitle(attributedTitle, for: .highlighted)
        button.setAttributedTitle(attributedTitle, for: .selected)
        button.setAttributedTitle(attributedTitle, for: .focused)
        button.setAttributedTitle(defaultTitle, for: .normal)
    }
    
    func makeTopButtonFancy(_ button: UIButton, title: String) {
        let attributedTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.white])
        let defaultTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: self.nativColor])
        button.backgroundColor = UIColor(white: 0, alpha: 0.05)
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = self.nativColor.cgColor
        button.setAttributedTitle(attributedTitle, for: .highlighted)
        button.setAttributedTitle(attributedTitle, for: .selected)
        button.setAttributedTitle(attributedTitle, for: .focused)
        button.setAttributedTitle(defaultTitle, for: .normal)
    }
    
    func colorButton(_ button: UIButton, event: String, view: UIView) {
        if event == "down" {
            button.backgroundColor = self.nativSemiFade
        } else {
            button.backgroundColor = view.backgroundColor
        }
    }
    
    func formatTextView(_ textView: UITextView) {
        textView.isScrollEnabled = false
        textView.layer.cornerRadius = 5
        textView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.layer.masksToBounds = true
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
    }
    
    func setTextViewPlaceholder(_ textView: UITextView, placeholder: String) {
        textView.text = placeholder
        textView.textColor = .lightGray
    }
    
    func formatTimestamp(_ timestampString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.date(from: timestampString)
        
        dateFormatter.dateFormat = "MMM d, h:mm a"
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        let timestamp = dateFormatter.string(from: date!)
        return timestamp
    }
    
    func getTimestamp(_ zone: String) -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        if zone == "UTC" {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        } else {
            dateFormatter.dateFormat = "MMM d, h:mm a"
            dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        }
        return dateFormatter.string(from: date)
    }
    
    func setTimestamps(_ start: String, end: String) -> [String] {
        let startArray = start.components(separatedBy: " ")
        let endArray = end.components(separatedBy: " ")
        let startLast = startArray.last
        let endLast = endArray.last
        if startLast == endLast {
            let newString = startArray[0] + " " + startArray[1]
            let new = newString.replacingOccurrences(of: ",", with: "")
            return [new, end]
        } else {
            return [start, end]
        }
    }
    
    func setCount(_ count: Int) -> String {
        let countDouble = Double(count)
        
        if countDouble >= 10000 && countDouble < 1000000 {
            var countThousand = countDouble/1000
            let countRounded = countThousand.roundToDecimalPlace(1)
            return "\(countRounded)k"
        } else if countDouble >= 1000000 && countDouble < 1000000000 {
            var countMillion = countDouble/1000000
            let countRounded = countMillion.roundToDecimalPlace(1)
            return "\(countRounded)M"
        } else if countDouble >= 1000000000 {
            var countBillion = countDouble/1000000000
            let countRounded = countBillion.roundToDecimalPlace(1)
            return "\(countRounded)B"
        } else if countDouble <= 0 {
            return "-"
        } else {
            return "\(count)"
        }
    }
    
    func setChatID(_ myID: Int, userID: Int) -> String {
        if myID < userID {
            return "\(myID)_\(userID)"
        } else {
            return "\(userID)_\(myID)"
        }
    }
    
    func colorString(_ string: String, wordsToColor: [String], color: UIColor) -> NSMutableAttributedString {
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: string)
        
        for word in wordsToColor {
            let range = (string as NSString).range(of: word)
            attributedString.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
        }
        
        return attributedString
    }
    
    func stringWithColoredTags(_ string: String, time: String, fontSize: CGFloat, timeSize: CGFloat) -> NSMutableAttributedString {
        let stringArray = string.components(separatedBy: " ")
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: string)
        
        var wordsToColor: [String] = []
        for element in stringArray {
            if element.characters.first == "@" || element.characters.first == "." {
                wordsToColor.append(element)
            }
        }
        for word in wordsToColor {
            let range = (string as NSString).range(of: word)
            attributedString.addAttribute(NSForegroundColorAttributeName, value: self.nativColor, range: range)
            let tapAttribute = ["tappedWord": word]
            attributedString.addAttributes(tapAttribute, range: range)
        }
        
        let entireRange = (string as NSString).range(of: string)
        attributedString.addAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: fontSize)], range: entireRange)
        
        if time != "default" {
            let range = (string as NSString).range(of: time)
            attributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.lightGray, range: range)
            attributedString.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: timeSize), range: range)
        }
        
        return attributedString
    }
    
    func anonStringWithColoredTags(_ string: String, time: String, fontSize: CGFloat, timeSize: CGFloat) -> NSMutableAttributedString {
        let stringArray = string.components(separatedBy: " ")
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: string)
        
        var wordsToColor: [String] = []
        for element in stringArray {
            if element.characters.first == "." {
                wordsToColor.append(element)
            }
        }
        for word in wordsToColor {
            let range = (string as NSString).range(of: word)
            attributedString.addAttribute(NSForegroundColorAttributeName, value: self.nativColor, range: range)
            let tapAttribute = ["tappedWord": word]
            attributedString.addAttributes(tapAttribute, range: range)
        }
        
        let entireRange = (string as NSString).range(of: string)
        attributedString.addAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: fontSize)], range: entireRange)
        
        if time != "default" {
            let range = (string as NSString).range(of: time)
            attributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.lightGray, range: range)
            attributedString.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: timeSize), range: range)
        }
        
        return attributedString
    }
    
    func handlesWithoutAt(_ string: String) -> [String] {
        let stringArray = string.components(separatedBy: " ")
        var handles: [String] = []
        
        for element in stringArray {
            if element.characters.first == "@" {
                handles.append(element)
            }
        }
        
        for (index, handle) in handles.enumerated() {
            let handleWithoutAt = handle.replacingOccurrences(of: "@", with: "")
            handles.remove(at: index)
            handles.insert(handleWithoutAt, at: index)
        }
        
        return handles
    }
    
    func tagsWithoutDot(_ string: String) -> [String] {
        let stringArray = string.components(separatedBy: " ")
        var tags: [String] = []
        
        for element in stringArray {
            if element.characters.first == "." {
                tags.append(element)
            }
        }
        
        for (index, tag) in tags.enumerated() {
            let tagWithoutDot = tag.replacingOccurrences(of: ".", with: "")
            tags.remove(at: index)
            tags.insert(tagWithoutDot.lowercased(), at: index)
        }
        
        return tags
    }
    
    func stringWithoutDot(_ string: String) -> [String] {
        var stringArray = string.components(separatedBy: " ")
        
        for (index, element) in stringArray.enumerated() {
            if element.characters.first == "." {
                let tagWithoutDot = element.replacingOccurrences(of: ".", with: "")
                stringArray.remove(at: index)
                stringArray.insert(tagWithoutDot.lowercased(), at: index)
            }
        }
        
        return stringArray
    }
    
    func clearTempDirectory() {
        let fileManager = FileManager.default
        let tempPath = NSTemporaryDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: tempPath)
            for path in filePaths {
                try fileManager.removeItem(atPath: NSTemporaryDirectory() + path)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func getSpecialHandles() -> [String] {
        let spec = ["georgetang", "gtang", "gtang42", "gtang43", "george", "georget", "tang", "native", "nativ"]
        return spec
    }
    
    func getMyBirthComponents() -> [Int] {
        if let birth = UserDefaults.standard.string(forKey: "myBirthday.nativ") {
            var birthString = birth
            birthString = birthString.replacingOccurrences(of: ",", with: "")
            birthString = birthString.replacingOccurrences(of: ".", with: "")
            let birthStringUpper = birthString.uppercased()
            var birthStringArray = birthStringUpper.components(separatedBy: " ")
            
            if birthStringArray.count == 3 {
                let monthString = birthStringArray[0]
                let dayString = birthStringArray[1]
                let yearString = birthStringArray[2]
                
                var monthInt: Int
                switch monthString {
                case "JAN", "JANUARY", "1":
                    monthInt = 1
                case "FEB", "FEBRUARY", "2":
                    monthInt = 2
                case "MAR", "MARCH", "3":
                    monthInt = 3
                case "APR", "APRIL", "4":
                    monthInt = 4
                case "MAY", "5":
                    monthInt = 5
                case "JUN", "JUNE", "6":
                    monthInt = 6
                case "JUL", "JULY", "7":
                    monthInt = 7
                case "AUG", "AUGUST", "8":
                    monthInt = 8
                case "SEP", "SEPT", "SEPTEMBER", "9":
                    monthInt = 7
                case "OCT", "OCTOBER", "10":
                    monthInt = 7
                case "NOV", "NOVEMBER", "11":
                    monthInt = 7
                case "DEC", "DECEMBER", "12":
                    monthInt = 7
                default:
                    monthInt = -2
                }
                
                var dayInt: Int
                if let dayNum = Int(dayString) {
                    dayInt = dayNum
                } else {
                    dayInt = -2
                }
                
                var yearInt: Int
                if let yearNum = Int(yearString) {
                    yearInt = yearNum
                } else {
                    yearInt = -2
                }
                
                return [monthInt, dayInt, yearInt]
                
            } else {
                return [-2, -2, -2]
            }
            
        } else {
            return [-2, -2, -2]
        }
    }
    
    func clearWebImageCache() {
        let imageCache = SDImageCache.shared()
        imageCache.clearMemory()
        imageCache.clearDisk()
    }
    
    func refreshLastView() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "addFirebaseObservers"), object: nil)
    }
    
    func removeObserverForLastView() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "removeFirebaseObservers"), object: nil)
    }
    
    func getNextPageNumber(_ posts: [[String:Any]]) -> Int {
        let count = posts.count
        let adCount = count/20
        let postsCount = count - adCount
        let nextPage = postsCount/42
        
        return nextPage
    }
    
    func getNextPageNumberNoAd(_ posts: [[String:Any]]) -> Int {
        let count = posts.count
        let nextPage = count/42
        
        return nextPage
    }
    
    func resetBadgeForKey(_ key: String) {
        let keyBadge = UserDefaults.standard.integer(forKey: key)
        let badgeNumber = UserDefaults.standard.integer(forKey: "badgeNumber.nativ")
        let difference = badgeNumber - keyBadge
        UserDefaults.standard.set(0, forKey: key)
        UserDefaults.standard.set(difference, forKey: "badgeNumber.nativ")
        UserDefaults.standard.synchronize()
        UIApplication.shared.applicationIconBadgeNumber = difference
    }
    
    func setSideMenuIndex(_ int: Int) {
        UserDefaults.standard.set(int, forKey: "sideMenuIndex.nativ")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - AWS
    
    func clearNotifications(_ subject: String) {
        let myInfo = self.setMyID()
        let myID = myInfo[1] as! Int
        let myIDFIR = myInfo[2] as! String
        
        let token = self.generateToken(16, firebaseID: myIDFIR)
        let iv = token.first!
        let tokenString = token.last!
        let key = token[1]
        
        do {
            let aes = try AES(key: key, iv: iv)
            let cipherText = try aes.encrypt(tokenString.utf8.map({$0}))
            
            let sendURL = URL(string: "https://dotnative.io/clearNotifications")
            var sendRequest = URLRequest(url: sendURL!)
            sendRequest.httpMethod = "POST"
            
            let sendString = "iv=\(iv)&token=\(cipherText)&myID=\(myID)&subject=\(subject)"
            
            sendRequest.httpBody = sendString.data(using: String.Encoding.utf8)
            
            let task = URLSession.shared.dataTask(with: sendRequest as URLRequest) {
                (data, response, error) in
                
                if error != nil {
                    print(error ?? "error")
                    return
                }
                
                do{
                    let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                    
                    if let parseJSON = json {
                        let status: String = parseJSON["status"] as! String
                        let message = parseJSON["message"] as! String
                        print("status: \(status), message: \(message)")
                        
                        DispatchQueue.main.async(execute: {
                            if status == "success" {
                                return
                            }
                        })
                    }
                    
                } catch {
                    print("server error")
                    return
                }
                
            }
            
            task.resume()
            
        } catch {
            print("token error")
            return
        }
    }
    
}

extension String {
    func trimSpace() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

extension Double {
    mutating func roundToDecimalPlace(_ place: Int) -> Double {
        let divisor = pow(10.0, Double(place))
        return (self*divisor).rounded()/divisor
    }
}

extension UIImage {
    convenience init(view: UIView) {
        UIGraphicsBeginImageContextWithOptions(view.frame.size, true, 0.0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: (image?.cgImage)!)
    }
}

public extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
}

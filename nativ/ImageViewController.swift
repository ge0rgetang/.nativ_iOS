//
//  ImageViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import SDWebImage

class ImageViewController: UIViewController {

    // MARK: - Outlets/Variables
    
    var imageURL: URL!
    let misc = Misc()
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var xButton: UIButton!
    @IBAction func xButtonTapped(_ sender: Any) {
        self.dismissVC()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.barTintColor = .black
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        self.navigationController?.navigationBar.tintColor = .white
        
        if let url = self.imageURL {
            self.imageView.sd_setImage(with: url)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    
    func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissVC), name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "unwindToHome"), object: nil)
    }
    
    func dismissVC() {
        self.dismiss(animated: true, completion: nil)
    }
}

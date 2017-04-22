//
//  UserInfoTableViewCell.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserInfoTableViewCell: UITableViewCell {

    @IBOutlet weak var userPicImageView: UIImageView!
    @IBOutlet weak var userHandleLabel: UILabel!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var friendRequestButton: UIButton!
    @IBOutlet weak var friendRequestLabel: UILabel!
    
    @IBOutlet weak var pointsCountLabel: UILabel!
    @IBOutlet weak var userDescriptionLabel: UILabel!
    
    @IBOutlet weak var userPicWidth: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}

//
//  UserListTableViewCell.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserListTableViewCell: UITableViewCell {

    @IBOutlet weak var whiteView: UIView!
    
    @IBOutlet weak var userPicImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userHandleLabel: UILabel!
    @IBOutlet weak var userMessageLabel: UILabel!
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var addLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}

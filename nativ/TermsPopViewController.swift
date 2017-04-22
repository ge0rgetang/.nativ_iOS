//
//  TermsPopViewController.swift
//  nativ
//
//  Created by George Tang on 4/12/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class TermsPopViewController: UIViewController {
    
    // MARK: - Outlets/Variables
    
    @IBOutlet weak var textView: UITextView!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredContentSize = CGSize(width: 320, height: 320)
        self.textView.text = self.termsText
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Terms Text
    
    var termsText =
        ".nativ App End User License Agreement" + "\r\n\n" +
            
            "This End User License Agreement (“Agreement”) is between you and .nativ and governs use of this app made available through the Apple App Store. By installing the .nativ App, you agree to be bound by this Agreement and understand that there is no tolerance for objectionable content. If you do not agree with the terms and conditions of this Agreement, you are not entitled to use the .nativ App." + "\r\n\n" +
            
            "In order to ensure .nativ provides the best experience possible for everyone, we strongly enforce a no tolerance policy for objectionable content. If you see inappropriate content, please use the “Report” feature found under each post." + "\r\n\n" +
            
            "1. Parties" + "\r\n" +
            "This Agreement is between you and .nativ only, and not Apple, Inc. (“Apple”). Notwithstanding the foregoing, you acknowledge that Apple and its subsidiaries are third party beneficiaries of this Agreement and Apple has the right to enforce this Agreement against you. .nativ, not Apple, is solely responsible for the .nativ app and its content." + "\r\n\n" +
            
            "2. Privacy" + "\r\n" +
            ".nativ may collect and use information about your usage of the .nativ App, including certain types of information from and about your device. .nativ may use this information, as long as it is in a form that does not personally identify you, to measure the use and performance of the .nativ App." + "\r\n\n" +
            
            "3. Limited License" + "\r\n" +
            ".nativ grants you a limited, non-exclusive, non-transferable, revocable license to use the .nativ App for your personal, non-commercial purposes. You may only use the .nativ App on Apple devices that you own or control and as permitted by the App Store Terms of Service." + "\r\n\n" +
            
            "4. Age Restrictions" + "\r\n" +
            "By using the .nativ App, you represent and warrant that (a) you are 17 years of age or older and you agree to be bound by this Agreement; (b) if you are under 17 years of age, you have obtained verifiable consent from a parent or legal guardian; and (c) your use of the .nativ App does not violate any applicable law or regulation. Your access to the .nativ App may be terminated without warning if .nativ believes, in its sole discretion, that you are under the age of 17 years and have not obtained verifiable consent from a parent or legal guardian. If you are a parent or legal guardian and you provide your consent to your child’s use of the .nativ App, you agree to be bound by this Agreement in respect to your child’s use of the .nativ App." + "\r\n\n" +
            
            "5. Objectionable Content Policy" + "\r\n" +
            "Content may not be submitted to .nativ, who will moderate all content and ultimately decide whether or not to post a submission to the extent such content includes, is in conjunction with, or alongside any, Objectionable Content. Objectionable Content includes, but is not limited to: (i) sexually explicit materials; (ii) obscene, defamatory, libelous, slanderous, violent and/or unlawful content or profanity; (iii) content that infringes upon the rights of any third party, including copyright, trademark, privacy, publicity or other personal or proprietary right, or that is deceptive or fraudulent; (iv) content that promotes the use or sale of illegal or regulated substances, tobacco products, ammunition and/or firearms; and (v) gambling, including without limitation, any online casino, sports books, bingo or poker." + "\r\n\n" +
            
            "6. Warranty" + "\r\n" +
            ".nativ disclaims all warranties about the .nativ App to the fullest extent permitted by law. To the extent any warranty exists under law that cannot be disclaimed, .nativ, not Apple, shall be solely responsible for such warranty." + "\r\n\n" +
            
            "7. Maintenance and Support" + "\r\n" +
            ".nativ does provide minimal maintenance or support for it but not to the extent that any maintenance or support is required by applicable law, .nativ, not Apple, shall be obligated to furnish any such maintenance or support." + "\r\n\n" +
            
            "8. Product Claims" + "\r\n" +
            ".nativ, not Apple, is responsible for addressing any claims by you relating to the .nativ App or use of it, including, but not limited to: (i) any product liability claim; (ii) any claim that the .nativ App fails to conform to any applicable legal or regulatory requirement; and (iii) any claim arising under consumer protection or similar legislation. Nothing in this Agreement shall be deemed an admission that you may have such claims." + "\r\n\n" +
            
            "9. Third Party Intellectual Property Claims" + "\r\n" +
    ".nativ shall not be obligated to indemnify or defend you with respect to any third party claim arising out or relating to the .nativ App. To the extent .nativ is required to provide indemnification by applicable law, .nativ, not Apple, shall be solely responsible for the investigation, defense, settlement and discharge of any claim that the .nativ App or your use of it infringes any third party intellectual property right."
}

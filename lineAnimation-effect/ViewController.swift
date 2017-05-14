//
//  ViewController.swift
//  lineAnimation-effect
//
//  Created by JaminZhou on 2017/5/14.
//  Copyright © 2017年 Hangzhou Tomorning Technology Co., Ltd. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var effectView: EffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        effectView.showAnimation()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

}


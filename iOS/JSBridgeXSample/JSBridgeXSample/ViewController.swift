//
//  ViewController.swift
//  JSBridgeXSample
//
//  Created by Xiaohui on 2017/4/10.
//  Copyright © 2017年 TLX. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        button.center = CGPoint(x: UIScreen.main.bounds.width / 2,
                                y: UIScreen.main.bounds.height / 2)
        button.setTitle("OpenURL", for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.backgroundColor = UIColor.blue
        button.addTarget(self, action: #selector(ViewController.onClickOpenURL), for: .touchUpInside)
        self.view.addSubview(button)
    }
    
    func onClickOpenURL() {
        let htmlPath = Bundle.main.path(forResource: "index", ofType: "html")!
        let webViewController = WebViewController(url: URL(fileURLWithPath: htmlPath))
        self.navigationController?.pushViewController(webViewController, animated: true)
    }

}


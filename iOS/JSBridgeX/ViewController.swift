//
//  ViewController.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2016/10/18.
//  Copyright © 2016年 TLX. All rights reserved.
//

import UIKit

class ViewController: UIViewController, WebViewNavigationDelegate {

    private var webView: WebViewProtocol!
    private var usedUIWebView: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if usedUIWebView {
            let webView = UIWebViewEx(frame: self.view.bounds)
            webView.webViewNavigationDelegate = self
            self.view.addSubview(webView)
            self.webView = webView
        } else {
            let webView = WKWebViewEx(frame: self.view.bounds)
            webView.webViewNavigationDelegate = self
            self.view.addSubview(webView)
            self.webView = webView
        }
        
        let height: CGFloat = 40
        let button = UIButton(frame: CGRect(x: 0, y: self.view.bounds.height - height, width: self.view.bounds.width, height: height))
        button.backgroundColor = UIColor.blackColor()
        button.setTitle("Send", forState: .Normal)
        self.view.addSubview(button)
        button.addTarget(self, action: #selector(onClickSend), forControlEvents: .TouchUpInside)
        let htmlPath = NSBundle.mainBundle().pathForResource("index", ofType: "html")!
        print("htmlPath: \(htmlPath)")
        self.webView.loadUrl(NSURL(fileURLWithPath: htmlPath))
        self.webView.registerEvent("Hello") { (data, callback) in
            print("Hello")
            callback?(code: 200, data: ["description": "成功"])
        }
    }
    
    func onClickSend() {
        self.webView.send("SendMessage1", data: ["desc": "hello"]) { (code, data) in
            print("SendMessage callback")
        }
    }
    
//MARK: - WebViewNavigationDelegate
    
    func webView(webView: WebViewProtocol, shouldStartLoadWithRequest request: NSURLRequest) -> Bool {
        return true
    }
    
    func webViewDidStartLoad(webView: WebViewProtocol) {
        
    }
    
    func webViewDidFinishLoad(webView: WebViewProtocol) {
        
    }
    
    func webView(webView: WebViewProtocol, didFailLoadWithError error: NSError) {
        
    }
}


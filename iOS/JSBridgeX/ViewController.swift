//
//  ViewController.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2016/10/18.
//  Copyright © 2016年 TLX. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIWebViewDelegate {

    private var webView: UIWebView!
    private var jsBridge: JSBridgeX!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView = UIWebView(frame: self.view.bounds)
        self.view.addSubview(self.webView)
        jsBridge = JSBridgeX(webView: self.webView, webViewDelegate: self)
        let htmlPath = NSBundle.mainBundle().pathForResource("index", ofType: "html")!
        print("htmlPath: \(htmlPath)")
        do {
            let html = try String(contentsOfFile: htmlPath)
            jsBridge.loadHTMLString(html ?? "", baseURL: nil)
        } catch {
            
        }
        jsBridge.registerEvent("Hello") { (data, callback) in
            print("Hello")
            callback?(code: 200, data: ["description": "成功"])
        }
    }
    
//MARK: - UIWebViewDelegate
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        return true
    }
    
    func webViewDidStartLoad(webView: UIWebView) {
        
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        
    }
}


//
//  WebViewController.swift
//  JSBridgeXSample
//
//  Created by Xiaohui on 2017/5/9.
//  Copyright © 2017年 TLX. All rights reserved.
//

import UIKit
import JSBridgeX

class WebViewController: UIViewController, WebViewNavigationDelegate {
    
    fileprivate var webView: WebViewProtocol!
    fileprivate var innerUrl: URL?
    
    var url: URL? {
        return self.innerUrl
    }
    
    convenience init(url: URL) {
        self.init()
        self.innerUrl = url
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - override
    
    override func loadView() {
        let wkWebView = WKWebViewEx(frame: UIScreen.main.bounds)
        wkWebView.webViewNavigationDelegate = self
        self.webView = wkWebView
        self.view = wkWebView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initBridgeEvents()
        if let url = self.url {
            self.webView.load(url: url)
        }
    }
    
    //MARK: - internal or public
    
    func send(eventName: String, data: [String: Any]?, callback: JSBridgeX.EventCallback?) {
        self.webView.send(eventName: eventName, data: data, callback: callback)
    }
    
    func register(eventName: String, handler: @escaping JSBridgeX.EventHandler) {
        self.webView.registerEvent(eventName: eventName, handler: handler)
    }
    
    func unregister(eventName: String) {
        self.webView.unregisterEvent(eventName: eventName)
    }
    
    func load(url: URL?) {
        self.innerUrl = url
        if let url = url {
            self.webView.load(url: url)
        }
    }
    
    //MARK: - private
    
    fileprivate func initBridgeEvents() {
        register(eventName: "openURL") { [weak self] (data, callback) in
            self?.onEventOpenUrl(with: data, callback: callback)
        }
    }
    
    fileprivate func onEventOpenUrl(with data: Any?, callback: JSBridgeX.EventCallback?) {
        guard let responseData = data as? [String: Any],
            let urlString = responseData["url"] as? String,
            let url = URL(string: urlString) else {
                callback?(JSBridgeX.CODE_INVALID_PARAMETER,
                          ["eventName": "openURL"])
                return
        }
        let rawMode = responseData["mode"] as? Int ?? 0
        let mode = Mode(rawValue: rawMode) ?? .new
        if mode == .new {
            self.navigationController?.pushViewController(WebViewController(url: url), animated: true)
        } else {
            self.load(url: url)
        }
        
        callback?(JSBridgeX.CODE_SUCCESS, nil)
    }
    
    //MARK: - WebViewNavigationDelegate
    
    func webView(webView: WebViewProtocol,
                 shouldStartLoadWithRequest request: URLRequest, navigationType: WebViewNavigationType) -> Bool {
        return true
    }
    
    func webViewDidStartLoad(webView: WebViewProtocol) {
        
    }
    
    func webViewLoadingWithProgress(webView: WebViewProtocol, progress: TimeInterval) {
        
    }
    
    func webViewDidFinishLoad(webView: WebViewProtocol) {
        
    }
    
    func webView(webView: WebViewProtocol, didFailLoadWithError error: Error) {
        
    }
}

enum Mode: Int {
    case new = 0
    case current = 1
}

//
//  UIWebViewEx.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2017/1/20.
//  Copyright © 2017年 TLX. All rights reserved.
//

import UIKit

public class UIWebViewEx: UIWebView, UIWebViewDelegate, WebViewProtocol {
    
    //替代UIWebViewDelegate，用于获取页面加载的生命周期
    public weak var webViewNavigationDelegate: WebViewNavigationDelegate?
    private lazy var bridge: JSBridgeX = {
        return JSBridgeX(webView: self) { (eventName, data, callback) in
            print("undefined eventName: \(eventName)")
            callback?(code: JSBridgeX.CODE_NOT_FOUND, data: nil)
        }
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        delegate = nil
    }
    
    public func setDeaultEventHandler(handler: JSBridgeX.DefaultEventHandler?) {
        self.bridge.defaultEventHandler = handler
    }
    
    //MARK: - UIWebViewDelegate
    
    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if self.bridge.interceptRequest(request) {
            return false
        }
        return self.webViewNavigationDelegate?.webView(self, shouldStartLoadWithRequest: request, navigationType: WebViewNavigationType.from(navigationType)) ?? true
    }
    
    public func webViewDidStartLoad(webView: UIWebView) {
        self.webViewNavigationDelegate?.webViewDidStartLoad(self)
    }
    
    public func webViewDidFinishLoad(webView: UIWebView) {
        self.bridge.injectBridgeToJS()
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: 0.9)
        self.webViewNavigationDelegate?.webViewDidFinishLoad(self)
    }
    
    public func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: 0.9)
        self.webViewNavigationDelegate?.webView(self, didFailLoadWithError: error)
    }
    
    //MARK: - WebViewProtocol
    
    public func loadUrl(url: NSURL) {
        self.loadRequest(NSURLRequest(URL: url))
    }

    public func executeJavaScript(js: String, completionHandler: ((AnyObject?, NSError?) -> Void)?) {
        let result = self.stringByEvaluatingJavaScriptFromString(js)
        completionHandler?(result, nil)
    }
    
    public func send(eventName: String, data: AnyObject?, callback: JSBridgeX.EventCallback?) {
        self.bridge.send(eventName, data: data, callback: callback)
    }
    
    public func registerEvent(eventName: String, handler: JSBridgeX.EventHandler) {
        self.bridge.registerEvent(eventName, handler: handler)
    }
    
    public func unregisterEvent(eventName: String) {
        self.bridge.unregisterEvent(eventName)
    }
}

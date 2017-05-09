//
//  UIWebViewEx.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2017/1/20.
//  Copyright © 2017年 TLX. All rights reserved.
//

import UIKit

open class UIWebViewEx: UIWebView, UIWebViewDelegate, WebViewProtocol {
    
    //替代UIWebViewDelegate，用于获取页面加载的生命周期
    open weak var webViewNavigationDelegate: WebViewNavigationDelegate?
    
    fileprivate lazy var bridge: JSBridgeX = {
        return JSBridgeX(webView: self) { (eventName, data, callback) in
            print("undefined eventName: \(eventName)")
            callback?(JSBridgeX.CODE_NOT_FOUND, nil)
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
        self.delegate = nil
    }

    open func setDeaultEventHandler(handler: JSBridgeX.DefaultEventHandler?) {
        self.bridge.defaultEventHandler = handler
    }
    
    //MARK: - UIWebViewDelegate
    
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if self.bridge.interceptRequest(request: request) {
            return false
        }
        return self.webViewNavigationDelegate?.webView(webView: self, shouldStartLoadWithRequest: request, navigationType: WebViewNavigationType.from(navigationType: navigationType)) ?? true
    }
    
    public func webViewDidStartLoad(_ webView: UIWebView) {
        self.webViewNavigationDelegate?.webViewDidStartLoad(webView: self)
    }
    
    public func webViewDidFinishLoad(_ webView: UIWebView) {
        self.bridge.injectBridgeToJS()
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: 0.9)
        self.webViewNavigationDelegate?.webViewDidFinishLoad(webView: self)
    }
    
    public func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: 0.9)
        self.webViewNavigationDelegate?.webView(webView: self, didFailLoadWithError: error)
    }
    
    //MARK: - WebViewProtocol
    
    open func loadUrl(url: URL) {
        self.loadRequest(URLRequest(url: url))
    }
    
    open func executeJavaScript(js: String, completionHandler: ((Any?, Error?) -> Void)?) {
        let result = self.stringByEvaluatingJavaScript(from: js)
        completionHandler?(result, nil)
    }
    
    open func send(eventName: String, data: Any?, callback: JSBridgeX.EventCallback?) {
        self.bridge.send(eventName: eventName, data: data, callback: callback)
    }
    
    open func registerEvent(eventName: String, handler: @escaping JSBridgeX.EventHandler) {
        self.bridge.registerEvent(eventName: eventName, handler: handler)
    }
    
    open func unregisterEvent(eventName: String) {
        self.bridge.unregisterEvent(eventName: eventName)
    }
}

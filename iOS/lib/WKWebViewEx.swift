//
//  WKWebViewEx.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2017/1/20.
//  Copyright © 2017年 TLX. All rights reserved.
//

import WebKit

open class WKWebViewEx: WKWebView, WebViewProtocol, WKNavigationDelegate {
    
    //    fileprivate let context = UnsafeMutableRawPointer.allocate(capacity: 1)
    fileprivate let kEstimatedProgress = "estimatedProgress"
    
    //替代WKNavigationDelegate，用于获取页面加载的生命周期
    open weak var webViewNavigationDelegate: WebViewNavigationDelegate?
    fileprivate lazy var bridge: JSBridgeX = {
        return JSBridgeX(webView: self) { (eventName, data, callback) in
            print("undefined eventName: \(eventName)")
            callback?(JSBridgeX.CODE_NOT_FOUND, nil)
        }
    }()
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        self.navigationDelegate = self
        self.addObserver(self, forKeyPath: self.kEstimatedProgress, options: .new, context: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.navigationDelegate = nil
        self.removeObserver(self, forKeyPath: self.kEstimatedProgress, context: nil)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == self.kEstimatedProgress {
            self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: self.estimatedProgress)
        }
    }
    
    open func setDeaultEventHandler(handler: JSBridgeX.DefaultEventHandler?) {
        self.bridge.defaultEventHandler = handler
    }
    
    //MARK: - WKNavigationDelegate
    
    @nonobjc open func webView(webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        if self.bridge.interceptRequest(request: request) {
            decisionHandler(.cancel)
            return
        }
        
        if let result = self.webViewNavigationDelegate?.webView(webView: self, shouldStartLoadWithRequest: request, navigationType: WebViewNavigationType.from(navigationType: navigationAction.navigationType)) {
            decisionHandler(result ? .allow : .cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    //    public func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
    //        decisionHandler(.Allow)
    //    }
    
    @nonobjc open func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.webViewNavigationDelegate?.webViewDidStartLoad(webView: self)
        
    }
    //
    //    public func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    //
    //    }
    
    @nonobjc open func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: 1)
        self.webViewNavigationDelegate?.webView(webView: self, didFailLoadWithError: error)
    }
    
    @nonobjc open func webView(webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.bridge.injectBridgeToJS()
    }
    
    @nonobjc open func webView(webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: 1)
        self.webViewNavigationDelegate?.webViewDidFinishLoad(webView: self)
    }
    
    @nonobjc open func webView(webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(webView: self, progress: 1)
        self.webViewNavigationDelegate?.webView(webView: self, didFailLoadWithError: error)
    }
    
    //MARK: - WebViewProtocol
    
    open func loadUrl(url: URL) {
        self.load(URLRequest(url: url))
    }
    
    open func executeJavaScript(js: String, completionHandler: ((Any?, Error?) -> Void)?) {
        self.evaluateJavaScript(js, completionHandler: completionHandler)
    }
    
    open func send(eventName: String, data: AnyObject?, callback: JSBridgeX.EventCallback?) {
        self.bridge.send(eventName: eventName, data: data, callback: callback)
    }
    
    open func registerEvent(eventName: String, handler: @escaping JSBridgeX.EventHandler) {
        self.bridge.registerEvent(eventName: eventName, handler: handler)
    }
    
    open func unregisterEvent(eventName: String) {
        self.bridge.unregisterEvent(eventName: eventName)
    }
    
}

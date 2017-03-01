//
//  WKWebViewEx.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2017/1/20.
//  Copyright © 2017年 TLX. All rights reserved.
//

import WebKit

public class WKWebViewEx: WKWebView, WebViewProtocol, WKNavigationDelegate {
    
    //替代WKNavigationDelegate，用于获取页面加载的生命周期
    public weak var webViewNavigationDelegate: WebViewNavigationDelegate?
    private lazy var bridge: JSBridgeX = {
        return JSBridgeX(webView: self) { (eventName, data, callback) in
            print("undefined eventName: \(eventName)")
            callback?(code: JSBridgeX.CODE_NOT_FOUND, data: nil)
        }
    }()
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        self.navigationDelegate = self
        self.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "estimatedProgress" {
            self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: self.estimatedProgress)
        }
    }
    
    public func setDeaultEventHandler(handler: JSBridgeX.DefaultEventHandler?) {
        self.bridge.defaultEventHandler = handler
    }
    
    //MARK: - WKNavigationDelegate
    
    public func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        if self.bridge.interceptRequest(request) {
            decisionHandler(.Cancel)
            return
        }
        
        if let result = self.webViewNavigationDelegate?.webView(self, shouldStartLoadWithRequest: request) {
            decisionHandler(result ? .Allow : .Cancel)
            return
        }
        decisionHandler(.Allow)
    }
    
//    public func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
//        decisionHandler(.Allow)
//    }
    
    public func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.webViewNavigationDelegate?.webViewDidStartLoad(self)
        
    }
//    
//    public func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
//        
//    }
    
    public func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: 1)
        self.webViewNavigationDelegate?.webView(self, didFailLoadWithError: error)
    }
    
    public func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        self.bridge.injectBridgeToJS()
    }
    
    public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: 1)
        self.webViewNavigationDelegate?.webViewDidFinishLoad(self)
    }
    
    public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        self.webViewNavigationDelegate?.webViewLoadingWithProgress(self, progress: 1)
        self.webViewNavigationDelegate?.webView(self, didFailLoadWithError: error)
    }

    //MARK: - WebViewProtocol
    
    public func loadUrl(url: NSURL) {
        self.loadRequest(NSURLRequest(URL: url))
    }
    
    public func executeJavaScript(js: String, completionHandler: ((AnyObject?, NSError?) -> Void)?) {
        self.evaluateJavaScript(js, completionHandler: completionHandler)
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

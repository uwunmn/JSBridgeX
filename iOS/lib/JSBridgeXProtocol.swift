//
//  JSBridgeXProtocol.swift
//  Pods
//
//  Created by Xiaohui on 2017/5/9.
//
//

import Foundation

public protocol WebViewProtocol: class {
    var canBack: Bool { get }
    var canForward: Bool { get }
    func back()
    func forward()
    func load(url: URL)
    func executeJavaScript(js: String, completionHandler: ((Any?, Error?) -> Void)?)
    func registerEvent(eventName: String, handler:  @escaping JSBridgeX.EventHandler)
    func unregisterEvent(eventName: String)
    func send(eventName: String, data: Any?, callback: JSBridgeX.EventCallback?)
}

public protocol WebViewNavigationDelegate: class {
    func webView(webView: WebViewProtocol, shouldStartLoadWithRequest request: URLRequest, navigationType: WebViewNavigationType) -> Bool
    func webViewDidStartLoad(webView: WebViewProtocol)
    func webViewDidFinishLoad(webView: WebViewProtocol)
    func webViewLoadingWithProgress(webView: WebViewProtocol, progress: TimeInterval)
    func webView(webView: WebViewProtocol, didFailLoadWithError error: Error)
}

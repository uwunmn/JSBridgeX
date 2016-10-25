//
//  JSBridgeX.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2016/10/18.
//  Copyright © 2016年 TLX. All rights reserved.
//

import UIKit



public class JSBridgeX: NSObject, UIWebViewDelegate {
 
    public typealias EventCallback = (code: Int, data: [String: AnyObject]?) -> Void
    public typealias EventHandler = (data: [String: AnyObject]?, callback: EventCallback?) -> Void
    public typealias Message = [String: AnyObject]
    
    public static let CODE_SUCCESS = 200
    public static let CODE_NOT_FOUND = 404
    public static let CODE_INVALID_PARAMETER = 403
    public static let CODE_BAD_BRIDGE = 503
    
    private let JBX_SCHEME = "torlaxbridge"
    private let JBX_HOST = "__TORLAX_HOST__"
    private let JBX_PATH = "/__TORLAX_EVENT__"
    
    private let JBX_JS_OBJECT = "JSBridge"
    private let JBX_JS_METHOD_FETCH_MESSAGE_QUEUE = "fetchMessageQueue"
    private let JBX_JS_METHOD_POST_MESSAGE_TO_JS = "dispatchMessageFromNative"
    
    private let JBX_METHOD_SEND = "SEND"
    private let JBX_METHOD_CALLBACK = "CALLBACK"
    
    private let JBX_KEY_METHOD = "method"
    private let JBX_KEY_EVENT_NAME = "eventName"
    private let JBX_KEY_DATA = "data"
    private let JBX_KEY_CODE = "code"
    private let JBX_KEY_CALLBACK_ID = "callbackId"
    private let JBX_KEY_DESCRIPTION = "description"
    
    private let webView: UIWebView
    private weak var webViewDelegate: UIWebViewDelegate?
    private var injectedJS: String = ""
    private var eventMap: [String: EventHandler] = [: ]
    private var eventCallbacks: [String: EventCallback] = [: ]
    private var postMessageQueue: [Message]! = []
    private var eventUniqueId = 0
    
    public init(webView: UIWebView, webViewDelegate: UIWebViewDelegate?) {
        self.webView = webView
        self.webViewDelegate = webViewDelegate
        super.init()
        self.webView.delegate = self
        self.injectedJS = self.loadInjectedJS()
    }
    
    deinit {
        self.webViewDelegate = nil
        self.webView.delegate = nil
    }
    
    //MARK: - internal property
    
    public func loadURL(url: NSURL) {
        self.webView.loadRequest(NSURLRequest(URL: url))
    }
    
    public func loadHTMLString(string: String, baseURL: NSURL?) {
        self.webView.loadHTMLString(string, baseURL: baseURL)
    }
    
    public func registerEvent(eventName: String, handler: EventHandler) {
        eventMap[eventName] = handler
    }
    
    public func unregisterEvent(eventName: String) {
        eventMap.removeValueForKey(eventName)
    }
    
    public func send(eventName: String, data: [String: AnyObject]?, callback: EventCallback?) {
        var message = [String: AnyObject]()
        message[JBX_KEY_METHOD] = JBX_METHOD_SEND
        message[JBX_KEY_EVENT_NAME] = eventName
        message[JBX_KEY_DATA] = data
        if callback != nil {
            eventUniqueId += 1
            let callbackId = "ios_cb_\(eventUniqueId)"
            message[JBX_KEY_CALLBACK_ID] = callbackId
            eventCallbacks[callbackId] = callback
        }
        postMessage(message)
    }
    
    //MARK: - private
    
    private func callback(code: Int, callbackId: String, data: [String: AnyObject]?) {
        var message = [String: AnyObject]()
        message[JBX_KEY_METHOD] = JBX_METHOD_CALLBACK
        message[JBX_KEY_CODE] = code
        message[JBX_KEY_CALLBACK_ID] = callbackId
        message[JBX_KEY_DATA] = data
        postMessage(message)
    }
    
    private func loadInjectedJS() -> String {
        let resourceBundle = NSBundle(forClass: JSBridgeX.self)
        if let url = resourceBundle.URLForResource("JSBridgeX", withExtension: "bundle"),
            let bundle = NSBundle(URL: url),
            let jsFilePath = bundle.pathForResource("JSBridge", ofType: "js"),
            let jsString = try? String(contentsOfFile: jsFilePath) {
            return jsString
        }
        return ""
    }
    
    private func dispatchMessageQueueFromJS() -> Bool {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_FETCH_MESSAGE_QUEUE)()"
        if let messageString = self.webView.stringByEvaluatingJavaScriptFromString(jsMethod),
            let messageData = messageString.dataUsingEncoding(NSUTF8StringEncoding) {
            let messages = parseMessageQueue(messageData)
            for message in messages {
                let method = message[JBX_KEY_METHOD] as? String
                if let method = method {
                    if method == JBX_METHOD_SEND {
                        handleMessageSentFromJS(message)
                    } else if method == JBX_METHOD_CALLBACK {
                        handleMessageCallbackFromJS(message)
                    }
                }
            }
            return false
        }
        return true
    }
    
    private func parseMessageQueue(data: NSData) -> [Message] {
        return ((try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)) as? [Message]) ?? []
    }
    
    private func stringifyMessage(message: Message) -> String {
        do {
            return try String(data: NSJSONSerialization.dataWithJSONObject(message, options: NSJSONWritingOptions(rawValue: 0)), encoding: NSUTF8StringEncoding) ?? ""
        } catch {
            
        }
        return ""
    }
    
    private func handleMessageSentFromJS(message: Message) {
        let callbackId = message[JBX_KEY_CALLBACK_ID] as? String
        let eventName = message[JBX_KEY_EVENT_NAME] as? String
        var callbackBlock: EventCallback? = nil
        if callbackId != nil {
            callbackBlock = { [weak self] (code: Int, data: [String: AnyObject]?) in
                if let weakSelf = self {
                    weakSelf.callback(code, callbackId: callbackId!, data: data)
                }
            }
        }
        if let eventName = eventName, let eventHandler = eventMap[eventName] {
            let data = message[JBX_KEY_DATA] as? [String: AnyObject]
            eventHandler(data: data, callback: callbackBlock)
            return
        }
        callbackBlock?(code: JSBridgeX.CODE_NOT_FOUND, data: nil)
    }
    
    private func handleMessageCallbackFromJS(message: Message) {
        if let callbackId = message[JBX_KEY_CALLBACK_ID] as? String,
            let eventCallback = eventCallbacks[callbackId] {
            if let code = message[JBX_KEY_CODE] as? Int {
                eventCallback(code: code,
                              data: message[JBX_KEY_DATA] as? [String: AnyObject])
            } else {
                eventCallback(code: JSBridgeX.CODE_INVALID_PARAMETER, data: nil)
            }
        }
    }
    
    private func postMessage(message: Message) {
        if postMessageQueue != nil {
            postMessageQueue!.append(message)
        } else {
            postMessageToJS(message)
        }
    }
    
    private func postMessageToJS(message: Message) {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_POST_MESSAGE_TO_JS)(\(stringifyMessage(message)))"
        self.webView.stringByEvaluatingJavaScriptFromString(jsMethod)
    }
    
    //MARK: - UIWebViewDelegate
    
    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        if webView != self.webView {
            return true
        }
        
        let url = request.URL
        if let scheme = url?.scheme where scheme == JBX_SCHEME {
            if let host = url?.host where host == JBX_HOST {
                print(url?.relativePath)
                if let path = url?.relativePath where path == JBX_PATH {
                    self.dispatchMessageQueueFromJS()
                }
            }
            return false
        } else {
            if let delegate = webViewDelegate {
                return delegate.webView?(webView, shouldStartLoadWithRequest: request, navigationType: navigationType) ?? true
            }
        }
        return true
    }
    
    public func webViewDidStartLoad(webView: UIWebView) {
        if webView != self.webView {
            return
        }
        if let delegate = webViewDelegate {
            delegate.webViewDidStartLoad?(webView)
        }
    }
    
    public func webViewDidFinishLoad(webView: UIWebView) {
        if webView != self.webView {
            return
        }
        
        if webView.stringByEvaluatingJavaScriptFromString("typeof \(JBX_JS_OBJECT) == 'object'") != "true" {
            webView.stringByEvaluatingJavaScriptFromString(self.injectedJS)
        }
        
        if let messages = postMessageQueue {
            for message in messages {
                postMessageToJS(message)
            }
            postMessageQueue = nil
        }
        if let delegate = webViewDelegate {
            delegate.webViewDidFinishLoad?(webView)
        }
    }
    
    public func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if webView != self.webView {
            return
        }
        if let delegate = webViewDelegate {
            delegate.webView?(webView, didFailLoadWithError: error)
        }
    }
    
}

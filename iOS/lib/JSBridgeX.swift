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
    public typealias DefaultEventHandler = (eventName: String, data: [String: AnyObject]?, callback: EventCallback?) -> Void
    
    public static let CODE_SUCCESS = 200
    public static let CODE_NOT_FOUND = 404
    public static let CODE_INVALID_PARAMETER = 403
    public static let CODE_BAD_BRIDGE = 503
    
    private let JBX_SCHEME = "jsbridgex"
    private let JBX_HOST = "__JBX_HOST__"
    private let JBX_PATH = "/__JBX_EVENT__"
    
    private let JBX_JS_OBJECT = "JSBridge"
    private let JBX_JS_METHOD_FETCH_MESSAGE_QUEUE = "fetchMessageQueue"
    private let JBX_JS_METHOD_POST_MESSAGE_TO_JS = "dispatchMessageFromNative"
    
    private let JBX_METHOD_SEND = "SEND"
    private let JBX_METHOD_CALLBACK = "CALLBACK"
    
    private weak var webView: UIWebView?
    private weak var webViewDelegate: UIWebViewDelegate?
    private var injectedJS: String = ""
    private var eventMap: [String: EventHandler] = [: ]
    private var eventCallbacks: [String: EventCallback] = [: ]
    private var postMessageQueue: [Message]! = []
    private var eventUniqueId = 0
    private let defaultMessageHandler: DefaultEventHandler?
    
    public init(webView: UIWebView, webViewDelegate: UIWebViewDelegate?, defaultMessageHandler: DefaultEventHandler?) {
        self.webView = webView
        self.webViewDelegate = webViewDelegate
        self.defaultMessageHandler = defaultMessageHandler
        super.init()
        self.webView?.delegate = self
        self.injectedJS = self.loadInjectedJS()
        registerEvent("listAllEvents") { (data, callback) in
            let events = [String](self.eventMap.keys)
            callback?(code: JSBridgeX.CODE_SUCCESS, data: ["Events": events])
        }
    }
    
    deinit {
        self.webViewDelegate = nil
        self.webView?.delegate = nil
    }
    
    //MARK: - internal property
    
    public func loadURL(url: NSURL) {
        self.webView?.loadRequest(NSURLRequest(URL: url))
    }
    
    public func loadHTMLString(string: String, baseURL: NSURL?) {
        self.webView?.loadHTMLString(string, baseURL: baseURL)
    }
    
    public func registerEvent(eventName: String, handler: EventHandler) {
        eventMap[eventName] = handler
    }
    
    public func unregisterEvent(eventName: String) {
        eventMap.removeValueForKey(eventName)
    }
    
    public func send(eventName: String, data: [String: AnyObject]?, callback: EventCallback?) {
        let message = Message(method: JBX_METHOD_SEND)
        message.eventName = eventName
        message.data = data
        if callback != nil {
            eventUniqueId += 1
            let callbackId = "ios_cb_\(eventUniqueId)"
            message.callbackId = callbackId
            eventCallbacks[callbackId] = callback
        }
        postMessage(message)
    }
    
    //MARK: - private
    
    private func callback(code: Int, callbackId: String, data: [String: AnyObject]?) {
        let message = Message(method: JBX_METHOD_CALLBACK)
        message.code = code
        message.callbackId = callbackId
        message.data = data
        postMessage(message)
    }
    
    private func loadInjectedJS() -> String {
        let resourceBundle = NSBundle(forClass: JSBridgeX.self)
        var bundle = NSBundle.mainBundle()
        if let url = resourceBundle.URLForResource("JSBridgeX", withExtension: "bundle") {
            bundle = NSBundle(URL: url) ?? bundle
        }
        if let jsFilePath = bundle.pathForResource("JSBridge", ofType: "js") {
            do {
                return try String(contentsOfFile: jsFilePath)
            } catch {
            
            }
        }
        return ""
    }
    
    private func dispatchMessageQueueFromJS() -> Bool {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_FETCH_MESSAGE_QUEUE)()"
        if let messageString = self.webView?.stringByEvaluatingJavaScriptFromString(jsMethod),
            let messageData = messageString.dataUsingEncoding(NSUTF8StringEncoding) {
            log("dispatchMessageQueueFromJS:\(messageString)")
            let rawMessages = parseMessageQueue(messageData)
            for rawMessage in rawMessages {
                if let message = Message(rawDict: rawMessage) {
                    if message.method == JBX_METHOD_SEND {
                        handleMessageSentFromJS(message)
                    } else if message.method == JBX_METHOD_CALLBACK {
                        handleMessageCallbackFromJS(message)
                    }
                }
            }
            return false
        }
        return true
    }
    
    private func parseMessageQueue(data: NSData) -> [[String: AnyObject]] {
        do {
            if let messages = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [[String: AnyObject]] {
                return messages
            }
        } catch {
            
        }
        return []
    }
    
    private func handleMessageSentFromJS(message: Message) {
        let callbackId = message.callbackId
        let eventName = message.eventName
        var callbackBlock: EventCallback?
        if callbackId != nil {
            callbackBlock = { [weak self] (code: Int, data: [String: AnyObject]?) in
                if let weakSelf = self {
                    weakSelf.callback(code, callbackId: callbackId!, data: data)
                }
            }
        }
        if let eventName = eventName {
            if let eventHandler = eventMap[eventName] {
                eventHandler(data: message.data, callback: callbackBlock)
            } else {
                defaultMessageHandler?(eventName: eventName, data: message.data, callback: callbackBlock)
            }
            return
        }
        callbackBlock?(code: JSBridgeX.CODE_INVALID_PARAMETER, data: nil)
    }
    
    private func handleMessageCallbackFromJS(message: Message) {
        if let callbackId = message.callbackId,
            let eventCallback = eventCallbacks[callbackId] {
            if let code = message.code {
                eventCallback(code: code, data: message.data)
            } else {
                eventCallback(code: JSBridgeX.CODE_INVALID_PARAMETER, data: nil)
            }
        }
    }
    
    private func postMessage(message: Message) {
        log("postMessage:\(message.toString())")
        if postMessageQueue != nil {
            postMessageQueue!.append(message)
        } else {
            postMessageToJS(message)
        }
    }
    
    private func postMessageToJS(message: Message) {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_POST_MESSAGE_TO_JS)(\(message.toString()))"
        self.webView?.stringByEvaluatingJavaScriptFromString(jsMethod)
    }
    
    private func log(items: Any..., separator: String = " ", terminator: String = "\n", file: NSString = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        let message = items.map({ String($0) }).joinWithSeparator(separator)
        let dateFormater = NSDateFormatter()
        dateFormater.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let date = dateFormater.stringFromDate(NSDate())
        let result = "JSX|\(date) [\(line)]: \(message)"
        print(result, separator: "", terminator: "\n")
    }

    //MARK: - UIWebViewDelegate
    
    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        if webView != self.webView {
            return true
        }
        
        let url = request.URL
        if let scheme = url?.scheme where scheme == JBX_SCHEME {
            if let host = url?.host where host == JBX_HOST {
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
        self.webViewDelegate?.webViewDidStartLoad?(webView)
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
        self.webViewDelegate?.webViewDidFinishLoad?(webView)
    }
    
    public func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if webView != self.webView {
            return
        }
        self.webViewDelegate?.webView?(webView, didFailLoadWithError: error)
    }
}

private let JBX_KEY_METHOD = "method"
private let JBX_KEY_EVENT_NAME = "eventName"
private let JBX_KEY_DATA = "data"
private let JBX_KEY_CODE = "code"
private let JBX_KEY_CALLBACK_ID = "callbackId"

public class Message {
    
    public var method: String {
        didSet {
            self.dict[JBX_KEY_METHOD] = self.method
        }
    }
    public var eventName: String? {
        didSet {
            self.dict[JBX_KEY_EVENT_NAME] = self.eventName
        }
    }
    public var code: Int? {
        didSet {
            self.dict[JBX_KEY_CODE] = self.code
        }
    }
    public var data: [String: AnyObject]? {
        didSet {
            self.dict[JBX_KEY_DATA] = self.data
        }
    }
    public var callbackId: String? {
        didSet {
            self.dict[JBX_KEY_CALLBACK_ID] = self.callbackId
        }
    }
    private var dict: [String: AnyObject] = [:]
    
    public init(method: String) {
        self.method = method
        self.dict[JBX_KEY_METHOD] = method
    }
    
    public init?(rawDict: [String: AnyObject]) {
        if let method = rawDict[JBX_KEY_METHOD] as? String  {
            self.method = method
            self.eventName = rawDict[JBX_KEY_EVENT_NAME] as? String
            self.code = rawDict[JBX_KEY_CODE] as? Int
            self.data = rawDict[JBX_KEY_DATA] as? [String: AnyObject]
            self.callbackId = rawDict[JBX_KEY_CALLBACK_ID] as? String
            dict = rawDict
            return
        }
        
        return nil
    }
    
    public func toString() -> String {
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(self.dict, options: NSJSONWritingOptions(rawValue: 0))
            return String(data: data, encoding: NSUTF8StringEncoding) ?? ""
        } catch {
            
        }
        return ""
    }
}

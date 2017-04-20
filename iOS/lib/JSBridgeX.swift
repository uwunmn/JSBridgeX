//
//  JSBridgeX.swift
//  JSBridgeX
//
//  Created by Xiaohui on 2016/10/18.
//  Copyright © 2016年 TLX. All rights reserved.
//

import UIKit
import WebKit

public class JSBridgeX: NSObject {

    public typealias EventCallback = (code: Int, data: AnyObject?) -> Void
    public typealias EventHandler = (data: AnyObject?, callback: EventCallback?) -> Void
    public typealias DefaultEventHandler = (eventName: String, data: AnyObject?, callback: EventCallback?) -> Void
    public typealias LogCallback = (message: String, file: NSString, line: Int, column: Int, function: String) -> Void
    
    public static let CODE_SUCCESS = 200
    public static let CODE_NOT_FOUND = 404
    public static let CODE_INVALID_PARAMETER = 403
    public static let CODE_INTERNAL_ERROR = 405
    
    public static var LogClosure: LogCallback?

    private let JBX_SCHEME = "jsbridgex"
    private let JBX_HOST = "__JBX_HOST__"
    private let JBX_PATH = "/__JBX_EVENT__"
    private let JBX_JS_OBJECT = "JSBridge"
    private let JBX_JS_METHOD_FETCH_MESSAGE_QUEUE = "fetchMessageQueue"
    private let JBX_JS_METHOD_POST_MESSAGE_TO_JS = "dispatchMessageFromNative"
    
    private let JBX_METHOD_SEND = "SEND"
    private let JBX_METHOD_CALLBACK = "CALLBACK"
    
    private weak var webView: WebViewProtocol?
    private var injectedJS: String = ""
    private var eventMap: [String: EventHandler] = [: ]
    private var eventCallbacks: [String: EventCallback] = [: ]
    private var postMessageQueue: [Message]! = []
    private var eventUniqueId = 0
    public var defaultEventHandler: DefaultEventHandler?
    
    public init(webView: WebViewProtocol, defaultEventHandler: DefaultEventHandler?) {
        self.webView = webView
        self.defaultEventHandler = defaultEventHandler
        super.init()
        self.injectedJS = self.loadInjectedJS()
//        registerEvent("listAllEvents") { (data, callback) in
//            let events = [String](self.eventMap.keys)
//            callback?(code: JSBridgeX.CODE_SUCCESS, data: ["Events": events])
//        }
    }
    
    deinit {
        log("JSBridgeX, deinit")
        self.webView = nil
    }
    
    //MARK: - internal property
    
    public func loadURL(url: NSURL) {
        self.webView?.loadUrl(url)
    }
    
    public func registerEvent(eventName: String, handler: EventHandler) {
        eventMap[eventName] = handler
    }
    
    public func unregisterEvent(eventName: String) {
        eventMap.removeValueForKey(eventName)
    }
    
    public func send(eventName: String, data: AnyObject?, callback: EventCallback?) {
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
    
    public func interceptRequest(request: NSURLRequest) -> Bool {
        let url = request.URL
        if let scheme = url?.scheme where scheme == JBX_SCHEME {
            if let host = url?.host where host == JBX_HOST {
                if let path = url?.relativePath where path == JBX_PATH {
                    self.dispatchMessageQueueFromJS()
                }
            }
            return true
        }
        return false
    }
    
    public func injectBridgeToJS() {
        self.webView?.executeJavaScript("typeof \(JBX_JS_OBJECT) == 'object'") { [weak self] (object, error) in
            let result = (object as? String) ?? "false"
            if result == "false" {
                self?.webView?.executeJavaScript((self?.injectedJS)!, completionHandler: nil)
                if let messages = self?.postMessageQueue {
                    for message in messages {
                        self?.postMessageToJS(message)
                    }
                    self?.postMessageQueue = nil
                }
            }
        }
    }
    
    //MARK: - private
    
    private func callback(code: Int, callbackId: String, data: AnyObject?) {
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
    
    private func dispatchMessageQueueFromJS(){
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_FETCH_MESSAGE_QUEUE)()"
        self.webView?.executeJavaScript(jsMethod) { [weak self] (object, error) in
            if let messageString = object as? String {
                self?.handleMessageQueueFromJS(messageString)
            }
        }
    }
    
    private func handleMessageQueueFromJS(messageString: String) {
        if let messageData = messageString.dataUsingEncoding(NSUTF8StringEncoding) {
            self.log("dispatchMessageQueueFromJS:", messageString)
            let messages = self.parseMessageQueue(messageData)
            for message in messages {
                if message.method == JBX_METHOD_SEND {
                    self.handleMessageSentFromJS(message)
                } else if message.method == JBX_METHOD_CALLBACK {
                    self.handleMessageCallbackFromJS(message)
                }
            }
        }
    }
    
    private func parseMessageQueue(data: NSData) -> [Message] {
        do {
            if let messages = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [[String: AnyObject]] {
                return messages.flatMap({ (dict) -> Message? in
                    return Message(rawDict: dict)
                })
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
            callbackBlock = { [weak self] (code: Int, data: AnyObject?) in
                self?.callback(code, callbackId: callbackId!, data: data)
            }
        }
        if let eventName = eventName {
            if let eventHandler = eventMap[eventName] {
                eventHandler(data: message.data, callback: callbackBlock)
            } else {
                defaultEventHandler?(eventName: eventName, data: message.data, callback: callbackBlock)
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
        log("postMessage:", message.description)
        if postMessageQueue != nil {
            postMessageQueue!.append(message)
        } else {
            postMessageToJS(message)
        }
    }
    
    private func postMessageToJS(message: Message) {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_POST_MESSAGE_TO_JS)(\(message.toString()))"
        self.webView?.executeJavaScript(jsMethod, completionHandler: nil)
    }
    
    private func log(items: Any..., separator: String = " ", terminator: String = "\n", file: NSString = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        let message = items.map({ String($0) }).joinWithSeparator(separator)
        if let logClosure = JSBridgeX.LogClosure {
            logClosure(message: message, file: file, line: line, column: column, function: function)
        } else {
            let dateFormater = NSDateFormatter()
            dateFormater.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let date = dateFormater.stringFromDate(NSDate())
            let result = "JSX|\(date) [\(line)]: \(message)"
            print(result, separator: "", terminator: "\n")
        }
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
    public var data: AnyObject? {
        didSet {
            self.dict[JBX_KEY_DATA] = self.data
        }
    }
    public var callbackId: String? {
        didSet {
            self.dict[JBX_KEY_CALLBACK_ID] = self.callbackId
        }
    }
    
    public var description: String {
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(self.dict, options: .PrettyPrinted)
            return String(data: data, encoding: NSUTF8StringEncoding) ?? ""
        } catch {
            
        }
        return ""
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
            self.data = rawDict[JBX_KEY_DATA]
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

public enum WebViewNavigationType : Int {
    case LinkActivated
    case FormSubmitted
    case BackForward
    case Reload
    case FormResubmitted
    case Other
    
    static func from(navigationType: WKNavigationType) -> WebViewNavigationType {
        switch navigationType {
        case .LinkActivated:
            return .LinkActivated
        case .FormSubmitted:
            return .FormSubmitted
        case .BackForward:
            return .BackForward
        case .Reload:
            return .Reload
        case .FormResubmitted:
            return .FormResubmitted
        case .Other:
            return .Other
        }
    }
    
    static func from(navigationType: UIWebViewNavigationType) -> WebViewNavigationType {
        switch navigationType {
        case .LinkClicked:
            return .LinkActivated
        case .FormSubmitted:
            return .FormSubmitted
        case .BackForward:
            return .BackForward
        case .Reload:
            return .Reload
        case .FormResubmitted:
            return .FormResubmitted
        case .Other:
            return .Other
        }
    }
}

public protocol WebViewProtocol: class {
    func loadUrl(url: NSURL)
    func executeJavaScript(js: String, completionHandler: ((AnyObject?, NSError?) -> Void)?)
    func registerEvent(eventName: String, handler: JSBridgeX.EventHandler)
    func unregisterEvent(eventName: String)
    func send(eventName: String, data: AnyObject?, callback: JSBridgeX.EventCallback?)
}

public protocol WebViewNavigationDelegate: class {
    func webView(webView: WebViewProtocol, shouldStartLoadWithRequest request: NSURLRequest, navigationType: WebViewNavigationType) -> Bool
    func webViewDidStartLoad(webView: WebViewProtocol)
    func webViewDidFinishLoad(webView: WebViewProtocol)
    func webViewLoadingWithProgress(webView: WebViewProtocol, progress: NSTimeInterval)
    func webView(webView: WebViewProtocol, didFailLoadWithError error: NSError)
}

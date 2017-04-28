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
    
    public typealias EventCallback = (_ code: Int, _ data: Any?) -> Void
    public typealias EventHandler = (_ data: Any?, _ callback: EventCallback?) -> Void
    public typealias DefaultEventHandler = (_ eventName: String, _ data: Any?, _ callback: EventCallback?) -> Void
    public typealias LogCallback = (_ message: String, _ file: NSString, _ line: Int, _ column: Int, _ function: String) -> Void
    
    public static let CODE_SUCCESS = 200
    public static let CODE_INVALID_PARAMETER = 403
    public static let CODE_NOT_FOUND = 404
    public static let CODE_INTERNAL_ERROR = 405
    
    public static var LogClosure: LogCallback?
    
    fileprivate let JBX_SCHEME = "jsbridgex"
    fileprivate let JBX_HOST = "__JBX_HOST__"
    fileprivate let JBX_PATH = "/__JBX_EVENT__"
    fileprivate let JBX_JS_OBJECT = "JSBridge"
    fileprivate let JBX_JS_METHOD_FETCH_MESSAGE_QUEUE = "fetchMessageQueue"
    fileprivate let JBX_JS_METHOD_POST_MESSAGE_TO_JS = "dispatchMessageFromNative"
    
    fileprivate let JBX_METHOD_SEND = "SEND"
    fileprivate let JBX_METHOD_CALLBACK = "CALLBACK"
    
    fileprivate weak var webView: WebViewProtocol?
    fileprivate var injectedJS: String = ""
    fileprivate var eventMap: [String: EventHandler] = [: ]
    fileprivate var eventCallbacks: [String: EventCallback] = [: ]
    fileprivate var postMessageQueue: [Message]! = []
    fileprivate var eventUniqueId = 0
    public var defaultEventHandler: DefaultEventHandler?
    
    public init(webView: WebViewProtocol, defaultEventHandler: DefaultEventHandler?) {
        self.webView = webView
        self.defaultEventHandler = defaultEventHandler
        super.init()
        self.injectedJS = self.loadInjectedJS()
    }
    
    deinit {
        self.webView = nil
    }
    
    //MARK: - internal property
    
    public func loadURL(url: URL) {
        self.webView?.loadUrl(url: url)
    }
    
    public func registerEvent(eventName: String, handler: @escaping EventHandler) {
        self.eventMap[eventName] = handler
    }
    
    public func unregisterEvent(eventName: String) {
        self.eventMap.removeValue(forKey: eventName)
    }
    
    public func send(eventName: String, data: Any?, callback: EventCallback?) {
        let message = Message(method: JBX_METHOD_SEND)
        message.eventName = eventName
        message.data = data
        if callback != nil {
            self.eventUniqueId += 1
            let callbackId = "ios_cb_\(self.eventUniqueId)"
            message.callbackId = callbackId
            self.eventCallbacks[callbackId] = callback
        }
        self.postMessage(message: message)
    }
    
    public func interceptRequest(request: URLRequest) -> Bool {
        let url = request.url
        if let scheme = url?.scheme, scheme == JBX_SCHEME {
            if let host = url?.host, host == JBX_HOST {
                if let path = url?.relativePath, path == JBX_PATH {
                    self.dispatchMessageQueueFromJS()
                }
            }
            return true
        }
        return false
    }
    
    public func injectBridgeToJS() {
        self.webView?.executeJavaScript(js: "typeof \(JBX_JS_OBJECT) == 'object'") { [weak self] (object, error) in
            let result = (object as? String) ?? "false"
            if result == "false" {
                self?.webView?.executeJavaScript(js: (self?.injectedJS)!, completionHandler: nil)
                if let messages = self?.postMessageQueue {
                    for message in messages {
                        self?.postMessageToJS(message: message)
                    }
                    self?.postMessageQueue = nil
                }
            }
        }
    }
    
    //MARK: - private
    
    fileprivate func callback(code: Int, callbackId: String, data: Any?) {
        let message = Message(method: JBX_METHOD_CALLBACK)
        message.code = code
        message.callbackId = callbackId
        message.data = data
        self.postMessage(message: message)
    }
    
    fileprivate func loadInjectedJS() -> String {
        let resourceBundle = Bundle(for: JSBridgeX.self)
        var bundle = Bundle.main
        if let url = resourceBundle.url(forResource: "JSBridgeX", withExtension: "bundle") {
            bundle = Bundle(url: url) ?? bundle
        }
        if let jsFilePath = bundle.path(forResource: "JSBridge", ofType: "js") {
            do {
                return try String(contentsOfFile: jsFilePath)
            } catch {
                
            }
        }
        return ""
    }
    
    fileprivate func dispatchMessageQueueFromJS(){
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_FETCH_MESSAGE_QUEUE)()"
        self.webView?.executeJavaScript(js: jsMethod) { [weak self] (object, error) in
            if let messageString = object as? String {
                self?.handleMessageQueueFromJS(messageString: messageString)
            }
        }
    }
    
    fileprivate func handleMessageQueueFromJS(messageString: String) {
        if let messageData = messageString.data(using: String.Encoding.utf8) {
            self.log(items: "dispatchMessageQueueFromJS:", messageString)
            let messages = self.parseMessageQueue(data: messageData)
            for message in messages {
                if message.method == JBX_METHOD_SEND {
                    self.handleMessageSentFromJS(message: message)
                } else if message.method == JBX_METHOD_CALLBACK {
                    self.handleMessageCallbackFromJS(message: message)
                }
            }
        }
    }
    
    fileprivate func parseMessageQueue(data: Data) -> [Message] {
        do {
            if let messages = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: AnyObject]] {
                return messages.flatMap({ (dict) -> Message? in
                    return Message(rawDict: dict)
                })
            }
        } catch {
            
        }
        return []
    }
    
    fileprivate func handleMessageSentFromJS(message: Message) {
        let callbackId = message.callbackId
        let eventName = message.eventName
        var callbackBlock: EventCallback?
        if callbackId != nil {
            callbackBlock = { [weak self] (code: Int, data: Any?) in
                self?.callback(code: code, callbackId: callbackId!, data: data)
            }
        }
        if let eventName = eventName {
            if let eventHandler = eventMap[eventName] {
                eventHandler(message.data, callbackBlock)
            } else {
                defaultEventHandler?(eventName, message.data, callbackBlock)
            }
            return
        }
        callbackBlock?(JSBridgeX.CODE_INVALID_PARAMETER, nil)
    }
    
    fileprivate func handleMessageCallbackFromJS(message: Message) {
        if let callbackId = message.callbackId,
            let eventCallback = eventCallbacks[callbackId] {
            if let code = message.code {
                eventCallback(code, message.data)
            } else {
                eventCallback(JSBridgeX.CODE_INVALID_PARAMETER, nil)
            }
        }
    }
    
    fileprivate func postMessage(message: Message) {
        self.log(items: "postMessage:", message.description)
        if postMessageQueue != nil {
            postMessageQueue!.append(message)
        } else {
            postMessageToJS(message: message)
        }
    }
    
    fileprivate func postMessageToJS(message: Message) {
        let jsMethod = "\(JBX_JS_OBJECT).\(JBX_JS_METHOD_POST_MESSAGE_TO_JS)(\(message.toString()))"
        self.webView?.executeJavaScript(js: jsMethod, completionHandler: nil)
    }
    
    fileprivate func log(items: Any..., separator: String = " ", terminator: String = "\n", file: NSString = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        let message = items.map({ String(describing: $0) }).joined(separator: separator)
        if let logClosure = JSBridgeX.LogClosure {
            logClosure(message, file, line, column, function)
        } else {
            let dateFormater = DateFormatter()
            dateFormater.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let date = dateFormater.string(from: Date())
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
    public var data: Any? {
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
            let data = try JSONSerialization.data(withJSONObject: self.dict, options: .prettyPrinted)
            return String(data: data, encoding: String.Encoding.utf8) ?? ""
        } catch {
            
        }
        return ""
    }
    
    fileprivate var dict: [String: Any] = [:]
    
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
            self.dict = rawDict
            return
        }
        
        return nil
    }
    
    public func toString() -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: self.dict, options: JSONSerialization.WritingOptions(rawValue: 0))
            return String(data: data, encoding: String.Encoding.utf8) ?? ""
        } catch {
            
        }
        return ""
    }
}

public enum WebViewNavigationType : Int {
    case linkActivated
    case formSubmitted
    case backForward
    case reload
    case formResubmitted
    case other
    
    static func from(navigationType: WKNavigationType) -> WebViewNavigationType {
        switch navigationType {
        case .linkActivated:
            return .linkActivated
        case .formSubmitted:
            return .formSubmitted
        case .backForward:
            return .backForward
        case .reload:
            return .reload
        case .formResubmitted:
            return .formResubmitted
        case .other:
            return .other
        }
    }
    
    static func from(navigationType: UIWebViewNavigationType) -> WebViewNavigationType {
        switch navigationType {
        case .linkClicked:
            return .linkActivated
        case .formSubmitted:
            return .formSubmitted
        case .backForward:
            return .backForward
        case .reload:
            return .reload
        case .formResubmitted:
            return .formResubmitted
        case .other:
            return .other
        }
    }
}

public protocol WebViewProtocol: class {
    func loadUrl(url: URL)
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

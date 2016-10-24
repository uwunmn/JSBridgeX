'use strict';

(function(w, doc) {
    if (w.JSBridge) return;

    var JBX_SCHEME = "torlaxbridge";
    var JBX_HOST = "__TORLAX_HOST__";
    var JBX_PATH = "/__TORLAX_EVENT__";
    
    var JBX_METHOD_SEND = "SEND";
    var JBX_METHOD_CALLBACK = "CALLBACK";
    
    var JBX_KEY_METHOD = "method";
    var JBX_KEY_EVENT_NAME = "eventName";
    var JBX_KEY_DATA = "data";
    var JBX_KEY_CODE = "code";
    var JBX_KEY_CALLBACK_ID = "callbackId";
    var JBX_KEY_DESCRIPTION = "description";

    var ua = navigator.userAgent;
    var isIOSDevice = /i(Phone|Pod|Pad|OS)/g.test(ua);
    var isAndroidDevice = /Android/g.test(ua);
    var sendMessages = [];
    var eventMap = {};
    var eventCallbacks = {};
    var eventUniqueId = 1;
    var messagingIframe;

    function init() {
        
    }

    function registerEvent(eventName, eventHandler) {
        eventMap[eventName] = eventHandler;
    }

    function unregisterEvent(eventName) {
        if (eventMap[eventName]) {
            delete eventMap[eventName];
        }
    }

    function send(eventName, data, eventCallback) {
        console.log('[send]' + 'eventName:' + eventName + ', data: ' + JSON.stringify(data));
        var message = {};
        message[JBX_KEY_METHOD] = JBX_METHOD_SEND;
        if (eventName) {
            message[JBX_KEY_EVENT_NAME] = eventName;
        }
        if (data) {
            message[JBX_KEY_DATA] = data;
        }
        if (eventCallback) {
            var callbackId = 'js_cb_' + (eventUniqueId++) + '_' + new Date().getTime();
            eventCallbacks[callbackId] = eventCallback;
            message[JBX_KEY_CALLBACK_ID] = callbackId;
        }
        postMessageToNative(message);
    }

    function callback(code, callbackId, data) {
        var message = {};
        message[JBX_KEY_METHOD] = JBX_METHOD_CALLBACK;
        message[JBX_KEY_CODE] = code
        message[JBX_KEY_CALLBACK_ID] = callbackId
        if (data) {
            message[JBX_KEY_DATA] = data
        }
        postMessageToNative(message);
    }

    function dispatchMessageFromNative(message) {
        console.log('dispatchMessage: ' + JSON.stringify(message));
        setTimeout(function() {
            try {
                if (message.method == JBX_METHOD_SEND) {
                    handleMessageSentFromNative(message);
                } else if (message.method == JBX_METHOD_CALLBACK) {
                    handleMessageCallbackFromNative(message)
                }              
            } catch (e) {
                callback(404, {JBX_KEY_DESCRIPTION: 'Not Found'});
            }
        });
    }

    function handleMessageSentFromNative(message) {
        var callbackId = message.callbackId;
        responseCallback = function(responseData) {
            if (callbackId) {
                callback(200, callbackId, responseData);    
            }
        };
        var handler = eventMap[message.eventName];
        if (handler) {
            handler(message.data, responseCallback);    
        } else {
            callback(404, {JBX_KEY_DESCRIPTION: 'Not Found'});
        }
    }

    function handleMessageCallbackFromNative(message) {
        var callbackId = message.callbackId;
        if (callbackId === undefined) {
            return;
        }
        var eventCallback = eventCallbacks[callbackId];
        if (eventCallback) {
            eventCallback(message.code, message.data);    
        }
    }

    function postMessageToNative(message) {
        sendMessages.push(message);
        triggerNativeCall();
    }

    function triggerNativeCall() {
        if (isIOSDevice) {
            messagingIframe.src = JBX_SCHEME + '://' + JBX_HOST + JBX_PATH;
        } else {
            try {
                AndroidAPI.dispatchMessageQueueFromJS(fetchMessageQueue());
            } catch (e) {
                console.log(e); 
            }
        }
    }

    function fetchMessageQueue() {
        try {
            var messages = sendMessages;
            sendMessages = [];
            var messageString = JSON.stringify(messages)
            console.log('[fetchMessageQueue] messages: ' + messageString);
            return messageString;
        } catch (e) {
            console.log(e);
        }
        return []
    }

    function ajax(path, data, callback) {
        send(METHOD_SEND, data, callback)
    }

    w.JSBridge = {
        init: init.bind(this),
        registerEvent: registerEvent.bind(this),
        unregisterEvent: unregisterEvent.bind(this),
        send: send.bind(this),
        dispatchMessageFromNative: dispatchMessageFromNative.bind(this),
        fetchMessageQueue: fetchMessageQueue.bind(this),
        ajax: ajax.bind(this),
    }

    messagingIframe = doc.createElement('iframe');
    messagingIframe.style.display = 'none';
    triggerNativeCall();
    doc.documentElement.appendChild(messagingIframe);

    var readyEvent = doc.createEvent('Events');
    readyEvent.initEvent('JSBridgeReady');
    readyEvent.bridge = JSBridge;
    doc.dispatchEvent(readyEvent);

})(window, document);
;
(function(w, doc) {
    if (w.JSBridge) return;

    var URL_SCHEME = 'jsridgexscheme';
    var URL_HOST = '__URL_HOST__';
    var URL_PATH = '__URL_PATH__';

    var METHOD_SEND = 'SEND';
    var METHOD_CALLBACK = 'CALLBACK';

    var ua = navigator.userAgent;
    var isIOSDevice = /i(Phone|Pod|Pad|OS)/g.test(ua);
    var isAndroidDevice = /Android/g.test(ua);
    var sendMessages = [];
    // var receivedMessages = [];
    var eventMap = {};
    var eventCallbacks = {};
    var eventUniqueId = 1;
    var messagingIframe;

    // function init() {
    //     var messages = receivedMessages;
    //     receivedMessages = null;
    //     for (var i = 0; i < messages.length; i++) {
    //         postMessageToNative(messages[i]);
    //     }
    // }

    function registerEvent(eventName, eventHandler) {
        eventMap[eventName] = eventHandler;
    }

    function deRegisterEvent(eventName) {
        if (eventMap[eventName]) {
            delete eventMap[eventName];
        }
    }

    function send(eventName, data, eventCallback) {
        console.log('[send]' + 'eventName:' + eventName + 'data: ' + JSON.stringify(data));
        var message = {};
        message["method"] = METHOD_SEND;
        if (eventName) {
            message["eventName"] = eventName;
        }
        if (data) {
            message["data"] = {
                data: data
            };
        }
        if (eventCallback) {
            var callbackId = 'js_cb_' + (eventUniqueId++) + '_' + new Date().getTime();
            eventCallbacks[callbackId] = eventCallback;
            message['callbackId'] = callbackId;
        }
        postMessageToNative(message);
    }

    function callback(code, callbackId, responseData) {
        var message = {};
        message["method"] = METHOD_CALLBACK;
        message['code'] = code
        message['callbackId'] = callbackId
        if (responseData) {
            message['data'] = responseData
        }
        postMessageToNative(message);
    }

    function _dispatchMessageFromNative(message) {
        console.log('_dispatchMessageFromNative:' + JSON.stringify(message));
        if (receivedMessages) {
            console.log('receivedMessages');
            receivedMessages.push(message);
        } else {
            dispatchMessage(message);
        }
    }

    function dispatchMessage(message) {
        console.log('dispatchMessage: ' + JSON.stringify(message));
        setTimeout(function() {
            try {
                var callbackId = message.callbackId;
                if (message.method == METHOD_SEND) {
                    console.log('dispatchMessage: ' + METHOD_SEND + 'callbackId:' + callbackId);
                    responseCallback = function(responseData) {
                        if (callbackId) {
                            callback(200, callbackId, responseData);    
                        }
                    };
                    var handler = eventMap[message.eventName];
                    if (handler) {
                        handler(message.data, responseCallback);    
                    } else {
                        callback(404);
                    }
                } else if (message.method == METHOD_CALLBACK) {
                    console.log('dispatchMessage: ' + METHOD_CALLBACK + 'callbackId:' + callbackId + ', code: ' + message.code);
                    if (callbackId === undefined) {
                        return;
                    }
                    var eventCallback = eventCallbacks[callbackId];
                    if (eventCallback) {
                        eventCallback(message.code, message.data);    
                    }
                }              
            } catch (e) {
                
            }
        });
    }

    function postMessageToNative(message) {
        sendMessages.push(message);
        triggerNativeCall();
    }

    function triggerNativeCall() {
        console.log('[triggerNativeCall]');
        setTimeout(function() {
            if (isIOSDevice) {
                messagingIframe.src = URL_SCHEME + '://' + URL_HOST + '/' + URL_PATH;
            } else {
                try {
                    var messages = sendMessages;
                    sendMessages = [];
                    console.log('[triggerNativeCall] messages: ' + JSON.stringify(messages));
                    AndroidAPI.dispatchJSMessageQueue(JSON.stringify(messages));
                } catch (e) {
                    console.log(e);
                }
            }
        });
    }

    w.JSBridge = {
        init: init.bind(this),
        send: send.bind(this),

        registerEvent: registerEvent.bind(this),
        deRegisterEvent: deRegisterEvent.bind(this),

        _dispatchMessageFromNative: _dispatchMessageFromNative.bind(this),
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
'use strict';

(function(w, doc) {
    if (w.JSBridge) return;

    var CODE_SUCCESS = 200;
    var CODE_NOT_FOUND = 404;
    var CODE_INVALID_PARAMETER = 403;
    var CODE_BAD_BRIDGE = 503;

    var JBX_SCHEME = 'jsbridgex';
    var JBX_HOST = '__JBX_HOST__';
    var JBX_PATH = '/__JBX_EVENT__';

    var JBX_METHOD_SEND = 'SEND';
    var JBX_METHOD_CALLBACK = 'CALLBACK';

    var JBX_KEY_METHOD = 'method';
    var JBX_KEY_EVENT_NAME = 'eventName';
    var JBX_KEY_DATA = 'data';
    var JBX_KEY_CODE = 'code';
    var JBX_KEY_CALLBACK_ID = 'callbackId';

    var ua = navigator.userAgent;
    var isIOSDevice = /i(Phone|Pod|Pad|OS)/g.test(ua);
    var isAndroidDevice = /Android/g.test(ua);
    var sendMessages = [];
    var eventMap = {};
    var eventCallbacks = {};
    var eventUniqueId = 1;
    var messagingIframe;
    var messageHandler;

    function init(defaultMessageHandler) {
        messageHandler = defaultMessageHandler;
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
        if (typeof eventCallback === 'function') {
            var callbackId = 'js_cb_' + (eventUniqueId++) + '_' + new Date().getTime();
            eventCallbacks[callbackId] = eventCallback;
            message[JBX_KEY_CALLBACK_ID] = callbackId;
        }
        postMessageToNative(message);
    }

    function callback(code, callbackId, data) {
        var message = {};
        message[JBX_KEY_METHOD] = JBX_METHOD_CALLBACK;
        message[JBX_KEY_CODE] = code;
        message[JBX_KEY_CALLBACK_ID] = callbackId;
        if (data) {
            message[JBX_KEY_DATA] = data;
        }
        postMessageToNative(message);
    }

    function listAllEvents() {
        send('listAllEvents', null, function(code, data) {
            console.log('Events: ' + JSON.stringify(data.Events));
        });
    }

    function dispatchMessageFromNative(message) {
        console.log('dispatchMessageFromNative: ' + JSON.stringify(message));
        setTimeout(function() {
            try {
                if (message.method === JBX_METHOD_SEND) {
                    handleMessageSentFromNative(message);
                } else if (message.method === JBX_METHOD_CALLBACK) {
                    handleMessageCallbackFromNative(message);
                }
            } catch (e) {
                console.log(e);
            }
        });
    }

    function handleMessageSentFromNative(message) {
        console.log('handleMessageSentFromNative');
        var callbackId = message.callbackId;
        var eventHandler = eventMap[message.eventName];
        if (typeof eventHandler === 'function') {
            eventHandler(message.data, function(code, responseData) {
                if (callbackId) {
                    callback(code, callbackId, responseData);
                }
            });
            return;
        }
        typeof messageHandler === 'function' && messageHandler(message);
    }

    function handleMessageCallbackFromNative(message) {
        console.log('handleMessageCallbackFromNative');
        var callbackId = message.callbackId;
        if (callbackId) {
            var eventCallback = eventCallbacks[callbackId];
            typeof eventCallback === 'function' && eventCallback(message.data, message.code);
        }
    }

    function postMessageToNative(message) {
        sendMessages.push(message);
        triggerNativeCall();
    }

    function triggerNativeCall() {
        if (isIOSDevice) {
            messagingIframe.src = JBX_SCHEME + '://' + JBX_HOST + JBX_PATH;
        } else if (isAndroidDevice) {
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
            var messageString = JSON.stringify(messages);
            console.log('[fetchMessageQueue] messages: ' + messageString);
            return messageString;
        } catch (e) {
            console.log(e);
        }
        return [];
    }

    w.JSBridge = {
        init: init.bind(this),
        registerEvent: registerEvent.bind(this),
        unregisterEvent: unregisterEvent.bind(this),
        send: send.bind(this),
        dispatchMessageFromNative: dispatchMessageFromNative.bind(this),
        fetchMessageQueue: fetchMessageQueue.bind(this),
        listAllEvents: listAllEvents.bind(this)
    };

    messagingIframe = doc.createElement('iframe');
    messagingIframe.style.display = 'none';
    triggerNativeCall();
    doc.documentElement.appendChild(messagingIframe);

    var readyEvent = doc.createEvent('Events');
    readyEvent.initEvent('JSBridgeReady');
    readyEvent.bridge = JSBridge;
    doc.dispatchEvent(readyEvent);
})(window, document);

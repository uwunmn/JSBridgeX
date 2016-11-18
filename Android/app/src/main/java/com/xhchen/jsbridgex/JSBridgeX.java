package com.xhchen.jsbridgex;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.os.Build;
import android.text.TextUtils;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by xhChen on 16/9/8.
 */
@SuppressLint({"addJavascriptInterface", "setJavaScriptEnabled"})
public final class JSBridgeX {
    public static final int CODE_SUCCESS = 200;
    public static final int CODE_NOT_FOUND = 404;
    public static final int CODE_INVALID_PARAMETER = 403;
    public static final int CODE_BAD_BRIDGE = 503;

    private static final String JS_BRIDGE_NAME = "JSBridge.js";

    private static final String JBX_JS_OBJECT = "JSBridge";
    private static final String JBX_JS_METHOD_POST_MESSAGE_TO_JS = "dispatchMessageFromNative";

    private static final String JBX_METHOD_SEND = "SEND";
    private static final String JBX_METHOD_CALLBACK = "CALLBACK";

    private static final String JBX_KEY_METHOD = "method";
    private static final String JBX_KEY_EVENT_NAME = "eventName";
    private static final String JBX_KEY_DATA = "data";
    private static final String JBX_KEY_CODE = "code";
    private static final String JBX_KEY_CALLBACK_ID = "callbackId";
    private static final String JBX_KEY_DESCRIPTION = "description";

    private WebView webView;
    private WebViewClientInterface webViewClientInterface;
    private String injectedJS;
    private int eventUniqueId = 0;

    private JSONArray postMessageQueue = new JSONArray();
    private Map<String, EventCallback> eventCallbacks = new HashMap<>();
    private Map<String, EventHandler> eventMap = new HashMap<>();
    private DefaultEventHandler defaultEventHandler;

    public JSBridgeX(Context context) {
        this.injectedJS = loadInjectedJS(context);
    }

    public void init(WebView webView, WebViewClientInterface webViewClient, DefaultEventHandler defaultEventHandler) {
        this.webView = webView;
        this.webViewClientInterface = webViewClient;
        this.defaultEventHandler = defaultEventHandler;
        if (webView != null) {
            webView.getSettings().setJavaScriptEnabled(true);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                WebView.setWebContentsDebuggingEnabled(true);
            }
            webView.removeJavascriptInterface("searchBoxJavaBridge_");
            webView.removeJavascriptInterface("accessibility");
            webView.removeJavascriptInterface("accessibilityTraversal");

            webView.getSettings().setDomStorageEnabled(true);
            webView.getSettings().setUseWideViewPort(true);
            webView.getSettings().setLoadWithOverviewMode(true);
            webView.addJavascriptInterface(new JSInterface(), "AndroidAPI");
            webView.setWebViewClient(new WebViewClient() {
                @Override
                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    if (webViewClientInterface != null) {
                        return webViewClientInterface.shouldOverrideUrlLoading(view, url);
                    }
                    return super.shouldOverrideUrlLoading(view, url);
                }

                @Override
                public void onPageStarted(WebView view, String url, Bitmap favicon) {
                    if (webViewClientInterface != null) {
                        webViewClientInterface.onPageStarted(view, url, favicon);
                    }
                }

                @Override
                public void onPageFinished(WebView view, String url) {
                    if (postMessageQueue != null) {
                        int queueCount = postMessageQueue.length();
                        if (queueCount > 0) {
                            for (int i = 0; i < queueCount; i++) {
                                try {
                                    postMessageToJS(postMessageQueue.getJSONObject(i));
                                } catch (JSONException e) {
                                    Log.e("[JSBridgeX]", "index = " + i);
                                    e.printStackTrace();
                                }
                            }
                        }
                        postMessageQueue = null;
                    }
                    if (webViewClientInterface != null) {
                        webViewClientInterface.onPageFinished(view, url);
                    }
                    if (!TextUtils.isEmpty(injectedJS)) {
                        view.loadUrl("javascript: " + injectedJS);
                    }
                }

                @TargetApi(android.os.Build.VERSION_CODES.M)
                @Override
                public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                    onReceivedError(view, error.getErrorCode(), error.getDescription().toString(), request.getUrl().toString());
                }

                @Override
                public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                    if (webViewClientInterface != null) {
                        webViewClientInterface.onReceivedError(view, errorCode, description, failingUrl);
                    }
                }
            });
        }
    }

    public void loadURL(String url) {
        if (webView != null) {
            webView.loadUrl(url);
        }
    }

    public void registerEvent(String eventName, EventHandler callback) {
        if (TextUtils.isEmpty(eventName) || callback == null)
            return;
        eventMap.put(eventName, callback);
    }

    public void unregisterEvent(String eventName) {
        if (TextUtils.isEmpty(eventName))
            return;
        eventMap.remove(eventName);
    }

    public void send(String eventName, JSONObject data, EventCallback callback) {
        try {
            JSONObject message = new JSONObject();
            message.put(JBX_KEY_METHOD, JBX_METHOD_SEND);
            message.put(JBX_KEY_EVENT_NAME, eventName);
            message.put(JBX_KEY_DATA, data);
            if (callback != null) {
                String callbackId = "android_cb_" + (++eventUniqueId);
                message.put(JBX_KEY_CALLBACK_ID, callbackId);
                eventCallbacks.put(callbackId, callback);
            }
            postMessage(message);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void callback(int code, String callbackId, Object data) {
        try {
            JSONObject message = new JSONObject();
            message.put(JBX_KEY_CODE, code);
            message.put(JBX_KEY_CALLBACK_ID, callbackId);
            message.put(JBX_KEY_METHOD, JBX_METHOD_CALLBACK);
            message.put(JBX_KEY_DATA, data);
            postMessage(message);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void postMessage(final JSONObject message) {
        if (postMessageQueue != null) {
            postMessageQueue.put(message);
        } else {
            postMessageToJS(message);
        }
    }

    private void postMessageToJS(final JSONObject message) {
        webView.post(new Runnable() {
            @Override
            public void run() {
                String js = String.format("javascript: %s.%s(%s);", JBX_JS_OBJECT,
                        JBX_JS_METHOD_POST_MESSAGE_TO_JS, message.toString());
                webView.loadUrl(js);
            }
        });
    }

    private String loadInjectedJS(Context context) {
        String contents = "";
        try {
            InputStream stream = context.getAssets().open(JS_BRIDGE_NAME);
            byte[] buffer = new byte[stream.available()];
            stream.read(buffer);
            stream.close();
            contents = new String(buffer);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return contents;
    }

    private class JSInterface {
        @JavascriptInterface
        public void dispatchMessageQueueFromJS(String messages) {
            Log.d("[JSBridgeX]", messages);
            try {
                JSONArray messageArray = new JSONArray(messages);
                for (int i = 0; i < messageArray.length(); i++) {
                    JSONObject message = messageArray.getJSONObject(i);
                    final String method = message.optString(JBX_KEY_METHOD, "");
                    if (method.equalsIgnoreCase(JBX_METHOD_SEND)) {
                        handleMessageSentFromJS(message);
                    } else if (method.equalsIgnoreCase(JBX_METHOD_CALLBACK)) {
                        handleMessageCallbackFromJS(message);
                    }
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }

        private void handleMessageSentFromJS(JSONObject message) throws JSONException {
            final String callbackId = message.optString(JBX_KEY_CALLBACK_ID, "");
            final String eventName = message.optString(JBX_KEY_EVENT_NAME, "");
            EventCallback callback = null;
            if (!TextUtils.isEmpty(callbackId)) {
                callback = new EventCallback(){

                    @Override
                    public void onCallback(int code, Object data) {
                        callback(code, callbackId, data);
                    }

                };
            }
            if (!TextUtils.isEmpty(eventName)) {
                EventHandler eventHandler = eventMap.get(eventName);
                Object data = message.opt(JBX_KEY_DATA);
                if (eventHandler != null) {
                    eventHandler.onHandle(data, callback);
                } else if(defaultEventHandler != null) {
                    defaultEventHandler.onHandle(eventName, data, callback);
                }
                return;
            }

            if (callback != null) {
                callback.onCallback(CODE_INVALID_PARAMETER, null);
            }
        }

        private void handleMessageCallbackFromJS(JSONObject message) {
            final String callbackId = message.optString(JBX_KEY_CALLBACK_ID, "");
            if (TextUtils.isEmpty(callbackId)) {
                EventCallback eventCallback = eventCallbacks.get(callbackId);
                if (eventCallback != null) {
                    final int code = message.optInt(JBX_KEY_CODE, 0);
                    if (code != 0) {
                        eventCallback.onCallback(code, message.opt(JBX_KEY_DATA));
                    } else {
                        eventCallback.onCallback(CODE_INVALID_PARAMETER, null);
                    }
                }
            }
        }
    }

    public interface EventCallback {
        void onCallback(int code, Object data);
    }

    public interface EventHandler {
        void onHandle(Object data, EventCallback callback);
    }

    public interface DefaultEventHandler {
        void onHandle(String eventName, Object data, EventCallback callback);
    }

    public interface WebViewClientInterface {
        boolean shouldOverrideUrlLoading(WebView view, String url);

        void onPageStarted(WebView view, String url, Bitmap favicon);

        void onPageFinished(WebView view, String url);

        void onReceivedError(WebView view, int errorCode, String description, String failingUrl);
    }
}

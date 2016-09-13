package com.xhchen.jsbridgex;

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
public final class JSBridge {
    private static final String JS_BRIDGE_NAME = "JSBridge.js";
    private static final String JS_BRIDGE_OBJECT = "JSBridge";
    private static final String JS_METHOD_DISPATCH_MESSAGE = "_dispatchMessageFromNative";

    private WebView webView;
    private WebViewClientInterface webViewClientInterface;
    private String injectedJS;
    private int eventUniqueId = 0;

    private JSONArray lazyMessageQueue = new JSONArray();
    private Map<String, EventResponseCallback> eventResponseCallbacks = new HashMap<>();
    private Map<String, EventHandler> eventMap = new HashMap<>();

    public JSBridge(Context context, WebView webView) {
        this.webView = webView;
        this.injectedJS = loadInjectedJS(context);
    }

    public void init(WebViewClientInterface webViewClient) {
        webViewClientInterface = webViewClient;
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
                    if (lazyMessageQueue != null) {
                        int queueCount = lazyMessageQueue.length();
                        if (queueCount > 0) {
                            for (int i = 0; i < queueCount; i++) {
                                try {
                                    dispatchMessage(lazyMessageQueue.getJSONObject(i));
                                } catch (JSONException e) {
                                    Log.e("[JSBridgeX]", "index = " + i);
                                    e.printStackTrace();
                                }
                            }
                        }
                        lazyMessageQueue = null;
                    }
                    if (webViewClientInterface != null) {
                        webViewClientInterface.onPageFinished(view, url);
                    }
                    if (!TextUtils.isEmpty(injectedJS)) {
                        webView.loadUrl("javascript: " + injectedJS);
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

    public void addEvent(String eventName, EventHandler callback) {
        if (TextUtils.isEmpty(eventName) || callback == null)
            return;
        eventMap.put(eventName, callback);
    }

    public void removeEvent(String eventName) {
        if (TextUtils.isEmpty(eventName))
            return;
        eventMap.remove(eventName);
    }

    public void loadHTML(String url) {
        if (webView != null) {
            webView.loadUrl(url);
        }
    }

    public void send(String eventName, JSONObject data, EventResponseCallback callback) {
        try {
            JSONObject message = new JSONObject();
            message.put("data", data);
            message.put("method", "SEND");
            message.put("eventName", eventName);
            if (callback != null) {
                String callbackId = "android_cb_" + (++eventUniqueId);
                message.put("callbackId", callbackId);
                eventResponseCallbacks.put(callbackId, callback);
            }
            dispatchMessage(message);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void callback(int code, String callbackId, JSONObject data) {
        try {
            JSONObject message = new JSONObject();
            message.put("code", code);
            message.put("callbackId", callbackId);
            message.put("method", "CALLBACK");
            message.put("data", data);
            dispatchMessage(message);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void dispatchMessage(JSONObject message) {
        if (lazyMessageQueue != null) {
            lazyMessageQueue.put(message);
        } else {
            postMessageToJS(message);
        }
    }

    private void postMessageToJS(final JSONObject message) {
        webView.post(new Runnable() {
            @Override
            public void run() {
                String js = String.format("javascript: %s.%s(%s);", JS_BRIDGE_OBJECT,
                        JS_METHOD_DISPATCH_MESSAGE, message.toString());
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
        }
        return contents;
    }

    public class JSInterface {
        @JavascriptInterface
        public void dispatchJSMessageQueue(String messages) {
            Log.d("[JSBridgeX]", messages);
            try {
                JSONArray messageArray = new JSONArray(messages);
                int count = messageArray.length();
                if (count <= 0) {
                    return;
                }
                for (int i = 0; i < count; i++) {
                    JSONObject message = messageArray.getJSONObject(i);
                    final String method = message.getString("method");
                    final String callbackId = message.getString("callbackId");
                    JSONObject data = message.getJSONObject("data");
                    if (method.equalsIgnoreCase("SEND")) {
                        String eventName = message.getString("eventName");
                        EventHandler eventHandler = eventMap.get(eventName);
                        if (eventHandler != null) {
                            eventHandler.onHandle(data, new EventResponseCallback(){

                                @Override
                                public void onResponseCallback(int code, JSONObject data) {
                                    if (!TextUtils.isEmpty(callbackId)) {
                                        callback(code, callbackId, data);
                                    }
                                }

                            });
                        }
                    } else if (method.equalsIgnoreCase("CALLBACK")) {
                        int code = message.getInt("code");
                        if (TextUtils.isEmpty(callbackId)) {
                            EventResponseCallback eventCallback = eventResponseCallbacks.get(callbackId);
                            eventCallback.onResponseCallback(code, data);
                        }
                    } else {

                    }
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }

    public interface EventResponseCallback {
        void onResponseCallback(int code, JSONObject data);
    }

    public interface EventHandler {
        void onHandle(JSONObject data, EventResponseCallback callback);
    }

    public interface WebViewClientInterface {
        void onPageStarted(WebView view, String url, Bitmap favicon);

        void onPageFinished(WebView view, String url);

        boolean shouldOverrideUrlLoading(WebView view, String url);

        void onReceivedError(WebView view, int errorCode, String description, String failingUrl);
    }
}

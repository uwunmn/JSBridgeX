package com.xhchen.test;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.webkit.WebView;

import com.xhchen.jsbridgex.JSBridgeX;
import com.xhchen.jsbridgex.R;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Created by xhChen on 16/9/8.
 */
public class MainActivity extends Activity implements JSBridgeX.WebViewClientInterface {

    private JSBridgeX jsBridge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        WebView webView = (WebView) findViewById(R.id.web_view);
        jsBridge = new JSBridgeX(this);
        jsBridge.init(webView, this, new JSBridgeX.DefaultEventHandler() {
            @Override
            public void onHandle(String eventName, JSONObject data, JSBridgeX.EventCallback callback) {
                Log.d("[JSBridgeX]", "eventName: " + eventName + " was not found");
                if (callback != null) {
                    callback.onCallback(JSBridgeX.CODE_NOT_FOUND, null);
                }
            }
        });
        jsBridge.loadURL("file:///android_asset/index.html");
        jsBridge.registerEvent("SendMessageFromJS", new JSBridgeX.EventHandler() {

            @Override
            public void onHandle(JSONObject data, JSBridgeX.EventCallback callback) {
                Log.d("[JSBridgeX]", "[SendMessageFromJS] data: " + data.toString());
                try {
                    JSONObject responseData = new JSONObject();
                    responseData.put("value", "hello");
                    callback.onCallback(200, responseData);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
        });
    }

    public void onClickSendMessage(View view) {
        try {
            JSONObject data = new JSONObject();
            data.put("text", "hello");
            jsBridge.send("SendMessage", data, new JSBridgeX.EventCallback(){

                @Override
                public void onCallback(int code, JSONObject data) {
                    Log.d("[JSBridgeX]", "code: " + code + ", data: " + data.toString());
                }
            });
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        return false;
    }

    @Override
    public void onPageStarted(WebView view, String url, Bitmap favicon) {

    }

    @Override
    public void onPageFinished(WebView view, String url) {

    }

    @Override
    public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {

    }
}

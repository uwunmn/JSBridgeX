package com.xhchen.test;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.webkit.WebView;

import com.xhchen.jsbridgex.JSBridge;
import com.xhchen.jsbridgex.R;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Created by xhChen on 16/9/8.
 */
public class MainActivity extends Activity {

    private JSBridge jsBridge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        jsBridge = new JSBridge(this, (WebView) findViewById(R.id.web_view));
        jsBridge.init(null);
        jsBridge.loadHTML("file:///android_asset/index.html");
        jsBridge.addEvent("SendMessageFromJS", new JSBridge.EventHandler() {

            @Override
            public void onHandle(JSONObject data, JSBridge.EventResponseCallback callback) {
                Log.d("[JSBridgeX]", "[SendMessageFromJS] data: " + data.toString());
                try {
                    JSONObject responseData = new JSONObject();
                    responseData.put("value", "hello");
                    callback.onResponseCallback(200, responseData);
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
            jsBridge.send("SendMessageFromNative", data, new JSBridge.EventResponseCallback(){

                @Override
                public void onResponseCallback(int code, JSONObject data) {
                    Log.d("[JSBridgeX]", "code: " + code + ", data: " + data.toString());
                }
            });
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
}

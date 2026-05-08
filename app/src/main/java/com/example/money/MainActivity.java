package com.example.money;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.OutputStream;
import java.io.OutputStreamWriter;

public class MainActivity extends Activity {
    private static final int REQUEST_EXPORT_CSV = 1001;

    private WebView webView;
    private String pendingCsv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());
        webView.addJavascriptInterface(new AppBridge(), "MoneyAndroid");
        webView.loadUrl("file:///android_asset/index.html");

        setContentView(webView);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
            return;
        }
        super.onBackPressed();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_EXPORT_CSV && resultCode == RESULT_OK && data != null && data.getData() != null) {
            writeCsv(data.getData());
        }
    }

    private void writeCsv(Uri uri) {
        try {
            OutputStream stream = getContentResolver().openOutputStream(uri);
            if (stream == null) {
                throw new IllegalStateException("无法打开导出文件");
            }
            OutputStreamWriter writer = new OutputStreamWriter(stream, "UTF-8");
            writer.write('\ufeff');
            writer.write(pendingCsv == null ? "" : pendingCsv);
            writer.flush();
            writer.close();
            Toast.makeText(this, "表格已导出", Toast.LENGTH_LONG).show();
        } catch (Exception ex) {
            Toast.makeText(this, "导出失败：" + ex.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private class AppBridge {
        @JavascriptInterface
        public void exportCsv(final String fileName, final String csv) {
            pendingCsv = csv;
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("text/csv");
                    intent.putExtra(Intent.EXTRA_TITLE, fileName == null || fileName.length() == 0
                            ? "家庭记账表.csv"
                            : fileName);
                    startActivityForResult(intent, REQUEST_EXPORT_CSV);
                }
            });
        }

        @JavascriptInterface
        public void toast(final String message) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Toast.makeText(MainActivity.this, message, Toast.LENGTH_SHORT).show();
                }
            });
        }
    }
}

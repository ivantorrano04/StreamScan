package com.example.cam_app

import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		try {
			WebView.setWebContentsDebuggingEnabled(false)
		} catch (e: Exception) {
			// ignore if not available on some devices/SDKs
		}
	}
}

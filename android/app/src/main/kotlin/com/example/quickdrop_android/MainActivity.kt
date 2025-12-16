package com.example.quickdrop_android

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import android.media.MediaScannerConnection // <--- IMPORT THIS
import androidx.annotation.NonNull
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.core.app.Person
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.quickdrop/share"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "addShareTarget") {
                // Logic to add Mac to Share Sheet
                val name = call.argument<String>("name")
                val id = call.argument<String>("id")
                if (name != null && id != null) {
                    addShareShortcut(name, id)
                    result.success("Shortcut Added")
                } else {
                    result.error("INVALID_ARGS", "Name or ID missing", null)
                }
            } 
            // NEW: Logic to refresh Gallery
            else if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    MediaScannerConnection.scanFile(
                        context, arrayOf(path), null, null
                    )
                    result.success("Scanned")
                } else {
                    result.error("INVALID_PATH", "Path missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun addShareShortcut(name: String, id: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val person = Person.Builder()
                .setName(name)
                .setKey(id)
                .build()

            val shortcut = ShortcutInfoCompat.Builder(context, id)
                .setShortLabel(name)
                .setPerson(person)
                .setCategories(setOf("com.example.quickdrop_android.SHARE_TARGET"))
                .setIntent(Intent(Intent.ACTION_SEND).apply {
                    action = Intent.ACTION_SEND
                    putExtra("TARGET_DEVICE_ID", id) 
                    component = componentName
                })
                .setLongLived(true)
                .build()

            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
        }
    }
}
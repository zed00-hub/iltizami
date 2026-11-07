#!/usr/bin/env python3
"""يُشغَّل بعد `flutter create --platforms=android .` لضبط أندرويد:
الأذونات، مستقبلات الإشعارات، اسم التطبيق، الأيقونة، وتفعيل desugaring."""
import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
APP = os.path.join(ROOT, "android", "app")
MANIFEST = os.path.join(APP, "src", "main", "AndroidManifest.xml")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


def patch_manifest():
    s = read(MANIFEST)
    perms = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.VIBRATE",
        "android.permission.SCHEDULE_EXACT_ALARM",
        "android.permission.USE_EXACT_ALARM",
    ]
    add = ""
    for p in perms:
        if p not in s:
            add += f'    <uses-permission android:name="{p}"/>\n'
    if add:
        s = s.replace("<application", add + "    <application", 1)

    s = re.sub(r'android:label="[^"]*"', 'android:label="التزام"', s, count=1)

    receivers = (
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    if "ScheduledNotificationReceiver" not in s:
        s = s.replace("</application>", receivers + "    </application>", 1)
    if "ActionBroadcastReceiver" not in s:
        s = s.replace(
            "</application>",
            '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />\n    </application>',
            1,
        )
    write(MANIFEST, s)
    print("manifest patched")


def patch_gradle():
    kts = os.path.join(APP, "build.gradle.kts")
    groovy = os.path.join(APP, "build.gradle")
    if os.path.exists(kts):
        s = read(kts)
        if "isCoreLibraryDesugaringEnabled" not in s:
            s = re.sub(
                r"compileOptions\s*\{",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
                s,
                count=1,
            )
        if "desugar_jdk_libs" not in s:
            s += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        write(kts, s)
        print("build.gradle.kts patched")
    elif os.path.exists(groovy):
        s = read(groovy)
        if "coreLibraryDesugaringEnabled" not in s:
            s = re.sub(
                r"compileOptions\s*\{",
                "compileOptions {\n        coreLibraryDesugaringEnabled true",
                s,
                count=1,
            )
        if "desugar_jdk_libs" not in s:
            s += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        write(groovy, s)
        print("build.gradle patched")
    else:
        print("لم يُعثر على build.gradle", file=sys.stderr)
        sys.exit(1)


def copy_icons():
    src = os.path.join(ROOT, "tool", "icons")
    res = os.path.join(APP, "src", "main", "res")
    for d in os.listdir(src):
        sd = os.path.join(src, d)
        if not (os.path.isdir(sd) and d.startswith("mipmap-")):
            continue
        dd = os.path.join(res, d)
        os.makedirs(dd, exist_ok=True)
        shutil.copy(os.path.join(sd, "ic_launcher.png"), os.path.join(dd, "ic_launcher.png"))
    # أيقونات adaptive الافتراضية قد تحجب الأيقونة الجديدة
    for d in os.listdir(res):
        if d.startswith("mipmap-anydpi"):
            shutil.rmtree(os.path.join(res, d), ignore_errors=True)
    print("icons copied")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    copy_icons()

#!/usr/bin/env bash
# Jalankan SEKALI dari folder proyek (perlu Flutter SDK >= 3.24 terpasang).
set -e
ORG="my.id.rfproject"

if [ ! -d android ]; then
  flutter create --org "$ORG" --project-name rfbuilder_app --platforms=android .
fi

M=android/app/src/main/AndroidManifest.xml
python3 - "$M" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
perms=[
 "android.permission.INTERNET","android.permission.ACCESS_NETWORK_STATE",
 "android.permission.POST_NOTIFICATIONS","android.permission.CAMERA",
 "android.permission.RECORD_AUDIO","android.permission.REQUEST_INSTALL_PACKAGES",
 "android.permission.VIBRATE"]
add="".join(f'    <uses-permission android:name="{x}"/>\n' for x in perms if x not in s)
s=s.replace("<application", add+"    <application",1) if add else s
if "usesCleartextTraffic" not in s:
    s=s.replace("<application","<application android:usesCleartextTraffic=\"false\"",1)
if 'android:label=' in s:
    s=re.sub(r'android:label="[^"]*"','android:label="RFBuilder"',s,count=1)
open(p,'w',encoding='utf-8').write(s)
PY

# minSdk 23
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] && sed -i -E 's/minSdk(Version)? *(=)? *flutter\.minSdkVersion/minSdk\2 23/; s/minSdkVersion +flutter\.minSdkVersion/minSdkVersion 23/' "$f" || true
done

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
echo "Selesai. Lanjut baca README.md (bagian SHA-1 Google) lalu: flutter run"

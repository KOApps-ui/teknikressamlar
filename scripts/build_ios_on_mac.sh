#!/bin/bash
set -e
echo "=== KO|Apps Teknik Ressamlar - iOS IPA Derleme Başlatılıyor ==="
flutter pub get
flutter build ios --release --no-codesign
rm -rf Payload KO_Apps_TeknikRessam.ipa
mkdir -p Payload
cp -r build/ios/iphoneos/Runner.app Payload/
zip -r KO_Apps_TeknikRessam.ipa Payload
rm -rf Payload
echo "=== BAŞARILI! KO_Apps_TeknikRessam.ipa oluşturuldu ==="

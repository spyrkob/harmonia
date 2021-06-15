#!/bin/bash


pwd

WGET='wget -q --no-check-certificate'

echo "download eclipse-jakartaeetck-8.0.2.zip for Jakarta EE 8 that resolves JSON-B regression"
$WGET https://download.eclipse.org/jakartaee/platform/8/eclipse-jakartaeetck-8.0.2.zip.sig
$WGET https://download.eclipse.org/jakartaee/platform/8/eclipse-jakartaeetck-8.0.2.zip

mv eclipse-jakartaeetck-8.0.2.zip jakartaeetck.zip
mv eclipse-jakartaeetck-8.0.2.zip.sig jakartaeetckinfo.txt
cat jakartaeetckinfo.txt
mkdir -p release/JAVAEE_BUILD/latest
sha256sum jakartaeetck.zip > jakartaeetck.fingerprint
echo "local sha256sum of jakartaeetck.zip="
cat jakartaeetck.fingerprint
mv jakartaeetck.zip release/JAVAEE_BUILD/latest/

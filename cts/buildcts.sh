#!/bin/bash


pwd

WGET='wget -q --no-check-certificate'

echo "download eclipse-jakartaeetck-8.0.2.zip for Jakarta EE 8 that resolves JSON-B regression"
$WGET https://download.eclipse.org/jakartaee/platform/8/eclipse-jakartaeetck-8.0.2.zip.sig
$WGET https://download.eclipse.org/jakartaee/platform/8/eclipse-jakartaeetck-8.0.2.zip

mv workdir/eclipse-jakartaeetck-8.0.2.zip workdir/jakartaeetck.zip
mv workdir/eclipse-jakartaeetck-8.0.2.zip.sig workdir/jakartaeetckinfo.txt
cat workdir/jakartaeetckinfo.txt
mkdir -p workdir/release/JAVAEE_BUILD/latest
sha256sum workdir/jakartaeetck.zip > workdir/jakartaeetck.fingerprint
echo "local sha256sum of jakartaeetck.zip="
cat workdir/jakartaeetck.fingerprint
mv workdir/jakartaeetck.zip workdir/release/JAVAEE_BUILD/latest/

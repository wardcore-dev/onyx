#!/bin/bash
APP=onyx
VERSION=1.0.0
BUNDLE=build/linux/x64/release/bundle

# --- .tar.gz для всех ---
tar -czf ${APP}-${VERSION}-linux-x64.tar.gz -C ${BUNDLE} .
echo "Done: ${APP}-${VERSION}-linux-x64.tar.gz"

# --- .deb для Ubuntu/Debian ---
DEB_DIR=${APP}_${VERSION}_amd64
mkdir -p ${DEB_DIR}/DEBIAN
mkdir -p ${DEB_DIR}/opt/${APP}
mkdir -p ${DEB_DIR}/usr/share/applications

cp -r ${BUNDLE}/. ${DEB_DIR}/opt/${APP}/

cat > ${DEB_DIR}/DEBIAN/control << EOF
Package: ${APP}
Version: ${VERSION}
Architecture: amd64
Maintainer: © 2026 WARDCORE
Description: ONYX
EOF

cat > ${DEB_DIR}/usr/share/applications/${APP}.desktop << EOF
[Desktop Entry]
Name=ONYX
Exec=/opt/${APP}/${APP}
Icon=/opt/${APP}/data/flutter_assets/assets/icon.png
Type=Application
Categories=Utility;
EOF

dpkg-deb --build ${DEB_DIR}
echo "Done: ${DEB_DIR}.deb"

rm -rf ${DEB_DIR}

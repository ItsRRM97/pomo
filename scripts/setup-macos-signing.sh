#!/usr/bin/env bash
# Creates and trusts a local self-signed code signing identity for Pomo.
#
# Why: `flutter build macos` without a signing identity produces an ad-hoc
# signed app. macOS refuses UNUserNotificationCenter authorization for
# ad-hoc signed apps (UNErrorDomain Code=1 "Notifications are not allowed
# for this application"), so banner notifications silently never work.
# A stable self-signed identity fixes this for local/unsigned distribution.
#
# Run once per machine: ./scripts/setup-macos-signing.sh
# The trust step opens a system dialog; approve it with your login password.
set -euo pipefail

IDENTITY_NAME="${POMO_SIGN_IDENTITY:-Pomo Dev Signing}"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
  echo "OK: signing identity '$IDENTITY_NAME' already exists and is valid."
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "--> Generating self-signed code signing certificate '$IDENTITY_NAME'..."
openssl req -x509 -newkey rsa:2048 \
  -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" -days 3650 -nodes \
  -subj "/CN=$IDENTITY_NAME" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "basicConstraints=critical,CA:FALSE" >/dev/null 2>&1

# -legacy is required with OpenSSL 3.x so Keychain can parse the p12.
openssl pkcs12 -export -legacy \
  -out "$WORKDIR/identity.p12" \
  -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
  -passout pass:pomodev -name "$IDENTITY_NAME" 2>/dev/null \
  || openssl pkcs12 -export -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
    -out "$WORKDIR/identity.p12" \
    -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
    -passout pass:pomodev -name "$IDENTITY_NAME"

echo "--> Importing into login keychain..."
security import "$WORKDIR/identity.p12" \
  -k "$HOME/Library/Keychains/login.keychain-db" \
  -P pomodev -A -T /usr/bin/codesign

echo "--> Trusting certificate for code signing (system dialog may appear)..."
security add-trusted-cert -p codeSign -p basic \
  -k "$HOME/Library/Keychains/login.keychain-db" "$WORKDIR/cert.pem"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
  echo "OK: '$IDENTITY_NAME' is ready. Builds via build_macos_dmg.sh will now use it."
else
  echo "ERROR: identity was imported but is not valid for code signing." >&2
  echo "Open Keychain Access, find '$IDENTITY_NAME', and set trust to Always Trust for Code Signing." >&2
  exit 1
fi

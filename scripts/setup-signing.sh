#!/usr/bin/env bash
#
# Creates a self-signed code signing certificate in the login keychain, once.
# Builds signed with it keep the same identity, so macOS remembers the Automation
# (Spotify) permission across rebuilds. Safe to re-run.
#
set -euo pipefail

NAME="MenuBarKit Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Signing certificate '$NAME' already exists."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# The system LibreSSL writes a PKCS#12 that `security import` accepts as-is
# (Homebrew's OpenSSL 3 would need -legacy).
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -config "$tmp/cert.cnf" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
  -out "$tmp/identity.p12" -passout pass:menubarkit -name "$NAME"

security import "$tmp/identity.p12" -k "$KEYCHAIN" -P menubarkit -T /usr/bin/codesign >/dev/null
echo "Created signing certificate '$NAME' in the login keychain."

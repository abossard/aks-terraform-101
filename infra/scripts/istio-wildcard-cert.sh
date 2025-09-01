#!/usr/bin/env bash

# Purpose: Create or update a self-signed wildcard certificate for *.${BASE_DOMAIN} and store it
#          as a Kubernetes TLS secret for Istio Gateway usage.
#
# The script is idempotent: it will always (re)generate the certificate locally and then apply the
# secret (kubectl apply). If you only want to re-create when expiring, you can extend with a date check.
#
# Requirements:
#  - openssl
#  - kubectl (current context pointing at the desired cluster)
#  - bash >= 4
#
# Usage:
#   ./istio-wildcard-cert.sh \
#       --base-domain yourdomain.com \
#       --namespace aks-istio \
#       --secret-name istio-wildcard-cert \
#       [--days 365] [--cert-dir ./cert-artifacts]
#
# Gateway YAML should set: tls.credentialName: <secret-name>
# The secret must exist in the SAME namespace as the Gateway resource.

BASE_DOMAIN=""
NAMESPACE="aks-istio"
SECRET_NAME="istio-wildcard-cert"
DAYS=365
CERT_DIR="./cert-artifacts"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-domain)
      BASE_DOMAIN="$2"; shift 2 ;;
    --namespace)
      NAMESPACE="$2"; shift 2 ;;
    --secret-name)
      SECRET_NAME="$2"; shift 2 ;;
    --days)
      DAYS="$2"; shift 2 ;;
    --cert-dir)
      CERT_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BASE_DOMAIN" ]]; then
  echo "--base-domain is required" >&2
  exit 1
fi

mkdir -p "$CERT_DIR"
KEY_FILE="$CERT_DIR/wildcard-${BASE_DOMAIN//./_}.key"
CRT_FILE="$CERT_DIR/wildcard-${BASE_DOMAIN//./_}.crt"
OPENSSL_CNF="$CERT_DIR/openssl-${BASE_DOMAIN//./_}.cnf"

cat > "$OPENSSL_CNF" <<EOF
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
CN = *.${BASE_DOMAIN}
O  = Example Org
OU = Demo

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.${BASE_DOMAIN}
DNS.2 = ${BASE_DOMAIN}
EOF

echo "Generating self-signed wildcard certificate for *.${BASE_DOMAIN} (${DAYS} days)"
openssl req -x509 -nodes -newkey rsa:2048 -days "$DAYS" \
  -keyout "$KEY_FILE" -out "$CRT_FILE" -config "$OPENSSL_CNF" >/dev/null 2>&1

echo "Creating/Updating namespace '$NAMESPACE' (if missing)"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

echo "Applying TLS secret '$SECRET_NAME' in namespace '$NAMESPACE'"
kubectl create secret tls "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --cert "$CRT_FILE" --key "$KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done. Secret details:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml | grep -E 'name:|type:'
echo "Certificate (subject):"; openssl x509 -in "$CRT_FILE" -noout -subject
echo "Certificate (SAN):";    openssl x509 -in "$CRT_FILE" -noout -ext subjectAltName | sed 's/.*, //'

echo "Next: Reference credentialName: $SECRET_NAME in your Istio Gateway in namespace $NAMESPACE."

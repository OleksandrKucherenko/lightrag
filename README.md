# Light RAG in docker container

## SSL Certificates

```bash
cd docker/certificates
# install root certificates
CAROOT=$(pwd) mkcert -install

# re-generate certificate 
CAROOT=$(pwd) mkcert -cert-file dev.localhost.pem \
  -key-file dev.localhost-key.pem \
  -p12-file dev.localhost.p12 \
  dev.localhost "*.dev.localhost" \
  localhost 127.0.0.1 0.0.0.0 ::1

# prepare for Windows HOST machine
openssl x509 -outform der -in rootCA.pem -out rootCA.crt
openssl x509 -inform PEM -in rootCA.pem -outform DER -out rootCA.cer

# Generate windows compatible certificate format, PFX is PKCS12 format
openssl pkcs12 -export -out dev.localhost.pfx -inkey dev.localhost-key.pem -in dev.localhost.pem -certfile rootCA.pem -passout "pass:"
```

In Powershell Admin:

```pwsh
 Import-Certificate -FilePath rootCA.cer -CertStoreLocation Cert:\LocalMachine\Root
```

## Caddy

```bash
# Validate configuration
docker run --rm \
    -v "$(pwd)/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
    lucaslorentz/caddy-docker-proxy:latest \
    validate \
    --config /etc/caddy/Caddyfile

# Examine logs
docker compose logs proxy

# Test URL
curl -s http://localhost/debug
curl -s http://localhost/health
curl -s http://localhost/
```

## Lazydocker Web UI

```bash
# encode password `admin`
docker run --rm caddy:2-alpine caddy hash-password --plaintext admin

# Test Url
curl -v http://monitor.dev.localhost --user admin:admin
 ```
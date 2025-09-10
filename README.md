# Light RAG in docker container

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/OleksandrKucherenko/lightrag)

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

```powershell
cd docker\certificates
# register certificate in 
sudo Import-Certificate -FilePath rootCA.cer -CertStoreLocation Cert:\LocalMachine\Root
```

After installation use `chrome://restart` to force Chrome to reload CA certificates.

After sharing the rootCA in project don't forget to reset own root certificate for `mkcert` tool:

```bash
# On macOS/Linux
rm -rf "$(mkcert -CAROOT)"

# On Windows (PowerShell)
Remove-Item -Recurse -Force "$(mkcert -CAROOT)"

# one line that doing all
mkcert -uninstall && rm -rf "$(mkcert -CAROOT)" && mkcert -install
```

## DNS Setup

### Windows

Edit file: `C:\Windows\System32\drivers\etc\hosts` 
```
# Added by Docker Desktop
192.168.1.103 host.docker.internal
192.168.1.103 gateway.docker.internal

# Required
192.168.1.103 dev.localhost
192.168.1.103 monitor.dev.localhost
192.168.1.103 kv.dev.localhost
192.168.1.103 graph.dev.localhost
192.168.1.103 *.dev.localhost
```

```bash
docker run --rm alpine sh -c "ip route | awk '/default/ { print \$3 }'"
```

## Secrets

We use MISE tool secrets support: https://mise.jdx.dev/environments/secrets.html

```shell
# install globally tools required for encryption/decryption
mise use -g sops
mise use -g age

# generate unique key for project
age-keygen -o .secrets/mise-age.txt
# Expected output:
#  Public key: <public key>

# make a copy, so mise can find it automatically (or better setup SOPS_AGE_KEY_FILE variable)
cp .secrets/mise-age.txt %HOME%/.config/mise/age.txt

# Encrypt JSON file (`-i` means in-place, so file will be replaced by encrypted version)
sops encrypt -i --age "<public key>" .env.llm.json
```

You can later decrypt the file with `sops decrypt -i .env.json` or edit it in EDITOR with `sops edit .env.json`. However, you'll first need to set `SOPS_AGE_KEY_FILE` to `~/.config/mise/age.txt` to decrypt the file.

## Caddy

```bash
# Validate configuration
docker run --rm \
    -v "$(pwd)/docker/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
    lucaslorentz/caddy-docker-proxy:latest \
    validate \
    --config /etc/caddy/Caddyfile

# Examine logs
docker compose logs proxy

# Test URL
curl -s http://dev.localhost/debug
curl -s http://dev.localhost/health
curl -s http://dev.localhost/
```

## Lazydocker Web UI

```bash
# encode password `admin`
docker run --rm caddy:2-alpine caddy hash-password --plaintext admin

# Test Url
curl -v http://monitor.dev.localhost --user admin:admin
 ```

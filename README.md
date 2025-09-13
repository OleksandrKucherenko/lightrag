# Light RAG in docker container

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/OleksandrKucherenko/lightrag)

- [Light RAG in docker container](#light-rag-in-docker-container)
  - [Developer Environment setup](#developer-environment-setup)
    - [Mise Tool Setup](#mise-tool-setup)
      - [Windows](#windows)
      - [Linux/MacOS/WSL2](#linuxmacoswsl2)
    - [SSL Certificates](#ssl-certificates)
      - [Security Risks](#security-risks)
    - [DNS Setup](#dns-setup)
      - [Windows](#windows-1)
      - [Configure DNS via hostctl](#configure-dns-via-hostctl)
      - [From WSL2: publish subdomains to Windows hosts via hostctl (auto)](#from-wsl2-publish-subdomains-to-windows-hosts-via-hostctl-auto)
    - [LLM Secrets](#llm-secrets)
  - [Services](#services)
    - [Caddy](#caddy)
    - [Lazydocker Web UI](#lazydocker-web-ui)
    - [Open WebUI](#open-webui)


## Developer Environment setup

Minimalistic Developer environment setup is required to make this solution work. Step:

1. install `mise`
2. configure DNS
3. install self-signed certificates
4. inject OpenAI llm secrets in a secure way

### Mise Tool Setup

#### Windows

```shell
# install scoop 
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# install mise tool
scoop install mise

# restart powershell terminal to apply all global environment changes (if you run it in VSCODE, you will need to restart the VSCODE process)

cd lightrag # enter project folder 

# MISE should automatically execute setup task if all configured properly
mise trust # may required on first run
```

#### Linux/MacOS/WSL2

```bash
# install BREW tool, ref: https://brew.sh/
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install mise tool
brew install mise

cd lightrag
mise trust
```

### SSL Certificates

We use self-signed certificates that are created and managed by `mkcert` tool. (MISE tool force it automatic installation)

All certificates are already included into project, but you may want to regenerate them for reducing any security risks.

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

#### Security Risks

After sharing the rootCA in project don't forget to reset own root certificate for `mkcert` tool:

```bash
# On macOS/Linux
rm -rf "$(mkcert -CAROOT)"

# On Windows (PowerShell)
Remove-Item -Recurse -Force "$(mkcert -CAROOT)"

# one line that doing all
mkcert -uninstall && rm -rf "$(mkcert -CAROOT)" && mkcert -install
```

### DNS Setup

Recommended tool: https://guumaster.github.io/hostctl/docs/getting-started/ (should be installed automatically by MISE)

```shell
# Windows
scoop install main/hostctl
scoop install main/gsudo # SUDO tool required for elevating the access

# Linux, macos
brew install guumaster/tap/hostctl
```

`.etchosts` is a helper for this project that contains mapping of the domains to `127.0.0.1`.

#### Windows

Edit file: `C:\Windows\System32\drivers\etc\hosts` 

```txt
# Added by Docker Desktop
192.168.1.103 host.docker.internal
192.168.1.103 gateway.docker.internal

# Required
192.168.1.103 dev.localhost
192.168.1.103 monitor.dev.localhost
192.168.1.103 kv.dev.localhost
192.168.1.103 graph.dev.localhost
192.168.1.103 rag.dev.localhost

# Pattern:
# 192.168.1.103 *.dev.localhost
```

```bash
# find the docker host IP
docker run --rm alpine sh -c "ip route | awk '/default/ { print \$3 }'"
```

#### Configure DNS via hostctl

```shell
# create configuration/profile 'lightrag' from provided file
sudo hostctl replace lightrag --from .etchosts

# disable configuration/profile
sudo hostctl disable lightrag

# enable configuration
sudo hostctl enable lightrag
```

Inside `C:/Windows/System32/Drivers/etc/hosts` file you can find:

```txt
##################################################################
# Content under this line is handled by hostctl. DO NOT EDIT.
##################################################################

# profile.on lightrag
127.0.0.1 dev.localhost
127.0.0.1 monitor.dev.localhost
127.0.0.1 kv.dev.localhost
127.0.0.1 graph.dev.localhost
127.0.0.1 rag.dev.localhost
# end
```

#### From WSL2: publish subdomains to Windows hosts via hostctl (auto)

Use this when running inside WSL2 to automatically detect your Windows LAN IP from the diagnostics report, transform `.etchosts` to use that IP (instead of `127.0.0.1`), and publish it to the Windows `hosts` file using `hostctl` with elevation via `sudo`.

Prerequisites (in Windows PowerShell):

```shell
scoop install main/hostctl
scoop install main/gsudo
```

Run in WSL2 at the project root:

```bash
# 1) Detect Windows LAN IP from diagnostics (strip ANSI color codes safely)
WIN_LAN_IP=$(bash bin/diag.wsl2.sh | sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' | awk '/Windows LAN IP/ {print $1; exit}')

# 2) Prepare a temp file visible to Windows with the IP substituted
WSL_TMP="/mnt/c/Temp/lightrag-hosts.txt"
WIN_TMP="C:\\Temp\\lightrag-hosts.txt"
mkdir -p /mnt/c/Temp
sed "s/127\\.0\\.0\\.1/${WIN_LAN_IP}/g" .etchosts > "$WSL_TMP"

# 3) Publish to Windows hosts with elevation (UAC prompt may appear once)
powershell.exe -NoProfile -Command "sudo hostctl replace lightrag --from \"$WIN_TMP\"; sudo hostctl enable lightrag"

# Optional: verify
powershell.exe -NoProfile -Command "Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts | Select-String -NotMatch '^#|^$'"
```

One‑liner version:

```bash
WIN_LAN_IP=$(bash bin/diag.wsl2.sh | sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' | awk '/Windows LAN IP/ {print $1; exit}'); \
  WSL_TMP="/mnt/c/Temp/lightrag-hosts.txt"; \
  WIN_TMP="C:\\Temp\\lightrag-hosts.txt"; \
  mkdir -p /mnt/c/Temp; sed "s/127\\.0\\.0\\.1/${WIN_LAN_IP}/g" .etchosts > "$WSL_TMP"; \
  powershell.exe -NoProfile -Command "sudo hostctl replace lightrag --from \"$WIN_TMP\"; sudo hostctl enable lightrag"; \
  powershell.exe -NoProfile -Command "Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts | Select-String -NotMatch '^#|^$'"
```

Notes:
- The IP is taken from the diagnostics section where entries are annotated as `Windows LAN IP (Wi‑Fi/Ethernet)`.
- If `WIN_LAN_IP` ends up empty, ensure `powershell.exe` is available from WSL and that the diagnostics show a `Windows LAN IP` entry.
- `sudo` will request elevation the first time; keep the window focused to accept the UAC prompt.

### LLM Secrets

We use MISE tool secrets support: https://mise.jdx.dev/environments/secrets.html

You will need OpenAI api key with enabled access to embedding and chat models. Open https://platform.openai.com/api-keys and create a new API key.

```shell
# install globally tools required for encryption/decryption
mise use -g sops
mise use -g age

# generate unique key for the project (it is your personal key, DO NOT SHARE IT !!!)
age-keygen -o .secrets/mise-age.txt
# Expected output:
#  Public key: <public key>

# make a copy, so mise can find it automatically (or better setup SOPS_AGE_KEY_FILE variable)
cp .secrets/mise-age.txt %HOME%/.config/mise/age.txt

# You can use .env.llm.example.json for composing own secrets storage and then simply encrypt it

# Encrypt JSON file (`-i` means in-place, so file will be replaced by encrypted version)
sops encrypt -i --age "<public key>" .env.llm.json

```

You can later decrypt the file with `sops decrypt -i .env.json` or edit it in EDITOR with `sops edit .env.json`. 
However, you'll first need to set `SOPS_AGE_KEY_FILE` to `~/.config/mise/age.txt` to decrypt the file.
This is already done by MISE tool for you.

## Services

### Caddy

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

### Lazydocker Web UI

```bash
# encode password `admin`
docker run --rm caddy:2-alpine caddy hash-password --plaintext admin

# Test Url
curl -v http://monitor.dev.localhost --user admin:admin
 ```

### Open WebUI

```bash
# verify connections
docker compose exec webui python -c "import requests; print('RAG API Status:', requests.get('http://rag:9621/health').status_code)" 2>/dev/null || echo "Testing internal connectivity..."

# Verify Caddy redirect
curl -s -o /dev/null -w "%{http_code}" http://webui.dev.localhost || echo "DNS or Caddy routing issue"

# Verify webui
curl -k -s -o /dev/null -w "%{http_code}" https://webui.dev.localhost || echo "HTTPS issue"
```
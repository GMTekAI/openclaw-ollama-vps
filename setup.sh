#!/usr/bin/env bash
# openclaw-ollama-vps setup script
# Installs Ollama and pulls recommended models on a fresh VPS

set -e

echo "==> Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "==> Configuring Ollama to accept external connections..."
# Add OLLAMA_HOST and OLLAMA_ORIGINS so OpenClaw (and other clients)
# can reach the API from outside localhost.
# Without this, Ollama binds to 127.0.0.1 only and external requests fail.
OLLAMA_SERVICE=/etc/systemd/system/ollama.service
if ! grep -q "OLLAMA_HOST" "$OLLAMA_SERVICE"; then
  sed -i 's|Environment="PATH=|Environment="OLLAMA_HOST=0.0.0.0"\nEnvironment="OLLAMA_ORIGINS=*"\nEnvironment="PATH=|' "$OLLAMA_SERVICE"
  echo "  OLLAMA_HOST=0.0.0.0 and OLLAMA_ORIGINS=* added to service."
else
  echo "  OLLAMA_HOST already set, skipping."
fi

echo "==> Fixing systemd-resolved DNS stability..."
# Prevents a known crash: Assertion 's->read_packet->family == AF_INET6' failed
# in systemd-resolved when DNS-over-TCP IPv6 streams are used.
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/disable-dns-tcp.conf << 'EOF'
[Resolve]
DNSOverTLS=no
EOF
systemctl restart systemd-resolved

echo "==> Enabling Ollama as a systemd service..."
systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

echo "==> Waiting for Ollama to be ready..."
for i in $(seq 1 10); do
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "  Ollama is up."
    break
  fi
  echo "  Waiting... ($i/10)"
  sleep 3
done

echo ""
echo "==> Choose a model to pull:"
echo "   1) llama3.1:8b   (~4.9 GB, good general-purpose, recommended)"
echo "   2) llama3.2:3b   (~2.0 GB, lighter, faster on low-RAM VPS)"
echo "   3) qwen2.5:7b    (~4.7 GB, strong coding + reasoning)"
echo "   4) Skip (pull manually with: ollama pull <model>)"
echo ""
read -rp "Enter choice [1-4]: " choice

CHOSEN_MODEL=""
case $choice in
  1) ollama pull llama3.1:8b && CHOSEN_MODEL="llama3.1:8b" ;;
  2) ollama pull llama3.2:3b && CHOSEN_MODEL="llama3.2:3b" ;;
  3) ollama pull qwen2.5:7b && CHOSEN_MODEL="qwen2.5:7b" ;;
  4) echo "Skipping model pull." ;;
  *) echo "Invalid choice, skipping." ;;
esac

echo ""
echo "==> Ollama setup complete."
echo "   API available at: http://localhost:11434"
echo "   External API:     http://$(hostname -I | awk '{print $1}'):11434"
echo ""
echo "==> Configuring OpenClaw to use local Ollama mode..."
openclaw config set gateway.mode local
openclaw config set provider ollama
if [ -n "$CHOSEN_MODEL" ]; then
  openclaw config set agents.defaults.model.primary "ollama/$CHOSEN_MODEL"
  echo "   Primary model set to: ollama/$CHOSEN_MODEL"
fi
echo ""

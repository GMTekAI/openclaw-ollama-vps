#!/usr/bin/env bash
# openclaw-ollama-vps setup script
# Installs Ollama and pulls recommended models on a fresh VPS

set -e

echo "==> Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "==> Enabling Ollama as a systemd service..."
systemctl enable ollama
systemctl start ollama

echo "==> Waiting for Ollama to be ready..."
for i in $(seq 1 10); do
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "   Ollama is up."
    break
  fi
  echo "   Waiting... ($i/10)"
  sleep 3
done

echo ""
echo "==> Choose a model to pull:"
echo "   1) llama3.1:8b  (~4.9 GB, good general-purpose, recommended)"
echo "   2) llama3.2:3b  (~2.0 GB, lighter, faster on low-RAM VPS)"
echo "   3) qwen2.5:7b   (~4.7 GB, strong coding + reasoning)"
echo "   4) Skip (pull manually with: ollama pull <model>)"
echo ""
read -rp "Enter choice [1-4]: " choice

case $choice in
  1) ollama pull llama3.1:8b ;;
  2) ollama pull llama3.2:3b ;;
  3) ollama pull qwen2.5:7b ;;
  4) echo "Skipping model pull." ;;
  *) echo "Invalid choice, skipping." ;;
esac

echo ""
echo "==> Ollama setup complete."
echo "    API available at: http://localhost:11434"
echo ""
echo "==> Next: configure OpenClaw to use local mode:"
echo "    openclaw config set gateway.mode local"
echo "    openclaw config set provider ollama"
echo ""

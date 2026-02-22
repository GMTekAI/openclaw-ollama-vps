# openclaw-ollama-vps

Run [OpenClaw](https://github.com/openclaw/openclaw) with **local Ollama models** on a Hostinger VPS  zero API costs, full privacy, runs 24/7.

This integration lets you swap out paid API providers (OpenAI, Anthropic, etc.) for self-hosted LLMs via [Ollama](https://ollama.com), running on your own VPS. Once set up, OpenClaw agents call your local model instead of a cloud API.

---

## Why

- **No API costs**  run unlimited agent sessions once the VPS is paid for
- **Privacy**  your prompts never leave your server
- **Always on**  Ollama runs as a systemd service, restarts automatically
- **Compatible**  uses OpenClaw's existing `gateway.mode=local` provider architecture

---

## Requirements

- A VPS with at least **8 GB RAM** (16 GB recommended for 8B models)
- Ubuntu 22.04 or Debian 12
- OpenClaw installed and authenticated (`openclaw login`)
- `systemd` available (standard on Hostinger VPS plans)

### Recommended Hostinger VPS Plans

| Plan | RAM  | Recommended Model      |
|------|------|------------------------|
| KVM2 | 8 GB | `llama3.2:3b`          |
| KVM4 | 16 GB| `llama3.1:8b`        |
| KVM8 | 32 GB| `qwen2.5:14b` or larger|

---

## Quick Start

### 1. Install Ollama

Run the setup script (interactive  picks your model):

```bash
curl -fsSL https://raw.githubusercontent.com/GMTekAI/openclaw-ollama-vps/main/setup.sh | bash
```

Or do it manually:

```bash
curl -fsSL https://ollama.com/install.sh | sh
systemctl enable ollama && systemctl start ollama
ollama pull llama3.1:8b
```

### 2. Verify Ollama is running

```bash
systemctl status ollama
curl http://localhost:11434/api/tags
```

You should see your pulled models listed in the JSON response.

### 3. Configure OpenClaw to use local mode

```bash
openclaw config set gateway.mode local
openclaw config set provider ollama
```

Confirm with:

```bash
openclaw config get gateway.mode
# local
```

### 4. Test inference end-to-end

```bash
curl -s http://localhost:11434/api/generate \
  -d '{"model":"llama3.1:8b","prompt":"Reply with just OK","stream":false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

Then run an OpenClaw agent normally  it will use your local model automatically.

---

## How It Works

OpenClaw's provider system supports a `gateway.mode=local` flag that routes inference requests to Ollama's `/api/chat` endpoint instead of a remote API. The `src/ollama-stream.ts` file in this repo is the stream adapter that translates OpenClaw's internal message format to Ollama's NDJSON chat API format and back.

Key behaviours:
- Handles streaming via NDJSON chunked responses
- Supports tool calls (function calling) if the model supports it
- Falls back gracefully on models with no tool support
- Passes `num_ctx` from the model's `contextWindow` config (defaults to 65536)
- Handles Qwen3-style `reasoning` field in addition to `content`

---

## Switching Models

List available models:
```bash
ollama list
```

Pull a new model:
```bash
ollama pull qwen2.5:7b
```

Update your OpenClaw config to use it  edit `~/.openclaw/config.json` or check `openclaw config set` docs.

---

## Keeping Ollama Updated

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Re-running the installer updates Ollama in place. Your pulled models are preserved.

---

---

## Troubleshooting

### OpenClaw cannot connect to Ollama ("connection refused" / "ECONNREFUSED")

By default Ollama binds to `127.0.0.1:11434` (localhost only). If OpenClaw is running on a different machine or hitting the VPS IP directly, requests will be refused.

**Fix:** set `OLLAMA_HOST=0.0.0.0` in the Ollama systemd service so it listens on all interfaces:

```bash
# Edit the service file
sudo sed -i 's|Environment="PATH=|Environment="OLLAMA_HOST=0.0.0.0"\nEnvironment="OLLAMA_ORIGINS=*"\nEnvironment="PATH=|' /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Verify it is now bound to all interfaces (should show *:11434)
ss -tlnp | grep 11434
```

The updated `setup.sh` in this repo does this automatically on fresh installs.

### Intermittent DNS failures / outbound requests timing out

On Ubuntu 22.04 / 24.04 with `systemd 255`, `systemd-resolved` can crash with:

```
Assertion 's->read_packet->family == AF_INET6' failed  Aborting.
```

This kills DNS resolution until the service auto-restarts, causing transient failures when Ollama tries to pull models or when the VPS makes any outbound HTTP request.

**Fix:** disable DNS-over-TLS streaming (which triggers the IPv6 assertion bug):

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/disable-dns-tcp.conf << 'EOF'
[Resolve]
DNSOverTLS=no
EOF
sudo systemctl restart systemd-resolved
```

The updated `setup.sh` applies this fix automatically.

## Contributing / Submitting Upstream

This repo is intended as a reference implementation and deployment guide. If you adapt it, fix bugs, or add support for new model behaviours, please:

1. Fork this repo
2. Make your changes
3. Open a PR here, or open an issue/PR on the [main OpenClaw repo](https://github.com/openclaw/openclaw) to discuss merging the provider upstream

---

## License

MIT  see [LICENSE](LICENSE)

#!/bin/bash
# gpu-droplet.sh — Spin up/down an on-demand GPU droplet with ollama
#
# The droplet joins the Tailscale mesh, so it's accessible from server and phone.
# Billing is per-second (5-min minimum). Shut it down when you're done.
#
# Usage:
#   gpu-droplet.sh up              # Create GPU droplet, install ollama, join Tailscale
#   gpu-droplet.sh down            # Destroy the droplet (stops billing)
#   gpu-droplet.sh status          # Check if running
#   gpu-droplet.sh ssh             # SSH into the GPU droplet
#   gpu-droplet.sh query "prompt"  # Send a query to the GPU droplet's ollama
#
# Cost: ~$0.76/hr (RTX 4000 Ada, 20GB VRAM)
#       ~$1.57/hr (L40S, 48GB VRAM — runs 70B)

set -euo pipefail

DROPLET_NAME="vorkosigan-gpu"
REGION="nyc2"
# RTX 4000 Ada: 20GB VRAM, $0.76/hr — runs 13B-30B
# L40S: 48GB VRAM, $1.57/hr — runs 70B comfortably
# H100: 80GB VRAM, $3.39/hr — runs 70B at full precision
GPU_SIZE="${GPU_SIZE:-gpu-4000adax1-20gb}"
IMAGE="gpu-h100x1-base"  # NVIDIA AI/ML Ready base image
SSH_KEY_IDS=$(doctl compute ssh-key list --format ID --no-header | tr '\n' ',' | sed 's/,$//')
MODEL="${GPU_MODEL:-llama3.2:13b}"
OLLAMA_PORT=11434

# Tailscale auth key — set this or it will prompt
# Generate at: https://login.tailscale.com/admin/settings/keys
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

get_droplet_id() {
    doctl compute droplet list --format Name,ID --no-header 2>/dev/null | \
        grep "^${DROPLET_NAME}" | awk '{print $2}'
}

get_droplet_ip() {
    doctl compute droplet get "$(get_droplet_id)" --format PublicIPv4 --no-header 2>/dev/null
}

get_tailscale_ip() {
    # Check if the GPU droplet is on our Tailscale network
    tailscale status 2>/dev/null | grep "$DROPLET_NAME" | awk '{print $1}'
}

cmd_up() {
    local existing
    existing=$(get_droplet_id)
    if [ -n "$existing" ]; then
        log "GPU droplet already running (ID: $existing)"
        log "Tailscale IP: $(get_tailscale_ip || echo 'not yet on mesh')"
        log "Public IP: $(get_droplet_ip)"
        return 0
    fi

    if [ -z "$TAILSCALE_AUTH_KEY" ]; then
        echo "TAILSCALE_AUTH_KEY not set."
        echo "Generate one at: https://login.tailscale.com/admin/settings/keys"
        echo "Then: TAILSCALE_AUTH_KEY=tskey-auth-xxx gpu-droplet.sh up"
        exit 1
    fi

    log "Creating GPU droplet ($GPU_SIZE in $REGION)..."
    log "Cost: billing starts now, per-second"

    # Cloud-init script to install ollama, join Tailscale, pull model
    local user_data
    user_data=$(cat <<'CLOUD_INIT'
#!/bin/bash
set -e

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey=TAILSCALE_KEY --hostname=vorkosigan-gpu

# Install ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Wait for ollama to start
sleep 5

# Pull the model
ollama pull MODEL_NAME

# Signal ready
touch /tmp/gpu-ready
CLOUD_INIT
)

    # Substitute variables into cloud-init
    user_data="${user_data//TAILSCALE_KEY/$TAILSCALE_AUTH_KEY}"
    user_data="${user_data//MODEL_NAME/$MODEL}"

    doctl compute droplet create "$DROPLET_NAME" \
        --region "$REGION" \
        --size "$GPU_SIZE" \
        --image "$IMAGE" \
        --ssh-keys "$SSH_KEY_IDS" \
        --user-data "$user_data" \
        --tag-names "gpu,ollama,vorkosigan" \
        --wait

    log "Droplet created. Waiting for Tailscale join and model pull..."
    log "This takes 3-5 minutes (mostly model download)."

    # Wait for Tailscale IP to appear
    local ts_ip=""
    for i in $(seq 1 60); do
        ts_ip=$(get_tailscale_ip)
        if [ -n "$ts_ip" ]; then
            break
        fi
        sleep 10
    done

    if [ -n "$ts_ip" ]; then
        log "GPU droplet on Tailscale: $ts_ip"
        log "ollama API: http://$ts_ip:$OLLAMA_PORT"
        log ""
        log "Test: curl http://$ts_ip:$OLLAMA_PORT/api/tags"
        log "Query: gpu-droplet.sh query 'hello'"
        log "SSH:   gpu-droplet.sh ssh"
        log "Stop:  gpu-droplet.sh down"
    else
        log "WARNING: Tailscale join timed out. Check manually:"
        log "  Public IP: $(get_droplet_ip)"
        log "  SSH: ssh root@$(get_droplet_ip)"
    fi
}

cmd_down() {
    local id
    id=$(get_droplet_id)
    if [ -z "$id" ]; then
        log "No GPU droplet running."
        return 0
    fi

    log "Destroying GPU droplet (ID: $id)..."
    log "Billing stops now."
    doctl compute droplet delete "$id" --force
    log "Destroyed. $0.00/hr from now."
}

cmd_status() {
    local id
    id=$(get_droplet_id)
    if [ -z "$id" ]; then
        echo "GPU droplet: not running"
        return 0
    fi

    local ts_ip
    ts_ip=$(get_tailscale_ip)
    echo "GPU droplet: RUNNING"
    echo "  ID: $id"
    echo "  Size: $GPU_SIZE"
    echo "  Public IP: $(get_droplet_ip)"
    echo "  Tailscale IP: ${ts_ip:-not on mesh}"
    echo "  ollama: http://${ts_ip:-$(get_droplet_ip)}:$OLLAMA_PORT"
    echo "  Cost: accruing at $GPU_SIZE rate"
}

cmd_ssh() {
    local ts_ip
    ts_ip=$(get_tailscale_ip)
    if [ -n "$ts_ip" ]; then
        ssh "root@$ts_ip"
    else
        local ip
        ip=$(get_droplet_ip)
        if [ -n "$ip" ]; then
            ssh "root@$ip"
        else
            echo "No GPU droplet running."
            exit 1
        fi
    fi
}

cmd_query() {
    local prompt="$*"
    local ts_ip
    ts_ip=$(get_tailscale_ip)
    if [ -z "$ts_ip" ]; then
        echo "GPU droplet not on Tailscale mesh. Is it running?"
        exit 1
    fi

    curl -s "http://$ts_ip:$OLLAMA_PORT/api/generate" \
        -d "$(jq -n --arg model "$MODEL" --arg prompt "$prompt" \
            '{model: $model, prompt: $prompt, stream: false}')" | \
        jq -r '.response'
}

# --- Main ---
case "${1:-}" in
    up)     cmd_up ;;
    down)   cmd_down ;;
    status) cmd_status ;;
    ssh)    cmd_ssh ;;
    query)  shift; cmd_query "$@" ;;
    *)
        echo "Usage: gpu-droplet.sh {up|down|status|ssh|query \"prompt\"}"
        echo ""
        echo "Environment variables:"
        echo "  GPU_SIZE=gpu-l40sx1-48gb    # Override GPU tier (default: RTX 4000 Ada)"
        echo "  GPU_MODEL=llama3:70b        # Override model (default: llama3.2:13b)"
        echo "  TAILSCALE_AUTH_KEY=tskey-... # Required for 'up' (generate at Tailscale admin)"
        exit 1
        ;;
esac

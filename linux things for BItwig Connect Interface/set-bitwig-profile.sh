#!/usr/bin/env bash
# Wait for Bitwig Connect ALSA and PipeWire device, then set profile

set -e

LOG_TAG="[bitwig-connect]"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=0.5

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*"
}

# Wait for ALSA control device
wait_for_alsa() {
    local attempt=0
    while [ ! -e /dev/snd/controlC2 ] && [ $attempt -lt $MAX_ATTEMPTS ]; do
        log "Waiting for ALSA control device /dev/snd/controlC2..."
        attempt=$((attempt + 1))
        sleep $SLEEP_INTERVAL
    done
    if [ ! -e /dev/snd/controlC2 ]; then
        log "ALSA control device not found after $((MAX_ATTEMPTS*SLEEP_INTERVAL)) seconds"
        return 1
    fi
    log "ALSA control device found: /dev/snd/controlC2"
}

# Wait for PipeWire object
wait_for_pipewire() {
    local attempt=0
    local id=""
    while [ $attempt -lt $MAX_ATTEMPTS ]; do
        id=$(pw-cli ls | awk '
            /^\s*id [0-9]+,/ {split($2,a,","); id=a[1]; desc=0; cls=0}
            /device.description *= *"Bitwig Connect"/ {desc=1}
            /media.class *= *"Audio\/Device"/ {cls=1}
            desc && cls {print id; exit}
        ')
        if [ -n "$id" ]; then
            echo "$id"
            return 0
        fi
        log "Waiting for Bitwig Connect PipeWire object..."
        attempt=$((attempt + 1))
        sleep $SLEEP_INTERVAL
    done
    return 1
}

# Set profile
set_profile() {
    local obj_id=$1
    log "Setting Bitwig Connect profile to pro-audio..."
    pw-cli set-param "$obj_id" 9 '{"name":"pro-audio"}'
    log "Profile set successfully."
}

main() {
    wait_for_alsa
    local obj_id
    obj_id=$(wait_for_pipewire)
    if [ -z "$obj_id" ]; then
        log "Error: Bitwig Connect PipeWire object not found after $((MAX_ATTEMPTS*SLEEP_INTERVAL)) seconds"
        exit 1
    fi
    set_profile "$obj_id"
}

main

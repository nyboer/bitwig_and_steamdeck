#!/usr/bin/env bash
# $1 is the device name, e.g., controlC2

USER=deck   # your login user
export XDG_RUNTIME_DIR="/run/user/$(id -u $USER)"

DEVICE="/dev/snd/$1"
MAX_WAIT=30   # max seconds to wait for ALSA and PipeWire
logger "[bitwig-connect] USB device detected ($DEVICE), starting initialization..."

# Wait for ALSA control device
SECONDS_WAITED=0
while [ ! -e "$DEVICE" ] && [ $SECONDS_WAITED -lt $MAX_WAIT ]; do
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
done

if [ ! -e "$DEVICE" ]; then
    logger "[bitwig-connect] Error: ALSA control device $DEVICE not found after $MAX_WAIT seconds"
    exit 1
fi
logger "[bitwig-connect] ALSA control device found: $DEVICE"

# Wait for PipeWire object
SECONDS_WAITED=0
OBJ_ID=""
while [ -z "$OBJ_ID" ] && [ $SECONDS_WAITED -lt $MAX_WAIT ]; do
    OBJ_ID=$(sudo -u $USER XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" pw-cli ls | awk '
        /^\s*id [0-9]+,/ {split($2,a,","); id=a[1]; desc=0; cls=0}
        /device.description *= *"Bitwig Connect"/ {desc=1}
        /media.class *= *"Audio\/Device"/ {cls=1}
        desc && cls {print id; exit}
    ')
    if [ -z "$OBJ_ID" ]; then
        sleep 1
        SECONDS_WAITED=$((SECONDS_WAITED + 1))
    fi
done

if [ -z "$OBJ_ID" ]; then
    logger "[bitwig-connect] Error: Bitwig Connect PipeWire object not found after $MAX_WAIT seconds"
    exit 1
fi
logger "[bitwig-connect] PipeWire object found: ID $OBJ_ID"

# Retry applying the Bitwig profile until it is confirmed
MAX_RETRIES=20
RETRY_INTERVAL=1
for i in $(seq 1 $MAX_RETRIES); do
    OUTPUT=$(sudo -u $USER XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /usr/local/bin/set-bitwig-profile.sh 2>&1)
    if echo "$OUTPUT" | grep -q "Profile set successfully"; then
        logger "[bitwig-connect] Profile applied successfully on attempt $i"
        exit 0
    else
        logger "[bitwig-connect] Attempt $i failed, retrying..."
        sleep $RETRY_INTERVAL
    fi
done

logger "[bitwig-connect] Error: Failed to apply Bitwig profile after $MAX_RETRIES attempts"
exit 1

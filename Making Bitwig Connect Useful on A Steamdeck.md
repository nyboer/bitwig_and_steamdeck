# Bitwig Connect Auto-Profile Setup

This document outlines the recommended approach to automatically set the Bitwig Connect audio interface to the `pro-audio` profile when it is connected. This approach ensures reliable detection of both ALSA and PipeWire before triggering the profile script.

---

## Overview

We want to achieve:

- Automatic detection of the Bitwig Connect USB interface.
- Automatic setting of the audio profile to `pro-audio`.
- Reliable initialization of both ALSA and PipeWire objects before the profile script is executed.
- Logging for debugging via `journalctl`.

**Key Points:**

- Using a udev rule to detect the device plug-in.
- A wrapper script handles retries for ALSA and PipeWire detection.
- The profile script is executed with the correct user environment (`XDG_RUNTIME_DIR`).

---

## 1. Profile script

This script is ultimately what sets the pro-audio profile for the Connect, so Bitwig will see 6 inputs and 12 outputs, instead of 0 inputs.
If nothing else, you can run this manually after you plug in the Connect and Bitwig will see all inputs.

Create the file:
```
sudo nano  /usr/local/bin/set-bitwig-profile.sh
```
and fill it with this script:
```
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
```
Make it executable:
```
sudo chmod +x /usr/local/bin/set-bitwig-profile.sh
```

## 2. udev Rule

Create the following file:
**`sudo nano /etc/udev/rules.d/99-bitwig-connect.rules`**

```text
# Trigger Bitwig Connect profile script on USB device add
SUBSYSTEM=="sound", ENV{ID_MODEL}=="Bitwig_Connect", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}="bitwig-connect@%k.service"
```
This tells udev: when the sound device appears, start a template service with the device name as instance.

###Explanation:

* SUBSYSTEM=="sound": Only trigger for sound devices.
* ENV{ID_MODEL}=="Bitwig_Connect": Match your Bitwig Connect interface.
* ACTION=="add": Trigger only on device addition.
* TAG+="systemd": Allow systemd to manage the device unit.
* ENV{SYSTEMD_WANTS}: Starts the corresponding template service for the device.

Reload udev rules after saving:
```
sudo udevadm control --reload
sudo udevadm trigger
```
## 3. Root-level systemd template service

Create the following file:

**`sudo nano /etc/systemd/system/bitwig-connect@.service`**

```
[Unit]
Description=Run Bitwig Connect profile script for %i
After=pipewire.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bitwig-connect-launch.sh %i
```

Explanation:
* %i is replaced by the device name (controlC2) from udev.
* Runs the wrapper script, which waits for both ALSA and PipeWire and applies the profile.
* Uses oneshot since it only needs to run once per device addition.

Reload systemd after creating the service:
```
sudo systemctl daemon-reload
```

## 4. Wrapper script

Create
**`sudo nano /usr/local/bin/bitwig-connect-launch.sh`**

```
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
```

Make it executable:
```
sudo chmod +x /usr/local/bin/bitwig-connect-launch.sh
```
## 5. Reload udev and systemd

```
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo udevadm trigger
```

## Results
Now, when you plug in the Bitwig Connect USB device:
* udev triggers the template service for that specific control device.
* The wrapper waits for ALSA and PipeWire to initialize.
* The set-bitwig-profile.sh script runs with proper environment.
* Logs appear in journalctl -f -t bitwig-connect.
This setup ensures:
* Automatic detection on USB plug.
* Reliable waiting for ALSA + PipeWire.
* Automatic profile application.
* Detailed logging for debugging.

## Troubleshoot
You can always view logs by starting
```
journalctl -f -t bitwig-connect
```
then plugging in the Connect.

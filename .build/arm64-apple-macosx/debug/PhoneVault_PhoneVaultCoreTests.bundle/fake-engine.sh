#!/bin/bash
# Fake libimobiledevice 1.4.0 tools for tests. Symlink names pick the tool; FAKE_MODE picks the behaviour.
name=$(basename "$0")
mode=${FAKE_MODE:-success}
udid=${FAKE_UDID:-00008110-FAKE}
state=${FAKE_STATE_DIR:-${TMPDIR:-/tmp}}
ios=${FAKE_IOS:-17.5}
delay=${FAKE_DELAY:-0.02}

log() { [ -n "$FAKE_LOG" ] && printf '%s\n' "$*" >> "$FAKE_LOG"; }

plist_info() {
cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>DeviceName</key><string>Teste</string>
<key>ProductType</key><string>iPhone10,4</string>
<key>ProductVersion</key><string>$ios</string>
<key>TotalDiskCapacity</key><integer>64000000000</integer>
<key>TotalDataCapacity</key><integer>59144826880</integer>
<key>TotalDataAvailable</key><integer>30570889216</integer>
</dict></plist>
EOF
}

write_meta() {
  local d=$1
  mkdir -p "$d/aa" "$d/bb" "$d/cc"
  cat > "$d/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>Unique Identifier</key><string>$udid</string></dict></plist>
EOF
  cat > "$d/Status.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>SnapshotState</key><string>finished</string></dict></plist>
EOF
  cat > "$d/Manifest.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict/></plist>
EOF
  /usr/bin/sqlite3 "$d/Manifest.db" "DROP TABLE IF EXISTS Files; CREATE TABLE Files(fileID TEXT, domain TEXT, relativePath TEXT, flags INTEGER, file BLOB); INSERT INTO Files VALUES('aa1','CameraRollDomain','a',1,NULL),('bb2','HomeDomain','b',1,NULL),('cc3','HomeDomain','c',1,NULL);"
  echo data > "$d/aa/aa1"
  echo data > "$d/bb/bb2"
  [ "$mode" = verifyMissingFile ] || echo data > "$d/cc/cc3"
}

case "$name" in
idevice_id)
  log "idevice_id $*"
  [ -f "$state/disconnected" ] && exit 0
  echo "$udid" ;;
idevicepair)
  log "idevicepair $*"
  case "$mode" in
    locked) echo "ERROR: device is locked with passcode"; exit 1 ;;
    denied) echo "ERROR: user denied trust"; exit 1 ;;
    needsTrust) echo "ERROR: device is not paired"; exit 1 ;;
  esac
  echo "SUCCESS: Validated pairing with device $udid" ;;
ideviceinfo)
  log "ideviceinfo $*"
  plist_info ;;
idevicebackup2)
  log "idevicebackup2 $*"
  case " $* " in *" restore "*)
    echo "Restoring"
    for i in 1 2 3 4 5 6 7 8 9 10; do
      case "$mode" in
        refuse) echo "ErrorCode 211: Find My iPhone must be disabled before restoring (MBErrorDomain/211)"; echo "Restore Failed (Error Code 211)."; exit 1 ;;
        protocol) echo "backup protocol version mismatch"; exit 1 ;;
        disconnect) [ $i = 5 ] && { touch "$state/disconnected"; exit 1; } ;;
        abort) [ $i = 5 ] && { echo "Restore Aborted."; exit 1; } ;;
        passcode) [ $i = 1 ] && echo "*** Waiting for passcode to be entered on the device ***" ;;
        alter) [ $i = 1 ] && echo changed > "${@: -1}/$udid/aa/aa1" ;;
      esac
      printf '\r[%-10s] %3d%%' "$(printf '=%.0s' $(seq 1 $i))" $((i * 10))
      sleep "$delay"
    done
    [ "$mode" = noSuccessLine ] && exit 0
    echo "Restore Successful."; exit 0 ;;
  esac
  dir=${@: -1}
  full=0; case " $* " in *" --full "*) full=1 ;; esac
  if [ $full = 1 ]; then echo "Full backup mode."; else echo "Incremental backup mode."; fi
  echo "Receiving files"
  dest="$dir/$udid"
  mkdir -p "$dest"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    case "$mode" in
      passcode) [ $i = 1 ] && echo "*** Waiting for passcode to be entered on the device ***" ;;
      crash) [ $i = 5 ] && exit 1 ;;
      disconnect) [ $i = 5 ] && { touch "$state/disconnected"; exit 1; } ;;
      cancelOnDevice) [ $i = 3 ] && { echo "User has cancelled the backup process on the device."; exit 1; } ;;
    esac
    printf '\r[%-10s] %3d%%' "$(printf '=%.0s' $(seq 1 $i))" $((i * 10))
    head -c 200000 /dev/zero > "$dest/pad-$i"
    sleep "$delay"
  done
  if [ "$mode" = exitZeroButFailed ]; then echo "Backup Failed (Error Code 1)."; exit 0; fi
  write_meta "$dest"
  echo " Finished"
  echo "Backup Successful."
  exit 0 ;;
*) exit 1 ;;
esac

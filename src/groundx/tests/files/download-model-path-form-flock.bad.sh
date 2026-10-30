flock "$lock" sh -c 'echo downloading'
flock -x "$lock" sh -c 'echo downloading'
flock -w 10 "$lock" sh -c 'echo downloading'
flock file sh -c 'echo downloading'
flock /abs/download.lock sh -c 'echo downloading'
    flock -s lockfile true
if flock "$lock" true; then :; fi

#!/bin/sh
LDCONFIG_PATHS="/host-sbin/ldconfig /host-usr-sbin/ldconfig /host-bin/ldconfig /host-usr-bin/ldconfig"

for path in $LDCONFIG_PATHS; do
  if [ -f "$path" ]; then
    echo "Found ldconfig at $path"
    cd "$(dirname "$path")" && ln -sf ldconfig /host-sbin/ldconfig.real
    break
  fi
done

if [ -L /host-sbin/ldconfig.real ]; then
  echo "Symbolic link created at /sbin/ldconfig.real"
else
  echo "Failed to find ldconfig in the specified paths."
fi
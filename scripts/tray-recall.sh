#!/usr/bin/env bash
# Brings back the tray icons of apps that were already running when the shell started.
# A new watcher starts with an empty list, and not every app registers again, so this looks
# for the items still on the session bus and registers the ones the watcher doesn't list.
watcher=org.kde.StatusNotifierWatcher
bus=org.freedesktop.DBus

known=$(busctl --user get-property $watcher /StatusNotifierWatcher $watcher RegisteredStatusNotifierItems) || exit 0

# Items can be listed under a well-known name, so compare the connections behind them
owners=$(for item in $(grep -o '"[^"/]*' <<< "$known" | tr -d '"'); do
    busctl --user call $bus /org/freedesktop/DBus $bus GetNameOwner s "$item" 2>/dev/null
done)

for name in $(busctl --user call $bus /org/freedesktop/DBus $bus ListNames | grep -o '":[^"]*"' | tr -d '"'); do
    [[ $owners == *"\"$name\""* ]] && continue
    # Some connections never answer, so each one gets a second at most
    if timeout 1 busctl --user get-property "$name" /StatusNotifierItem org.kde.StatusNotifierItem Id >/dev/null 2>&1; then
        busctl --user call $watcher /StatusNotifierWatcher $watcher RegisterStatusNotifierItem s "$name"
    fi
done

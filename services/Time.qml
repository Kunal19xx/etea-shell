pragma Singleton

import QtQuick
import Quickshell

// One clock for the whole shell. It looks every second, so it's right again the moment the
// machine wakes up: a timer set for the next minute or hour doesn't count the time asleep,
// and the widgets that had stayed up for days would show the night before.
Singleton {
    id: root

    property date now: new Date() // moves once a minute
    property date exact: new Date() // moves every second, for clocks that show them

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: {
            const time = new Date();
            root.exact = time;
            if (time.getMinutes() !== root.now.getMinutes() || Math.abs(time - root.now) >= 60000)
                root.now = time;
        }
    }
}

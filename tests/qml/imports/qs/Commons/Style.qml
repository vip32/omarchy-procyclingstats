pragma Singleton
import QtQuick
QtObject {
    function space(value) {return value}
    readonly property var font:({family:"monospace",body:14,caption:12,subtitle:16})
}

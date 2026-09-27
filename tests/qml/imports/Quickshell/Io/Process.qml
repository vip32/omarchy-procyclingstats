import QtQuick
QtObject {
    property bool running: false
    property var command: []
    property QtObject stdout
    signal exited(int code, int status)
}

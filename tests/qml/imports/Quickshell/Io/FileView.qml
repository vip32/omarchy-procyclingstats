import QtQuick
QtObject {
    property string path: ""
    signal loaded()
    function reload() {}
    function text() {return "{}"}
}

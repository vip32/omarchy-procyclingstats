import QtQuick
Item {
    property string text:""
    property bool bordered:false
    property color foreground:"white"
    signal clicked()
    implicitHeight:32
}

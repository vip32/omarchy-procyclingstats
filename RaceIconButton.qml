import QtQuick
import qs.Commons
import qs.Ui

// Keep icon geometry independent of glyph width and text-button padding.
Button {
    implicitWidth: Style.space(30)
    implicitHeight: implicitWidth
    iconSize: Style.space(16)
    horizontalPadding: 0
    verticalPadding: 0
    bordered: true
    Accessible.name: tooltipText
}

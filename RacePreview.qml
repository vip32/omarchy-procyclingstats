import QtQuick
import qs.Commons
import qs.Ui

Column {
    id:root
    property var detail: ({})
    property color foreground: Color.foreground
    readonly property color dim: Qt.darker(foreground,1.5)
    spacing:Style.space(12)
    Row {
        width:parent.width;spacing:Style.space(12)
        Column {
            width:(parent.width-Style.space(12))*0.65;spacing:Style.space(4)
            RaceText {text:"START · AS PUBLISHED BY PCS";font.pixelSize:Style.font.caption;color:root.dim}
            RaceText {width:parent.width;text:root.detail.startTime || "Not published";font.pixelSize:Style.font.subtitle;color:root.foreground;wrapMode:Text.WordWrap;elide:Text.ElideNone}
        }
        Column {
            width:(parent.width-Style.space(12))*0.35;spacing:Style.space(4)
            RaceText {text:"DISTANCE";font.pixelSize:Style.font.caption;color:root.dim}
            RaceText {text:root.detail.distance ? root.detail.distance+" km" : "—";font.pixelSize:Style.font.subtitle;color:root.foreground}
        }
    }
    RaceText {width:parent.width;visible:!!(root.detail.departure || root.detail.arrival);text:[root.detail.departure,root.detail.arrival].filter(Boolean).join(" → ");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground}
    Profile {width:parent.width;height:Style.space(75);visible:(root.detail.profile || []).length>0;points:root.detail.profile || [];lineColor:Color.accent}
    RaceText {width:parent.width;visible:!(root.detail.profile || []).length;text:"Course profile unavailable here. Open PCS with ↗.";font.pixelSize:Style.font.caption;color:root.dim;wrapMode:Text.WordWrap;elide:Text.ElideNone}
}

import QtQuick
import qs.Commons
import qs.Ui

CursorSurface {
    id: root
    property var group: ({})
    property color textColor: Color.foreground
    readonly property var riders: group.riders || []
    bordered: true
    foreground: textColor
    implicitHeight: body.implicitHeight + Style.space(20)
    height: implicitHeight
    Column {
        id:body
        x:Style.space(10);y:Style.space(10)
        width:parent.width-Style.space(20)
        spacing:Style.space(7)
        Item {
            width:parent.width;height:Style.space(22)
            RaceText {anchors.left:parent.left;anchors.right:gap.left;anchors.rightMargin:Style.space(8);text:(root.group.label || "Group")+(root.group.count ? " · "+root.group.count : "");font.bold:true;color:root.textColor}
            RaceText {id:gap;anchors.right:parent.right;text:(root.group.gap || "—")+(root.group.uncertain ? " ?" : "");font.bold:true;color:Color.accent}
        }
        Repeater {
            model:root.riders
            Row {
                required property var modelData
                width:parent.width;spacing:Style.space(10)
                RaceText {width:Style.space(34);text:modelData.bib || "";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5);horizontalAlignment:Text.AlignRight}
                RaceText {width:parent.width-Style.space(44);text:modelData.name || "";color:root.textColor}
            }
        }
        RaceText {visible:root.riders.length===0;width:parent.width;text:"Individual riders not listed by PCS";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
        RaceText {visible:Number(root.group.omitted || 0)>0;width:parent.width;text:"+"+root.group.omitted+" more riders · open PCS for the full group";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
    }
}

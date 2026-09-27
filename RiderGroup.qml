import QtQuick
import qs.Commons
import qs.Ui

CursorSurface {
    id: root
    property var group: ({})
    property color textColor: Color.foreground
    readonly property var riders: group.riders || []
    property bool showAll:false
    property string racePath:""
    onRacePathChanged:showAll=false
    onGroupChanged: if (riders.length<=4) showAll=false
    bordered: true
    foreground: textColor
    implicitHeight: body.implicitHeight + Style.space(20)
    height: implicitHeight
    Column {
        id:body
        x:Style.space(10);y:Style.space(10)
        width:parent.width-Style.space(20)
        spacing:Style.space(5)
        Item {
            width:parent.width;height:Style.space(22)
            RaceText {anchors.left:parent.left;anchors.right:gap.left;anchors.rightMargin:Style.space(8);text:(root.group.label || "Group")+(root.group.count ? " · "+root.group.count : "");font.bold:true;color:root.textColor}
            RaceText {id:gap;anchors.right:parent.right;text:(root.group.gap || "—")+(root.group.uncertain ? " ?" : "");font.bold:true;color:Color.accent}
        }
        Grid {
            width:parent.width;columns:width>Style.space(350) ? 2 : 1;spacing:Style.space(5)
            Repeater {
                model:root.showAll ? root.riders : root.riders.slice(0,4)
                Row {
                    required property var modelData
                    width:(parent.width-parent.spacing*(parent.columns-1))/parent.columns;spacing:Style.space(6)
                    RaceText {width:Style.space(26);text:modelData.bib || "";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5);horizontalAlignment:Text.AlignRight}
                    RaceText {width:parent.width-Style.space(32);text:modelData.name || "";font.pixelSize:Style.font.caption;color:root.textColor}
                }
            }
        }
        Button {visible:root.riders.length>4;text:root.showAll ? "Fewer riders" : "+"+(root.riders.length-4)+" riders";fontSize:Style.font.caption;verticalPadding:Style.space(2);foreground:root.textColor;onClicked:root.showAll=!root.showAll}
        RaceText {visible:root.riders.length===0;width:parent.width;text:"Individual riders not listed by PCS";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
        RaceText {visible:Number(root.group.omitted || 0)>0;width:parent.width;text:"+"+root.group.omitted+" more riders · open PCS for the full group";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
    }
}

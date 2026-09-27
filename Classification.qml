import QtQuick
import qs.Commons
import qs.Ui

Column {
    id:root
    property var classification: ({})
    property color textColor: Color.foreground
    property bool showAll:false
    readonly property var rows:classification.rows || []
    onClassificationChanged:showAll=false
    spacing:Style.space(5)
    PanelSectionHeader {text:(root.classification.title || "Classification").toUpperCase();foreground:root.textColor}
    RaceText {width:parent.width;text:"Leader’s time · gaps to leader";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
    Repeater {
        model:root.showAll ? root.rows : root.rows.slice(0,10)
        CursorSurface {
            required property var modelData
            width:parent.width;height:Style.space(38);bordered:true;foreground:root.textColor
            RaceText {id:rank;anchors.left:parent.left;anchors.leftMargin:Style.space(8);anchors.verticalCenter:parent.verticalCenter;width:Style.space(30);text:modelData.rank;color:Qt.darker(root.textColor,1.5);font.pixelSize:Style.font.caption}
            RaceText {anchors.left:rank.right;anchors.leftMargin:Style.space(8);anchors.right:time.left;anchors.rightMargin:Style.space(8);anchors.verticalCenter:parent.verticalCenter;text:modelData.name;font.bold:modelData.rank==="1";color:root.textColor}
            RaceText {id:time;anchors.right:parent.right;anchors.rightMargin:Style.space(8);anchors.verticalCenter:parent.verticalCenter;width:Style.space(88);text:modelData.time;horizontalAlignment:Text.AlignRight;color:Color.accent}
        }
    }
    RaceText {visible:!root.rows.length;width:parent.width;text:"Results not published yet";color:Qt.darker(root.textColor,1.5)}
    Button {visible:root.rows.length>10;text:root.showAll ? "Show top 10" : "Show all "+root.rows.length;bordered:true;foreground:root.textColor;onClicked:root.showAll=!root.showAll}
}

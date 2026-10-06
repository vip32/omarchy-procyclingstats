import QtQuick
import qs.Commons
import qs.Ui

Column {
    id:root
    property var events:[]
    property string state:""
    property string error:""
    property color textColor:Color.foreground
    property bool concealed:false
    readonly property bool rowsHidden:concealed && events.length>0
    property bool showAll:false
    spacing:Style.space(8)
    PanelSectionHeader {text:"RACE EVENTS · LATEST FIRST";foreground:root.textColor}
    RaceText {width:parent.width;visible:root.error!=="";text:(root.events.length ? "Previous events · " : "")+root.error;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Color.urgent}
    SpoilerVeil {width:parent.width;visible:root.rowsHidden;foreground:root.textColor}
    Repeater {
        model:root.rowsHidden ? [] : root.showAll ? root.events : root.events.slice(0,15)
        CursorSurface {
            required property var modelData
            width:parent.width;height:Math.max(Style.space(48),marker.implicitHeight+Style.space(18),body.implicitHeight+Style.space(18))
            bordered:true;foreground:root.textColor
            Column {
                id:marker
                x:Style.space(10);y:Style.space(9);width:Style.space(65)
                RaceText {width:parent.width;text:modelData.marker==="F" ? "FINISH" : modelData.marker || "—";font.pixelSize:Style.font.caption;font.bold:true;color:Color.accent;horizontalAlignment:Text.AlignHCenter}
                RaceText {width:parent.width;text:/^\d+(\.\d+)?$/.test(modelData.marker) ? "km to go" : "";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5);horizontalAlignment:Text.AlignHCenter}
            }
            RaceText {
                id:body
                anchors.left:marker.right;anchors.leftMargin:Style.space(12)
                anchors.right:parent.right;anchors.rightMargin:Style.space(10)
                y:Style.space(9)
                text:modelData.text;font.pixelSize:Style.font.caption;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.textColor
            }
        }
    }
    RaceText {width:parent.width;visible:!root.events.length && !root.error;text:root.state==="empty" ? "No race events published yet." : root.state==="ready" ? "No race events." : "Loading race events…";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.textColor,1.5)}
    Button {visible:!root.rowsHidden && root.events.length>15;text:root.showAll ? "Show latest 15" : "Show all "+root.events.length+" events";bordered:true;foreground:root.textColor;onClicked:root.showAll=!root.showAll}
}

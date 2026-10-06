import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

CursorSurface {
    id: root
    property bool trendFresh:false
    readonly property string trend:Model.gapTrendText(group,trendFresh)
    property var group: ({})
    property color textColor: Color.foreground
    readonly property var riders: group.riders || []
    property bool showAll:false
    property string racePath:""
    onRacePathChanged:showAll=false
    onGroupChanged:if(!riders.length)showAll=false
    foreground:textColor
    hasCursor:mouse.containsMouse && riders.length>0
    implicitHeight:body.implicitHeight+Style.space(8)
    height:implicitHeight
    Accessible.role:Accessible.Button
    Accessible.name:(group.label || "Group")+" · "+(group.gap || "Gap unavailable")
    Accessible.description:"Expand or collapse the named riders"+(trend ? (group.gapDelta<0 ? ". Gaining " : ". Losing ")+Math.abs(group.gapDelta)+" seconds since the previous update" : "")
    Accessible.onPressAction:if(riders.length)showAll=!showAll
    Column {
        id:body
        x:Style.space(6);y:Style.space(4)
        width:parent.width-Style.space(12)
        spacing:Style.space(3)
        Item {
            width:parent.width;height:Style.space(18)
            RaceText {anchors.left:parent.left;anchors.right:gap.left;anchors.rightMargin:Style.space(8);text:(root.group.label || "Group")+(root.group.count ? " · "+root.group.count : "")+(root.riders.length ? root.showAll ? "  ▴" : "  ▾" : "");font.pixelSize:Style.font.caption;font.bold:true;color:root.textColor}
            RaceText {id:gap;anchors.right:parent.right;text:(root.group.gap || "—")+(root.group.uncertain ? " ?" : "")+root.trend;font.pixelSize:Style.font.caption;font.bold:true;color:Color.accent}
        }
        RaceText {
            visible:!root.showAll && root.riders.length>0;width:parent.width
            text:root.riders.slice(0,4).map(function(r){return r.name}).join(" · ")+(root.riders.length>4 ? " · +"+(root.riders.length-4)+" more" : "")
            font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.15)
        }
        Grid {
            visible:root.showAll
            width:parent.width;columns:width>Style.space(350) ? 2 : 1;spacing:Style.space(5)
            Repeater {
                model:root.showAll ? root.riders : []
                Row {
                    required property var modelData
                    width:(parent.width-parent.spacing*(parent.columns-1))/parent.columns;spacing:Style.space(6)
                    RaceText {width:Style.space(26);text:modelData.bib || "";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5);horizontalAlignment:Text.AlignRight}
                    RaceText {width:parent.width-Style.space(32);text:modelData.name || "";font.pixelSize:Style.font.caption;color:root.textColor}
                }
            }
        }
        RaceText {visible:root.riders.length===0;width:parent.width;text:"Individual riders not listed by PCS";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
        RaceText {visible:root.showAll && Number(root.group.omitted || 0)>0;width:parent.width;text:"+"+root.group.omitted+" more riders · open PCS for the full group";font.pixelSize:Style.font.caption;color:Qt.darker(root.textColor,1.5)}
    }
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:root.riders.length ? Qt.PointingHandCursor : Qt.ArrowCursor;onClicked:if(root.riders.length)root.showAll=!root.showAll}
    PanelToolTip {
        visible:root.trend!=="" && mouse.containsMouse
        text:(root.group.gapDelta<0 ? "Gaining " : "Losing ")+Math.abs(root.group.gapDelta)+" seconds to the front since the previous update"
    }

}

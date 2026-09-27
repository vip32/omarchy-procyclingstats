import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
    id: root
    property var values: Model.settings({})
    property color foreground: Color.foreground
    property string feedback: ""
    property int cursorIndex: 0
    signal changed(var changes)
    signal testRequested()
    spacing: Style.space(12)
    readonly property var fields: [
        {key:"refreshIntervalSec",label:"Live races & events",min:60,max:900,step:30},
        {key:"overviewIntervalSec",label:"Race list",min:300,max:3600,step:60},
        {key:"resultsIntervalSec",label:"Finished results & GC",min:300,max:3600,step:60},
        {key:"notificationDurationSec",label:"Notification duration",min:5,max:30,step:1}
    ]
    function change(index, direction) {
        var field = fields[index]
        var changes = {}
        changes[field.key] = Math.max(field.min,Math.min(field.max,values[field.key] + direction*field.step))
        changed(changes)
    }
    function move(dx,dy) {
        cursorIndex = Math.max(0,Math.min(4,cursorIndex+dy))
        if(dx) {if(cursorIndex===4) changed({eventNotifications:dx>0});else change(cursorIndex,dx)}
    }
    function activate() {
        if(cursorIndex===4) changed({eventNotifications:!values.eventNotifications})
        else change(cursorIndex,1)
    }
    function duration(seconds) {return seconds < 60 ? seconds+" sec" : seconds%60 ? Math.floor(seconds/60)+"m "+seconds%60+"s" : seconds/60+" min"}

    PanelSectionHeader {text:"REFRESH & NOTIFICATIONS";foreground:root.foreground}
    Repeater {
        model:root.fields
        CursorSurface {
            id:row
            required property var modelData
            required property int index
            width:root.width;height:Style.space(64)
            bordered:true;foreground:root.foreground;hasCursor:root.cursorIndex===index
            Column {
                anchors.left:parent.left;anchors.leftMargin:Style.space(12)
                anchors.right:adjust.left;anchors.rightMargin:Style.space(8)
                anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(4)
                RaceText {width:parent.width;text:row.modelData.label;font.bold:true;color:root.foreground}
                RaceText {width:parent.width;text:root.duration(root.values[row.modelData.key]);color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
            }
            Row {
                id:adjust;anchors.right:parent.right;anchors.rightMargin:Style.space(10);anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
                Button {text:"−";bordered:true;foreground:root.foreground;enabled:root.values[row.modelData.key]>row.modelData.min;onClicked:{root.cursorIndex=row.index;root.change(row.index,-1)}}
                Button {text:"+";bordered:true;foreground:root.foreground;enabled:root.values[row.modelData.key]<row.modelData.max;onClicked:{root.cursorIndex=row.index;root.change(row.index,1)}}
            }
        }
    }
    Toggle {
        width:parent.width;label:"Race-event notifications"
        description:"New events from up to 3 recently opened races, even with this panel closed."
        checked:root.values.eventNotifications;hasCursor:root.cursorIndex===4;foreground:root.foreground
        onClicked:{root.cursorIndex=4;root.changed({eventNotifications:!root.values.eventNotifications})}
    }
    Button {text:"Send test notification";bordered:true;foreground:root.foreground;enabled:root.values.eventNotifications;onClicked:root.testRequested()}
    RaceText {width:parent.width;text:"Notifications close automatically and respect Do Not Disturb. New events in one refresh are grouped into one notification per race.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    RaceText {width:parent.width;text:root.feedback || "Changes save automatically. PCS cooldowns still apply.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.feedback ? Color.urgent : Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    RaceText {width:parent.width;text:"J/K select · H/L adjust · Enter change · Esc back";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
}

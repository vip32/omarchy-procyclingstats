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
    signal reveal(var item)
    readonly property var categories: Model.categories()
    readonly property var levels: Model.raceLevels()
    readonly property int fieldsStart: 1+categories.length
    readonly property int notificationIndex: fieldsStart+fields.length
    readonly property int lastIndex: notificationIndex+1
    spacing: Style.space(12)
    readonly property var fields: [
        {key:"archiveRaceCount",label:"Recent & upcoming race count",min:10,max:100,step:5,unit:"races"},
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
    function categoryChange(index, checked) {
        var changes={};changes[categories[index].key]=checked;changed(changes)
    }
    function levelChange(direction) {
        var index=levels.indexOf(values.minimumRaceLevel)
        changed({minimumRaceLevel:levels[Math.max(0,Math.min(levels.length-1,index+direction))]})
    }
    function cursorItem() {
        if(cursorIndex===0) return levelRow
        if(cursorIndex<fieldsStart) return categoryRepeater.itemAt(cursorIndex-1)
        if(cursorIndex===notificationIndex) return notificationToggle
        if(cursorIndex===lastIndex) return spoilerToggle
        return fieldRepeater.itemAt(cursorIndex-fieldsStart)
    }
    onCursorIndexChanged: reveal(cursorItem())
    function move(dx,dy) {
        cursorIndex = Math.max(0,Math.min(lastIndex,cursorIndex+dy))
        if(!dx) return
        if(cursorIndex===0) levelChange(dx)
        else if(cursorIndex<fieldsStart) categoryChange(cursorIndex-1,dx>0)
        else if(cursorIndex===notificationIndex) changed({eventNotifications:dx>0})
        else if(cursorIndex===lastIndex) changed({revealMode:dx>0})
        else change(cursorIndex-fieldsStart,dx)
    }
    function activate() {
        if(cursorIndex===0) levelChange(levels.indexOf(values.minimumRaceLevel)===levels.length-1 ? -levels.length : 1)
        else if(cursorIndex<fieldsStart) categoryChange(cursorIndex-1,!values[categories[cursorIndex-1].key])
        else if(cursorIndex===notificationIndex) changed({eventNotifications:!values.eventNotifications})
        else if(cursorIndex===lastIndex) changed({revealMode:!values.revealMode})
        else change(cursorIndex-fieldsStart,1)
    }
    function duration(seconds) {return seconds < 60 ? seconds+" sec" : seconds%60 ? Math.floor(seconds/60)+"m "+seconds%60+"s" : seconds/60+" min"}

    PanelSectionHeader {text:"RACE FILTERS";foreground:root.foreground}
    CursorSurface {
        id:levelRow;width:parent.width;height:Style.space(64)
        bordered:true;foreground:root.foreground;hasCursor:root.cursorIndex===0
        Column {
            anchors.left:parent.left;anchors.leftMargin:Style.space(12)
            anchors.right:levelAdjust.left;anchors.rightMargin:Style.space(8)
            anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(4)
            RaceText {text:"Minimum race level";font.bold:true;color:root.foreground}
            RaceText {text:root.values.minimumRaceLevel;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
        }
        Row {
            id:levelAdjust;anchors.right:parent.right;anchors.rightMargin:Style.space(10);anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
            Button {text:"‹";tooltipText:"Include lower race levels";bordered:true;foreground:root.foreground;enabled:root.values.minimumRaceLevel!=="All";onClicked:{root.cursorIndex=0;root.levelChange(-1)}}
            Button {text:"›";tooltipText:"Raise minimum race level";bordered:true;foreground:root.foreground;enabled:root.values.minimumRaceLevel!=="WorldTour";onClicked:{root.cursorIndex=0;root.levelChange(1)}}
        }
    }
    RaceText {width:parent.width;text:"Class 2 → Class 1 → ProSeries → WorldTour. Championships stay visible at every level.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    Row {
        width:parent.width;spacing:Style.space(6)
        RaceText {width:parent.width-allCategories.width-noCategories.width-Style.space(12);anchors.verticalCenter:parent.verticalCenter;text:"CATEGORIES · "+root.categories.filter(function(c){return root.values[c.key]}).length+" / "+root.categories.length;color:root.foreground;font.pixelSize:Style.font.caption}
        Button {id:allCategories;text:"All";foreground:root.foreground;onClicked:{var changes={};root.categories.forEach(function(c){changes[c.key]=true});root.changed(changes)}}
        Button {id:noCategories;text:"None";foreground:root.foreground;onClicked:{var changes={};root.categories.forEach(function(c){changes[c.key]=false});root.changed(changes)}}
    }
    Grid {
        width:parent.width;columns:2;spacing:Style.space(6)
        Repeater {
            id:categoryRepeater;model:root.categories
            CursorSurface {
                id:categoryRow
                required property var modelData
                required property int index
                readonly property bool checked:root.values[modelData.key]===true
                width:(root.width-Style.space(6))/2;height:Style.space(36)
                bordered:true;foreground:root.foreground;hasCursor:root.cursorIndex===index+1
                Accessible.role:Accessible.CheckBox;Accessible.name:modelData.code+" · "+modelData.label
                Accessible.checkable:true;Accessible.checked:checked
                Accessible.onPressAction:root.categoryChange(index,!checked)
                Rectangle {
                    id:check;anchors.left:parent.left;anchors.leftMargin:Style.space(10);anchors.verticalCenter:parent.verticalCenter
                    width:Style.space(16);height:width;radius:Style.space(2);color:"transparent";border.color:root.foreground
                    RaceText {anchors.centerIn:parent;text:categoryRow.checked ? "✓" : "";color:root.foreground;font.pixelSize:Style.font.caption}
                }
                RaceText {anchors.left:check.right;anchors.leftMargin:Style.space(8);anchors.right:parent.right;anchors.rightMargin:Style.space(8);anchors.verticalCenter:parent.verticalCenter;text:categoryRow.modelData.code+" · "+categoryRow.modelData.label;color:root.foreground;font.pixelSize:Style.font.caption}
                MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{root.cursorIndex=categoryRow.index+1;root.categoryChange(categoryRow.index,!categoryRow.checked)}}
            }
        }
    }
    RaceText {width:parent.width;text:"Applies to Races, Live, the calendar and event notifications. Races with missing category or level data are hidden when that filter is restricted.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    PanelSeparator {foreground:root.foreground}
    PanelSectionHeader {text:"CALENDAR & UPDATES";foreground:root.foreground}
    Repeater {
        id:fieldRepeater
        model:root.fields
        CursorSurface {
            id:row
            required property var modelData
            required property int index
            width:root.width;height:Style.space(64)
            bordered:true;foreground:root.foreground;hasCursor:root.cursorIndex===root.fieldsStart+index
            Column {
                anchors.left:parent.left;anchors.leftMargin:Style.space(12)
                anchors.right:adjust.left;anchors.rightMargin:Style.space(8)
                anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(4)
                RaceText {width:parent.width;text:row.modelData.label;font.bold:true;color:root.foreground}
                RaceText {width:parent.width;text:row.modelData.unit==="races" ? root.values[row.modelData.key]+" races" : root.duration(root.values[row.modelData.key]);color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
            }
            Row {
                id:adjust;anchors.right:parent.right;anchors.rightMargin:Style.space(10);anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
                Button {text:"−";bordered:true;foreground:root.foreground;enabled:root.values[row.modelData.key]>row.modelData.min;onClicked:{root.cursorIndex=root.fieldsStart+row.index;root.change(row.index,-1)}}
                Button {text:"+";bordered:true;foreground:root.foreground;enabled:root.values[row.modelData.key]<row.modelData.max;onClicked:{root.cursorIndex=root.fieldsStart+row.index;root.change(row.index,1)}}
            }
        }
    }
    Toggle {
        id:notificationToggle
        width:parent.width;label:"Race-event notifications"
        description:"New events from up to 3 recently opened races, even with this panel closed."
        checked:root.values.eventNotifications;hasCursor:root.cursorIndex===root.notificationIndex;foreground:root.foreground
        onClicked:{root.cursorIndex=root.notificationIndex;root.changed({eventNotifications:!root.values.eventNotifications})}
    }
    RaceText {width:parent.width;text:"Notifications close automatically and respect Do Not Disturb. New events in one refresh are grouped into one notification per race.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    Toggle {
        id:spoilerToggle
        width:parent.width;label:"Spoiler protection"
        description:"Blur finished results until revealed. Also hides finished-race events and notifications."
        checked:root.values.revealMode;hasCursor:root.cursorIndex===root.lastIndex;foreground:root.foreground
        onClicked:{root.cursorIndex=root.lastIndex;root.changed({revealMode:!root.values.revealMode})}
    }
    RaceText {width:parent.width;text:root.feedback || "Changes save automatically. PCS cooldowns still apply.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.feedback ? Color.urgent : Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
    RaceText {width:parent.width;text:"J/K select · H/L adjust · Enter change · Esc back";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Qt.darker(root.foreground,1.5);font.pixelSize:Style.font.caption}
}

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
    id:root
    property var detail: ({})
    property color foreground: Color.foreground
    readonly property color dim: Qt.darker(foreground,1.5)
    readonly property var nextPoint: Model.nextKeypoint(detail)
    readonly property var latest: (detail.events || []).slice(0,3)
    signal eventsRequested()
    spacing:Style.space(10)
    function value(n,unit) {return n===null || n===undefined ? "—" : String(n)+(unit || "")}

    Row {
        width:parent.width;spacing:Style.space(12)
        Repeater {
            model:[
                {label:"KM TO GO",value:root.value(root.detail.kmToGo)},
                {label:root.detail.status==="upcoming" ? "START ("+(root.detail.startZone || "local")+")" : "RACE TIME",value:root.detail.status==="upcoming" ? root.detail.start || "—" : root.detail.elapsed || "—"},
                {label:"AVG. KM/H",value:root.value(root.detail.avgSpeed)}
            ]
            Column {
                required property var modelData
                width:(parent.width-Style.space(24))/3;spacing:Style.space(3)
                RaceText {width:parent.width;text:modelData.label;font.pixelSize:Style.font.caption;color:root.dim}
                RaceText {width:parent.width;text:modelData.value;font.pixelSize:Style.font.subtitle;font.bold:true;color:root.foreground}
            }
        }
    }
    PanelSeparator {foreground:root.foreground}
    PanelSectionHeader {text:"RACE SITUATION · GAPS TO FRONT";foreground:root.foreground}
    Column {
        width:parent.width;spacing:Style.space(6)
        Repeater {
            model:root.detail.groups || []
            RiderGroup {required property var modelData;width:parent.width;group:modelData;racePath:root.detail.path || "";textColor:root.foreground}
        }
        RaceText {width:parent.width;visible:!(root.detail.groups || []).length;text:root.detail.status==="upcoming" ? "Race has not started yet." : "No group gaps published";font.pixelSize:Style.font.caption;color:root.dim}
    }
    Item {
        width:parent.width;height:Math.max(eventsHeading.implicitHeight,allEvents.implicitHeight)
        PanelSectionHeader {id:eventsHeading;anchors.left:parent.left;anchors.right:allEvents.left;anchors.verticalCenter:parent.verticalCenter;text:root.latest.length && (root.detail.error || root.detail.eventsError) ? "LATEST EVENTS · PREVIOUS DATA" : "LATEST EVENTS · KM TO GO";foreground:root.foreground}
        Button {id:allEvents;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;text:"All →";tooltipText:"Full race events (T)";fontSize:Style.font.caption;verticalPadding:Style.space(2);foreground:root.foreground;onClicked:root.eventsRequested()}
    }
    Column {
        width:parent.width;spacing:Style.space(6)
        Repeater {
            model:root.latest
            Row {
                required property var modelData
                width:parent.width;spacing:Style.space(10)
                RaceText {width:Style.space(58);text:modelData.marker==="F" ? "Finish" : modelData.marker ? modelData.marker+" km" : "—";font.pixelSize:Style.font.caption;color:root.dim}
                RaceText {width:parent.width-Style.space(68);text:modelData.text;font.pixelSize:Style.font.caption;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;color:root.foreground}
            }
        }
        RaceText {width:parent.width;visible:!root.latest.length;text:root.detail.eventsError || (root.detail.eventsState==="empty" ? "No events published yet." : root.detail.error ? "Events unavailable." : "Waiting for race events…");font.pixelSize:Style.font.caption;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.dim}
    }
    PanelSeparator {foreground:root.foreground}
    Profile {
        width:parent.width;height:Style.space(58);visible:(root.detail.profile || []).length>1
        points:root.detail.profile || []
        progress:root.detail.distance>0 && root.detail.kmDone!==null && root.detail.kmDone!==undefined ? root.detail.kmDone/root.detail.distance : -1
        foreground:root.foreground
    }
    Row {
        width:parent.width
        RaceText {width:parent.width*0.6;text:root.value(root.detail.kmDone)+" / "+root.value(root.detail.distance," km covered");font.pixelSize:Style.font.caption;color:root.dim}
        RaceText {width:parent.width*0.4;text:root.detail.profile && root.detail.profile.length>1 ? root.detail.distance>0 && root.detail.kmDone!==null && root.detail.kmDone!==undefined ? "│ Current position" : "" : "Profile unavailable";horizontalAlignment:Text.AlignRight;font.pixelSize:Style.font.caption;color:root.dim}
    }
    RaceText {
        width:parent.width;visible:!!root.nextPoint
        text:root.nextPoint ? "Next · "+root.nextPoint.name+" · in "+root.nextPoint.remaining+" km"+(root.nextPoint.length ? " · "+root.nextPoint.length+" km" : "")+(root.nextPoint.gradient ? " at "+root.nextPoint.gradient+"%" : "") : ""
        font.pixelSize:Style.font.caption;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground
    }
}

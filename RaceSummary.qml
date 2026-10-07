import QtQuick
import qs.Commons
import qs.Ui

Column {
    id:root
    property bool concealed: false
    property var detail: ({})
    property color foreground: Color.foreground
    readonly property color dim: Qt.darker(foreground,1.5)
    readonly property bool hasProfile: (detail.profile || []).length>1 || !!detail.profileImage
    spacing:Style.space(10)
    function value(n,unit) {return n===null || n===undefined ? "—" : String(n)+(unit || "")}

    Row {
        width:parent.width;spacing:Style.space(12)
        Repeater {
            model:[
                {label:"DISTANCE",value:root.value(root.detail.distance," km")},
                {label:"HM",value:root.value(root.detail.elevationGain," m")},
                {label:"WINNER TIME",value:root.concealed && root.detail.elapsed ? "Hidden" : root.detail.elapsed || "—"},
                {label:"AVG. KM/H",value:root.concealed && root.detail.avgSpeed!==null && root.detail.avgSpeed!==undefined ? "Hidden" : root.value(root.detail.avgSpeed)}
            ]
            Column {
                required property var modelData
                width:(parent.width-parent.spacing*3)/4;spacing:Style.space(3)
                RaceText {width:parent.width;text:modelData.label;font.pixelSize:Style.font.caption;color:root.dim}
                RaceText {width:parent.width;text:modelData.value;font.pixelSize:Style.font.subtitle;font.bold:true;color:root.foreground}
            }
        }
    }
    RaceText {width:parent.width;visible:!!root.detail.profileLabel;text:root.detail.profileLabel+" · elevation profile";color:root.dim;font.pixelSize:Style.font.caption}
    Profile {id:summaryProfile;width:parent.width;height:root.detail.profileImage && !summaryProfile.hasCurve ? Math.min(Style.space(220),width*(root.detail.profileImageHeight || 300)/(root.detail.profileImageWidth || 600)) : Style.space(58);imageSource:root.detail.profileImage || "";visible:root.hasProfile;points:root.detail.profile || [];foreground:root.foreground}
    RaceText {
        width:parent.width;visible:!root.hasProfile || !!root.detail.profileError
        text:root.hasProfile ? "Profile · previous data" : root.detail.state==="loading" || !root.detail.state ? "Loading profile…" : "Profile unavailable · open PCS with ↗"
        font.pixelSize:Style.font.caption;color:root.dim
    }
    PanelSeparator {foreground:root.foreground}
}

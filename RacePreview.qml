import QtQuick
import qs.Commons
import qs.Ui

Column {
    id:root
    property var detail: ({})
    property color foreground: Color.foreground
    readonly property color dim: Qt.darker(foreground,1.5)
    readonly property bool hasProfile:(detail.profile || []).length>1 || !!detail.profileImage
    spacing:Style.space(12)
    Row {
        width:parent.width;spacing:Style.space(12)
        Column {
            width:(parent.width-parent.spacing*2)*0.5;spacing:Style.space(4)
            RaceText {text:"START · AS PUBLISHED BY PCS";font.pixelSize:Style.font.caption;color:root.dim}
            RaceText {width:parent.width;text:root.detail.startTime || "Not published";font.pixelSize:Style.font.subtitle;color:root.foreground;wrapMode:Text.WordWrap;elide:Text.ElideNone}
        }
        Column {
            width:(parent.width-parent.spacing*2)*0.25;spacing:Style.space(4)
            RaceText {text:"DISTANCE";font.pixelSize:Style.font.caption;color:root.dim}
            RaceText {text:root.detail.distance ? root.detail.distance+" km" : "—";font.pixelSize:Style.font.subtitle;color:root.foreground}
        }
        Column {
            width:(parent.width-parent.spacing*2)*0.25;spacing:Style.space(4)
            RaceText {text:"ELEVATION";font.pixelSize:Style.font.caption;color:root.dim}
            RaceText {text:root.detail.elevationGain===null || root.detail.elevationGain===undefined ? "—" : root.detail.elevationGain+" m";font.pixelSize:Style.font.subtitle;color:root.foreground}
        }
    }
    RaceText {width:parent.width;visible:!!(root.detail.departure || root.detail.arrival);text:[root.detail.departure,root.detail.arrival].filter(Boolean).join(" → ");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground}
    RaceText {width:parent.width;visible:!!root.detail.profileLabel;text:root.detail.profileLabel+" · elevation profile";color:root.dim;font.pixelSize:Style.font.caption}
    Profile {id:previewProfile;width:parent.width;height:root.detail.profileImage && !previewProfile.hasCurve ? Math.min(Style.space(220),width*(root.detail.profileImageHeight || 300)/(root.detail.profileImageWidth || 600)) : Style.space(75);visible:root.hasProfile;imageSource:root.detail.profileImage || "";points:root.detail.profile || [];lineColor:Color.accent}
    RaceText {width:parent.width;visible:!root.hasProfile;text:"Course profile unavailable here. Open PCS with ↗.";font.pixelSize:Style.font.caption;color:root.dim;wrapMode:Text.WordWrap;elide:Text.ElideNone}
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "io.github.vip32.procyclingstats"
    manageIpc: false
    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.5)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property var races: service ? service.races : []
    readonly property bool demo: service ? service.demo : false
    readonly property var rows: filter === "Live" ? races.filter(function(r) {return r.status === "live"}) : races
    readonly property var selected: rows.length ? rows[Math.max(0,Math.min(cursorIndex,rows.length-1))] : null
    readonly property var detail: selected && service ? service.details[selected.path] || ({}) : ({})
    readonly property int refreshSeconds: Math.max(60,Math.min(900,Number(setting("refreshIntervalSec",60))||60))
    readonly property bool finished: (selected && selected.status === "finished") || detail.status === "finished"
    readonly property var classifications: detail.classifications || []
    readonly property var classification: classifications.filter(function(c){return c.kind === classificationKind})[0] || classifications[0] || ({})
    property string classificationKind: "gc"
    property string filter: "Today"
    property int cursorIndex: 0
    property bool expanded: false
    property double now: Date.now()

    function age(stamp) {
        var secs = Math.max(0, Math.floor((now-Date.parse(stamp))/1000))
        if (!isFinite(secs)) return "Waiting for data"
        return secs < 60 ? "Updated just now" : "Updated " + Math.floor(secs/60) + "m ago"
    }
    function val(n, unit) {return n === null || n === undefined ? "—" : String(n) + (unit || "")}
    function titleStatus(s) { return ({live:"LIVE",finished:"FINISHED",upcoming:"UPCOMING",scheduled:"SCHEDULED",unknown:"STATUS UNKNOWN"})[s] || "WAITING" }
    function configure() { if (service) service.refreshIntervalSec = refreshSeconds }
    function select(index, show) {
        cursorIndex = Math.max(0,Math.min(rows.length-1,index))
        if(show) expanded = true
        if(service && selected) service.watch(selected.path)
        Qt.callLater(function() {
            if (expanded) scroller.contentY = 0
            else {
                var item = raceRepeater.itemAt(cursorIndex)
                if (item) {
                    var y = item.mapToItem(column, 0, 0).y
                    if (y < scroller.contentY) scroller.contentY = y
                    else if (y + item.height > scroller.contentY + scroller.height)
                        scroller.contentY = y + item.height - scroller.height
                }
            }
        })
    }
    function openSource() {
        var path = selected ? selected.path + (selected.status === "live" || selected.status === "upcoming" ? "/live" : "") : ""
        if(path && !/^race\/[a-z0-9-]+\/\d{4}\/(result|stage-\d+[a-z]?)(\/live)?$/.test(path)) return
        Quickshell.execDetached(["/usr/bin/xdg-open","https://www.procyclingstats.com/" + path])
    }
    onServiceChanged: configure()
    onRefreshSecondsChanged: configure()
    onFilterChanged: { cursorIndex = 0; expanded = false }
    onSelectedChanged: { classificationKind = "gc"; if(opened && expanded && service && selected) service.watch(selected.path) }
    onOpenedChanged: {
        if(opened) {now=Date.now(); configure(); if(service){service.refresh();if(expanded && selected)service.watch(selected.path)} Qt.callLater(function(){keys.forceActiveFocus()})}
    }
    Timer { interval:30000; running:root.opened; repeat:true; onTriggered:root.now=Date.now() }
    IpcHandler {
        target: "io.github.vip32.procyclingstats.panel"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function expand(): void { root.open(); root.select(root.cursorIndex, true) }
        function compact(): void { root.expanded = false; root.open() }
        function selectRace(index: int): void { root.filter = "Today"; root.open(); root.select(index, true) }
        function restoreView(filterName: string, path: string, expanded: bool, opened: bool): void {
            root.filter = filterName === "Live" ? "Live" : "Today"
            var i = root.rows.findIndex(function(r){return r.path === path})
            root.cursorIndex = Math.max(0,i)
            root.expanded = expanded
            if(opened) root.open(); else root.close()
        }
        function status(): string {
            return JSON.stringify({opened:root.opened, expanded:root.expanded, serviceReady:!!root.service,
                filter:root.filter, rows:root.rows.length, selected:root.selected ? root.selected.path : "", detailState:root.detail.state || "",
                geometry:{x:panel.cardOrigin.x,y:panel.cardOrigin.y,width:panel.contentWidth,height:panel.contentHeight,screen:panel.screen ? panel.screen.name : ""},
                riderCount:(root.detail.groups || []).reduce(function(n,g){return n+(g.riders || []).length},0),
                classificationRows:(root.classification.rows || []).length, classificationTitle:root.classification.title || "",
                demo:root.demo, vertical:root.bar ? root.bar.vertical : false})
        }
    }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        iconComponent: Component { RaceBike {color:button.foreground} }
        tooltipText: "ProCyclingStats · road cycling\n" + (root.demo ? "DEMO — fictional races" : root.service && root.service.error ? root.service.error : root.races.filter(function(r){return r.status === "live"}).length + " live · " + root.races.length + " races today") + "\nLeft click: races · Right click: PCS · Middle click: refresh"
        onPressed: function(code) {
            if(code===Qt.LeftButton)root.toggle()
            else if(code===Qt.RightButton)root.openSource()
            else if(code===Qt.MiddleButton && root.service)root.service.refresh()
        }
        Rectangle {
            visible: root.races.some(function(r){return r.status === "live"}) && !root.demo && root.service && root.service.state === "ready"
            width: Style.space(4); height:width; radius:width/2
            color: Color.accent
            anchors.right:parent.right; anchors.top:parent.top
            anchors.topMargin:Style.space(4); anchors.rightMargin:Style.space(2)
        }
    }
    KeyboardPanel {
        id: panel
        anchorItem:button
        owner:root
        bar:root.bar
        open:root.opened
        centerOnBar:false
        focusTarget:keys
        contentWidth:panel.fittedContentWidth(Style.space(root.expanded ? 590 : 420))
        contentHeight:panel.fittedContentHeight(column.implicitHeight,Style.space(root.expanded ? 720 : 560))
        PanelKeyCatcher {
            id:keys
            anchors.fill:parent
            onMoveRequested:function(dx,dy){if(dy!==0)root.select(root.cursorIndex+dy,root.expanded)}
            onActivateRequested:root.select(root.cursorIndex,true)
            onCloseRequested:{if(root.expanded)root.expanded=false;else root.close()}
            onTabRequested:function(direction){root.switchPanel(direction)}
            onTextKey:function(text){
                var k=text.toLowerCase()
                if(k==="r" && root.service)root.service.refresh()
                if(k==="o")root.openSource()
                if(k==="e" && root.selected){root.expanded=!root.expanded;root.select(root.cursorIndex,root.expanded)}
            }
            Flickable {
                id:scroller
                anchors.fill:parent
                contentWidth:width
                contentHeight:column.implicitHeight
                clip:true
                boundsBehavior:Flickable.StopAtBounds
                flickableDirection:Flickable.VerticalFlick
                Column {
                    id:column
                    width:scroller.width
                    spacing:Style.spacing.panelGap
                    Item {
                        width:parent.width; height:Style.space(44)
                        RaceBike {id:hero; width:Style.space(32);height:width;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;color:root.foreground}
                        Column {
                            anchors.left:hero.right;anchors.leftMargin:Style.space(12)
                            anchors.right:actions.left;anchors.rightMargin:Style.space(8)
                            anchors.verticalCenter:parent.verticalCenter
                            spacing:Style.space(2)
                            RaceText {width:parent.width;text:"ProCyclingStats";font.pixelSize:Style.font.title;font.bold:true;color:root.foreground}
                            RaceText {width:parent.width;text:root.demo ? "DEMO · fictional road races" : root.service && root.service.loading ? "Refreshing races…" : "Road cycling · " + root.age(root.service ? root.service.fetchedAt : "");font.pixelSize:Style.font.caption;color:root.dim}
                        }
                        Row {
                            id:actions;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
                            Button {text:"↻";tooltipText:"Refresh races (R)";bordered:true;foreground:root.foreground;onClicked:if(root.service)root.service.refresh()}
                            Button {visible:root.expanded;text:"↙";tooltipText:"Back to today’s races";bordered:true;foreground:root.foreground;onClicked:root.expanded=false}
                        }
                    }
                    PanelSeparator {foreground:root.foreground}
                    Row {
                        width:parent.width;spacing:Style.space(6)
                        Repeater {
                            model:["Today","Live"]
                            Button {required property string modelData;width:(parent.width-Style.space(6))/2;text:modelData;selected:root.filter===modelData;bordered:true;foreground:root.foreground;onClicked:root.filter=modelData}
                        }
                    }
                    RaceText {
                        width:parent.width
                        visible:root.service && root.service.error !== ""
                        text:(root.races.length ? "Showing previous data. " : "")+(root.service ? root.service.error : "")
                        color:Color.urgent
                        wrapMode:Text.WordWrap
                        elide:Text.ElideNone
                    }
                    Column {
                        visible:!root.expanded || !root.selected
                        width:parent.width;spacing:Style.space(7)
                        PanelSectionHeader {text:"TODAY’S RACES";foreground:root.foreground}
                        Repeater {
                            id:raceRepeater
                            model:root.rows
                            CursorSurface {
                                id:raceRow
                                required property var modelData
                                required property int index
                                width:parent.width;height:Style.space(74)
                                bordered:true;foreground:root.foreground
                                hasCursor:root.cursorIndex===index
                                Column {
                                    anchors.left:parent.left;anchors.leftMargin:Style.space(10)
                                    anchors.right:miniProfile.left;anchors.rightMargin:Style.space(10)
                                    anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(4)
                                    RaceText {width:parent.width;text:raceRow.modelData.name;font.bold:true;color:root.foreground}
                                    RaceText {width:parent.width;text:[root.titleStatus(raceRow.modelData.status),raceRow.modelData.category,raceRow.modelData.eta ? "ETA "+raceRow.modelData.eta : ""].filter(Boolean).join(" · ");font.pixelSize:Style.font.caption;color:raceRow.modelData.status==="live" ? Color.accent : root.dim}
                                }
                                Column {
                                    id:miniProfile;anchors.right:parent.right;anchors.rightMargin:Style.space(10)
                                    anchors.verticalCenter:parent.verticalCenter;width:Style.space(84)
                                    Profile {width:parent.width;height:Style.space(27);points:raceRow.modelData.profile || [];lineColor:Color.accent}
                                    RaceText {width:parent.width;text:raceRow.modelData.toGo || "→";horizontalAlignment:Text.AlignRight;font.pixelSize:Style.font.caption;color:root.dim}
                                }
                                MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:root.cursorIndex=raceRow.index;onClicked:root.select(raceRow.index,true)}
                            }
                        }
                        RaceText {
                            width:parent.width;visible:root.rows.length===0
                            text:root.service && root.service.error ? "Race data is unavailable. You can still open PCS below." : root.service && root.service.state==="loading" ? "Loading today’s races…" : root.filter==="Live" ? "No live races listed right now." : "No races listed today."
                            color:root.dim;wrapMode:Text.WordWrap;elide:Text.ElideNone
                        }
                    }
                    Column {
                        visible:root.expanded && !!root.selected
                        width:parent.width;spacing:Style.space(12)
                        RaceText {width:parent.width;text:root.selected ? root.selected.name : "";font.pixelSize:Style.font.title;font.bold:true;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground}
                        RaceText {width:parent.width;text:[root.titleStatus(root.detail.status || (root.selected ? root.selected.status : "")),root.detail.date || "",root.demo ? "Fictional snapshot" : root.detail.fetchedAt ? root.age(root.detail.sourceAt || root.detail.fetchedAt) : root.detail.error ? "Race data unavailable" : root.finished ? "Loading results…" : "Loading LiveStats…"].filter(Boolean).join(" · ");font.pixelSize:Style.font.caption;color:Color.accent}
                        RaceText {width:parent.width;visible:!!root.detail.error;text:(root.detail.fetchedAt ? "Previous snapshot · " : "")+(root.detail.error || "");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Color.urgent}
                        Column {
                            visible:root.finished
                            width:parent.width;spacing:Style.space(10)
                            Row {
                                width:parent.width;spacing:Style.space(6)
                                visible:root.classifications.length>1
                                Repeater {
                                    model:root.classifications
                                    Button {required property var modelData;width:(parent.width-Style.space(6)*(root.classifications.length-1))/Math.max(1,root.classifications.length);text:modelData.kind==="gc" ? "GC" : "Stage results";selected:root.classification.kind===modelData.kind;bordered:true;foreground:root.foreground;onClicked:root.classificationKind=modelData.kind}
                                }
                            }
                            Classification {width:parent.width;visible:root.classifications.length>0;classification:root.classification;textColor:root.foreground}
                            RaceText {width:parent.width;visible:!root.classifications.length;text:root.detail.resultsError || (root.detail.error ? "Results could not be loaded. Open PCS below." : "Waiting for published results…");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.dim}
                            RaceText {width:parent.width;visible:root.detail.stageRace===true && root.detail.gcAvailable===false;text:"General classification is not published on this stage page yet.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.dim}
                        }
                        Column {
                            visible:!root.finished
                            width:parent.width;spacing:Style.space(12)
                        Grid {
                            width:parent.width;columns:3;spacing:Style.space(8)
                            Repeater {
                                model:[
                                    {label:"KM TO GO",value:root.val(root.detail.kmToGo)},
                                    {label:"RACE TIME",value:root.detail.elapsed || "—"},
                                    {label:"AVG. KM/H",value:root.val(root.detail.avgSpeed)},
                                    {label:"KM DONE",value:root.val(root.detail.kmDone)},
                                    {label:"DISTANCE",value:root.val(root.detail.distance," km")},
                                    {label:"START ("+(root.detail.startZone || "local")+")",value:root.detail.start || "—"}
                                ]
                                CursorSurface {
                                    required property var modelData
                                    width:(parent.width-Style.space(16))/3;height:Style.space(64);bordered:true;foreground:root.foreground
                                    Column {anchors.fill:parent;anchors.margins:Style.space(10);spacing:Style.space(3)
                                        RaceText {width:parent.width;text:modelData.label;font.pixelSize:Style.font.caption;color:root.dim}
                                        RaceText {width:parent.width;text:modelData.value;font.pixelSize:Style.font.subtitle;font.bold:true;color:root.foreground}
                                    }
                                }
                            }
                        }
                        PanelSectionHeader {text:"RACE SITUATION · GAPS TO FRONT";foreground:root.foreground}
                        Repeater {
                            model:root.detail.groups || []
                            RiderGroup {required property var modelData;width:parent.width;group:modelData;textColor:root.foreground}
                        }
                        RaceText {width:parent.width;visible:!(root.detail.groups || []).length;text:"No group gaps published";color:root.dim;font.pixelSize:Style.font.caption}
                        PanelSectionHeader {text:"COURSE PROFILE";foreground:root.foreground}
                        Profile {width:parent.width;height:Style.space(95);points:root.detail.profile || [];progress:root.detail.distance>0 && root.detail.kmDone!==null ? root.detail.kmDone/root.detail.distance : -1;foreground:root.foreground}
                        RaceText {visible:!(root.detail.profile || []).length;width:parent.width;text:"Course profile unavailable";color:root.dim;font.pixelSize:Style.font.caption}
                        Row {width:parent.width
                            RaceText {width:parent.width/2;text:root.val(root.detail.kmDone," km covered");color:root.dim;font.pixelSize:Style.font.caption}
                            RaceText {width:parent.width/2;text:root.val(root.detail.kmToGo," km remaining");horizontalAlignment:Text.AlignRight;color:root.dim;font.pixelSize:Style.font.caption}
                        }
                        PanelSeparator {foreground:root.foreground}
                        PanelSectionHeader {text:"NEXT ON THE ROUTE";foreground:root.foreground}
                        Repeater {
                            model:(root.detail.keypoints || []).filter(function(k){return root.detail.kmDone===null || k.km>=Number(root.detail.kmDone || 0)}).slice(0,3)
                            RaceText {required property var modelData;width:parent.width;text:modelData.kind+" · "+modelData.name+" · km "+modelData.km+(modelData.gradient ? " · "+modelData.gradient+"%" : "");font.pixelSize:Style.font.caption;color:root.dim}
                        }
                        }
                    }
                    PanelSeparator {foreground:root.foreground}
                    Row {
                        width:parent.width;spacing:Style.space(10)
                        Button {text:"Open PCS ↗";bordered:true;foreground:root.foreground;onClicked:root.openSource()}
                        RaceText {anchors.verticalCenter:parent.verticalCenter;width:parent.width-Style.space(140);text:root.demo ? "FICTIONAL DEMO · no live data" : "Source: ProCyclingStats";font.pixelSize:Style.font.caption;color:root.dim}
                    }
                    RaceText {width:parent.width;text:"J/K select · Enter details · R refresh · Esc back";font.pixelSize:Style.font.caption;color:root.dim;horizontalAlignment:Text.AlignHCenter}
                }
            }
        }
    }
}

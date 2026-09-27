import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

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
    readonly property var preferences: Model.settings(settings)
    readonly property var connection: Model.warning(service ? service.updateIssues : {},now,service ? service.nextAllowed : 0,service ? service.loading : false)
    readonly property color warningColor: bar ? bar.urgent : Color.urgent
    property bool settingsOpen: false
    property string settingsError: ""
    readonly property bool finished: (selected && selected.status === "finished") || detail.status === "finished"
    readonly property var classifications: detail.classifications || []
    readonly property var classification: classifications.filter(function(c){return c.kind === classificationKind})[0] || classifications[0] || ({})
    property string classificationKind: "gc"
    property string detailView: "overview"
    property string lastSelectedPath: ""
    property string filter: "Races"
    property int cursorIndex: 0
    property bool expanded: false
    property double now: Date.now()

    function age(stamp) {
        var secs = Math.max(0, Math.floor((now-Date.parse(stamp))/1000))
        if (!isFinite(secs)) return "Waiting for data"
        return secs < 60 ? "Updated just now" : "Updated " + Math.floor(secs/60) + "m ago"
    }
    function val(n, unit) {return n === null || n === undefined ? "—" : String(n) + (unit || "")}
    function showFilter(name) {
        settingsOpen=false
        expanded=false
        filter=name === "Live" ? "Live" : "Races"
        cursorIndex=0
        detailView="overview"
        Qt.callLater(function(){scroller.contentY=0})
    }
    function titleStatus(s) { return ({live:"LIVE",finished:"FINISHED",upcoming:"UPCOMING",scheduled:"SCHEDULED",unknown:"STATUS UNKNOWN"})[s] || "WAITING" }
    function configure() {
        if(service) for(var key in preferences) service[key]=preferences[key]
    }
    function persistSettings(changes) {
        if(Object.keys(changes).every(function(k){return preferences[k]===changes[k]})) return
        var entry=Object.assign({},settings || {},changes,{id:moduleName})
        if(bar && bar.shell && bar.shell.updateEntryInline(moduleName,entry)) {
            settings=entry
            settingsError=""
        } else settingsError="Could not save settings. Please try again."
    }
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
        var path = selected ? selected.path + (expanded && detailView === "events" ? "/live/race-events" : selected.status === "live" || selected.status === "upcoming" ? "/live" : "") : ""
        if(path && !/^race\/[a-z0-9-]+\/\d{4}\/(result|stage-\d+[a-z]?)(\/live(\/race-events)?)?$/.test(path)) return
        Quickshell.execDetached(["/usr/bin/xdg-open","https://www.procyclingstats.com/" + path])
    }
    onServiceChanged: configure()
    onPreferencesChanged: configure()
    onSettingsOpenChanged: Qt.callLater(function(){scroller.contentY=0})
    onFilterChanged: { cursorIndex = 0; expanded = false }
    onSelectedChanged: {
        var path = selected ? selected.path : ""
        if(path !== lastSelectedPath) {classificationKind="gc";detailView="overview";lastSelectedPath=path}
        if(opened && expanded && service && selected) service.watch(selected.path)
    }
    onDetailViewChanged: Qt.callLater(function(){scroller.contentY=0})
    onOpenedChanged: {
        if(opened) {now=Date.now(); configure(); if(service){service.refresh();if(expanded && selected)service.watch(selected.path)} Qt.callLater(function(){keys.forceActiveFocus()})}
    }
    Timer { interval:15000; running:root.opened || root.connection.visible; repeat:true; onTriggered:root.now=Date.now() }
    Connections {
        target:root.service
        function onUpdateIssuesChanged() {root.now=Date.now()}
        function onNextAllowedChanged() {root.now=Date.now()}
    }
    IpcHandler {
        target: "io.github.vip32.procyclingstats.panel"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function expand(): void { root.open(); root.select(root.cursorIndex, true) }
        function events(): void { root.open(); root.select(root.cursorIndex,true); root.detailView="events" }
        function setDetailView(view: string): void { root.detailView=view==="events" ? "events" : "overview" }
        function settings(): void { root.settingsOpen=true;root.open() }
        function showRaces(): void { root.showFilter("Races") }
        function compact(): void { root.expanded = false; root.open() }
        function selectRace(index: int): void { root.filter = "Races"; root.open(); root.select(index, true) }
        function restoreView(filterName: string, path: string, expanded: bool, opened: bool): void {
            root.filter = filterName === "Live" ? "Live" : "Races"
            var i = root.rows.findIndex(function(r){return r.path === path})
            root.cursorIndex = Math.max(0,i)
            root.expanded = expanded
            if(opened) root.open(); else root.close()
        }
        function status(): string {
            return JSON.stringify({opened:root.opened, expanded:root.expanded, serviceReady:!!root.service,
                detailView:root.detailView, eventsCount:(root.detail.events || []).length, eventsState:root.detail.eventsState || "", filter:root.filter, rows:root.rows.length, selected:root.selected ? root.selected.path : "", detailState:root.detail.state || "",
                geometry:{x:panel.cardOrigin.x,y:panel.cardOrigin.y,width:panel.contentWidth,height:panel.contentHeight,screen:panel.screen ? panel.screen.name : ""},
                riderCount:(root.detail.groups || []).reduce(function(n,g){return n+(g.riders || []).length},0),
                classificationRows:(root.classification.rows || []).length, classificationTitle:root.classification.title || "",
                warning:root.connection,settingsOpen:root.settingsOpen,settings:root.preferences,
                demo:root.demo, vertical:root.bar ? root.bar.vertical : false})
        }
    }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        iconComponent: Component { RaceBike {color:root.connection.visible ? root.warningColor : button.foreground} }
        tooltipText: "ProCyclingStats · road cycling\n" + (root.connection.visible ? root.connection.title+"\n"+root.connection.text : root.demo ? "DEMO — fictional races" : root.service && root.service.error ? root.service.error : root.races.filter(function(r){return r.status === "live"}).length + " live · " + root.races.length + " races today") + "\nLeft click: races · Right click: PCS · Middle click: refresh"
        onPressed: function(code) {
            if(code===Qt.LeftButton)root.toggle()
            else if(code===Qt.RightButton)root.openSource()
            else if(code===Qt.MiddleButton && root.service)root.service.refresh()
        }
        Rectangle {
            visible: !root.connection.visible && root.races.some(function(r){return r.status === "live"}) && !root.demo && root.service && root.service.state === "ready"
            width: Style.space(4); height:width; radius:width/2
            color: Color.accent
            anchors.right:parent.right; anchors.top:parent.top
            anchors.topMargin:Style.space(4); anchors.rightMargin:Style.space(2)
        }
        RaceText {
            visible:root.connection.visible;text:"!";font.bold:true;color:root.warningColor
            font.pixelSize:Style.font.caption;anchors.right:parent.right;anchors.top:parent.top
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
        contentWidth:panel.fittedContentWidth(Style.space(root.expanded || root.settingsOpen ? 590 : 420))
        contentHeight:panel.fittedContentHeight(column.implicitHeight+connectionBanner.height+(connectionBanner.visible ? Style.space(12) : 0),Style.space(root.expanded || root.settingsOpen ? 720 : 560))
        PanelKeyCatcher {
            id:keys
            anchors.fill:parent
            onMoveRequested:function(dx,dy){if(root.settingsOpen)settingsPage.move(dx,dy);else if(dy!==0)root.select(root.cursorIndex+dy,root.expanded)}
            onActivateRequested:{if(root.settingsOpen)settingsPage.activate();else root.select(root.cursorIndex,true)}
            onCloseRequested:{if(root.settingsOpen)root.settingsOpen=false;else if(root.expanded)root.expanded=false;else root.close()}
            onTabRequested:function(direction){root.switchPanel(direction)}
            onTextKey:function(text){
                var k=text.toLowerCase()
                if(k===","){root.settingsOpen=!root.settingsOpen;return}
                if(k==="1"){root.showFilter("Races");return}
                if(k==="2"){root.showFilter("Live");return}
                if(root.settingsOpen)return
                if(k==="r" && root.service)root.service.refresh()
                if(k==="o")root.openSource()
                if(k==="t" && root.expanded)root.detailView=root.detailView==="events" ? "overview" : "events"
                if(k==="e" && root.selected){root.expanded=!root.expanded;root.select(root.cursorIndex,root.expanded)}
            }
            BorderSurface {
                id:connectionBanner
                visible:root.connection.visible
                width:parent.width;height:visible ? warningText.implicitHeight+Style.space(20) : 0
                color:"transparent";radius:Style.cornerRadius
                borderSpec:Border.controlSpec("normal",root.warningColor,root.warningColor)
                Column {
                    id:warningText;x:Style.space(10);y:Style.space(10);width:parent.width-Style.space(20);spacing:Style.space(4)
                    RaceText {width:parent.width;text:"⚠ "+root.connection.title;font.bold:true;color:root.warningColor}
                    RaceText {width:parent.width;text:root.connection.text;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground;font.pixelSize:Style.font.caption}
                }
            }
            Flickable {
                id:scroller
                anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
                anchors.top:connectionBanner.bottom;anchors.topMargin:connectionBanner.visible ? Style.space(12) : 0
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
                            RaceText {width:parent.width;text:root.settingsOpen ? "Settings" : "ProCyclingStats";font.pixelSize:Style.font.title;font.bold:true;color:root.foreground}
                            RaceText {width:parent.width;text:root.demo ? "DEMO · fictional road races" : root.service && root.service.loading ? "Refreshing races…" : "Road cycling · " + root.age(root.service ? root.service.fetchedAt : "");font.pixelSize:Style.font.caption;color:root.dim}
                        }
                        Row {
                            id:actions;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
                            Button {text:"\uf11e";tooltipText:"Races (1)";Accessible.name:"Races";selected:root.filter==="Races" && !root.settingsOpen && !root.expanded;bordered:true;foreground:root.foreground;onClicked:root.showFilter("Races")}
                            Button {text:"◉";tooltipText:"Live races (2)";Accessible.name:"Live races";selected:root.filter==="Live" && !root.settingsOpen && !root.expanded;bordered:true;foreground:root.foreground;onClicked:root.showFilter("Live")}
                            Button {text:"↻";tooltipText:"Refresh races (R)";bordered:true;foreground:root.foreground;onClicked:if(root.service)root.service.refresh()}
                            Button {text:"↗";tooltipText:"Open PCS in browser (O)";Accessible.name:"Open ProCyclingStats in browser";bordered:true;foreground:root.foreground;onClicked:root.openSource()}
                            Button {text:root.settingsOpen ? "←" : "⚙";tooltipText:root.settingsOpen ? "Back to races" : "Settings (,)";bordered:true;foreground:root.foreground;onClicked:{if(root.settingsOpen)root.showFilter("Races");else root.settingsOpen=true}}
                            Button {visible:root.expanded && !root.settingsOpen;text:"↙";tooltipText:"Back to races";bordered:true;foreground:root.foreground;onClicked:root.showFilter("Races")}
                        }
                    }
                    PanelSeparator {foreground:root.foreground}
                    SettingsPage {
                        id:settingsPage;width:parent.width;visible:root.settingsOpen
                        values:root.preferences;foreground:root.foreground;feedback:root.settingsError
                        onChanged:function(changes){root.persistSettings(changes)}
                    }
                    Column {
                    width:parent.width;spacing:Style.spacing.panelGap;visible:!root.settingsOpen
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
                        PanelSectionHeader {text:root.filter==="Live" ? "LIVE RACES" : "RACES";foreground:root.foreground}
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
                            text:root.service && root.service.error ? "Race data is unavailable. Use ↗ in the header to open PCS." : root.service && root.service.state==="loading" ? "Loading today’s races…" : root.filter==="Live" ? "No live races listed right now." : "No races listed today."
                            color:root.dim;wrapMode:Text.WordWrap;elide:Text.ElideNone
                        }
                    }
                    Column {
                        visible:root.expanded && !!root.selected
                        width:parent.width;spacing:Style.space(12)
                        RaceText {width:parent.width;text:root.selected ? root.selected.name : "";font.pixelSize:Style.font.title;font.bold:true;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground}
                        RaceText {width:parent.width;text:[root.titleStatus(root.detail.status || (root.selected ? root.selected.status : "")),root.detail.date || "",root.demo ? "Fictional snapshot" : root.detail.fetchedAt ? root.age(root.detail.sourceAt || root.detail.fetchedAt) : root.detail.error ? "Race data unavailable" : root.finished ? "Loading results…" : "Loading LiveStats…"].filter(Boolean).join(" · ");font.pixelSize:Style.font.caption;color:Color.accent}
                        RaceText {width:parent.width;visible:!!root.detail.error;text:(root.detail.fetchedAt ? "Previous snapshot · " : "")+(root.detail.error || "");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Color.urgent}
                        Row {
                            width:parent.width;spacing:Style.space(6)
                            Button {width:(parent.width-Style.space(6))/2;text:"Overview";selected:root.detailView==="overview";bordered:true;foreground:root.foreground;onClicked:root.detailView="overview"}
                            Button {width:(parent.width-Style.space(6))/2;text:"Race events";selected:root.detailView==="events";bordered:true;foreground:root.foreground;onClicked:root.detailView="events"}
                        }
                        Column {
                            visible:root.detailView==="events"
                            width:parent.width;spacing:Style.space(10)
                            RaceText {width:parent.width;text:root.demo ? "Fictional race events" : root.detail.eventsFetchedAt ? root.age(root.detail.eventsFetchedAt) : "";color:root.dim;font.pixelSize:Style.font.caption}
                            RaceEvents {width:parent.width;events:root.detail.events || [];state:root.detail.eventsState || "";error:root.detail.eventsError || (root.detail.error ? "Events could not be refreshed." : "");textColor:root.foreground}
                        }
                        Column {
                            visible:root.detailView==="overview" && root.finished
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
                            RaceText {width:parent.width;visible:!root.classifications.length;text:root.detail.resultsError || (root.detail.error ? "Results could not be loaded. Open PCS with ↗ in the header." : "Waiting for published results…");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.dim}
                            RaceText {width:parent.width;visible:root.detail.stageRace===true && root.detail.gcAvailable===false;text:"General classification is not published on this stage page yet.";wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.dim}
                        }
                        RaceOverview {
                            visible:root.detailView==="overview" && !root.finished
                            width:parent.width;detail:root.detail;foreground:root.foreground
                        }
                    }
                    RaceText {width:parent.width;text:"J/K select · Enter details · T events · R refresh · Esc back";font.pixelSize:Style.font.caption;color:root.dim;horizontalAlignment:Text.AlignHCenter}
                    }
                }
            }
        }
    }
}

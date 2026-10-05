import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    readonly property var todayRaces: service ? service.races.filter(function(r){return Model.matchesRace(r,preferences)}) : []
    property int dayOffset: 0
    readonly property bool archive: filter==="Calendar"
    property string archiveMode: "recent"
    property int archiveCount: preferences.archiveRaceCount
    property var archiveSelection: null
    readonly property var archiveData: service ? service.archives[archiveMode] || ({state:"loading",races:[]}) : ({})
    readonly property int archiveAvailableCount: Model.archiveRows(archiveData.races || [],archiveMode,Model.dayKey(now,0),preferences,100).length
    readonly property bool archiveBusy: service ? service.archiveBusy(archiveMode) : false
    readonly property string dayDate: Model.dayKey(now,dayOffset)
    readonly property var dayData: archive ? archiveData : !service ? ({}) : dayOffset === 0 ? {state:service.state,error:service.error,fetchedAt:service.fetchedAt,races:service.races} : service.dayLists[dayDate] || ({state:"loading"})
    readonly property var unfilteredRaces: dayData.races || []
    readonly property var races: unfilteredRaces.filter(function(r){return Model.matchesRace(r,preferences)})
    readonly property bool filtersActive: Model.filtersActive(preferences)
    readonly property bool preview: selected && selected.date>Model.dayKey(now,0) && !finished
    readonly property bool demo: service ? service.demo : false
    readonly property var rows: archive ? Model.archiveRows(unfilteredRaces,archiveMode,Model.dayKey(now,0),preferences,archiveCount) : filter === "Live" ? races.filter(function(r) {return r.status === "live"}) : races
    readonly property var selected: archive && expanded && archiveSelection ? archiveSelection : rows.length ? rows[Math.max(0,Math.min(cursorIndex,rows.length-1))] : null
    readonly property var detail: selected && service ? service.details[selected.path] || ({}) : ({})
    readonly property var preferences: Model.settings(demo ? {} : settings)
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
    property bool detached: false
    readonly property bool dashboardVisible: opened || (detached && dashboardWindow.visible)
    function restorePosition(offset) {
        Qt.callLater(function(){
            scroller.contentY=Math.max(0,Math.min(offset,Math.max(0,scroller.contentHeight-scroller.height)))
            if(dashboardVisible) keys.forceActiveFocus()
        })
    }
    function focusWindow() {
        dashboardWindow.visible=true
        dashboardWindow.minimized=false
        Qt.callLater(function(){
            var toplevel=ToplevelManager.toplevels.values.find(function(t){return t.title===dashboardWindow.title})
            if(toplevel) toplevel.activate()
            else {
                var nativeWindow=windowMount.Window.window
                if(nativeWindow) nativeWindow.requestActivate()
            }
            keys.forceActiveFocus()
        })
    }
    function showDashboard() {
        if(service && service.windowOwner && service.windowOwner !== root) {service.windowOwner.focusWindow();return}
        if(detached) focusWindow()
        else controller.show()
    }
    function hideDashboard() {
        if(service && service.windowOwner && service.windowOwner !== root) {service.windowOwner.hideDashboard();return}
        if(detached) dashboardWindow.visible=false
        controller.hide()
    }
    function detachDashboard() {
        if(service && !service.claimWindow(root)) {service.windowOwner.focusWindow();return}
        var offset=scroller.contentY
        detached=true
        controller.hide()
        focusWindow()
        restorePosition(offset)
    }
    function dockDashboard() {
        if(service && service.windowOwner && service.windowOwner !== root) {service.windowOwner.dockDashboard();return}
        var offset=scroller.contentY
        detached=false
        dashboardWindow.visible=false
        if(service)service.releaseWindow(root)
        controller.show()
        restorePosition(offset)
    }
    function toggleWindow() {if(detached)dockDashboard();else detachDashboard()}
    Component.onDestruction: {if(service)service.releaseWindow(root)}
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
        if(name === "Live") dayOffset=0
        filter=name === "Live" ? "Live" : name==="Calendar" ? "Calendar" : "Races"
        archiveSelection=null
        cursorIndex=0
        detailView="overview"
        Qt.callLater(function(){scroller.contentY=0})
    }
    function showCalendar(mode) {
        if(service && archiveMode!==mode) service.stopArchive(archiveMode)
        archiveMode=mode==="upcoming" ? "upcoming" : "recent"
        archiveCount=preferences.archiveRaceCount
        showFilter("Calendar")
        if(service) service.watchArchive(archiveMode,archiveCount,false)
    }
    function refreshView() {
        if(!service)return
        if(archive)service.refreshArchive(archiveMode,archiveCount)
        else service.refresh()
    }
    function showDay(offset) {
        showFilter("Races")
        dayOffset=Math.max(-1,Math.min(1,offset))
        if(service) service.watchDay(dayDate)
    }
    onDayDateChanged: {
        cursorIndex=0; expanded=false
        if(service) {service.checkDate(now);service.watchDay(dayDate)}
        if(archive && service)service.watchArchive(archiveMode,archiveCount,false)
    }
    function titleStatus(s) { return ({live:"LIVE",finished:"FINISHED",upcoming:"UPCOMING",scheduled:"SCHEDULED",unknown:"STATUS UNKNOWN"})[s] || "WAITING" }
    function configure() {
        if(service) {
            var filters={minimumRaceLevel:preferences.minimumRaceLevel}
            Model.categories().forEach(function(c){filters[c.key]=preferences[c.key]})
            if(JSON.stringify(service.raceFilters)!==JSON.stringify(filters)) service.raceFilters=filters
            for(var key in preferences) if(key in service && key!=="raceFilters") service[key]=preferences[key]
        }
    }
    function persistSettings(changes) {
        if(demo) {settingsError="Demo settings are read-only.";return}
        if(Object.keys(changes).every(function(k){return preferences[k]===changes[k]})) return
        var entry=Object.assign({},settings || {},changes,{id:moduleName})
        if(bar && bar.shell && bar.shell.updateEntryInline(moduleName,entry)) {
            settings=entry
            settingsError=""
        } else settingsError="Could not save settings. Please try again."
    }
    function select(index, show) {
        cursorIndex = Math.max(0,Math.min(rows.length-1,index))
        if(archive && show) {archiveSelection=rows[cursorIndex] || null;if(service)service.stopArchive(archiveMode)}
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
        var sourcePath=selected ? (expanded && detailView==="events" && detail.stagePath ? detail.stagePath : selected.path) : ""
        var path = selected ? sourcePath + (expanded && detailView === "events" ? "/live/race-events" : !preview && (selected.status === "live" || selected.status === "upcoming") ? "/live" : "") : ""
        openPcsPath(path)
    }
    function openPcsPath(path) {
        if(path && !/^race\/[a-z0-9-]+\/\d{4}\/(result|gc|stage-\d+[a-z]?)(\/live(\/race-events)?)?$/.test(path)) return
        Quickshell.execDetached(["/usr/bin/xdg-open","https://www.procyclingstats.com/" + path])
    }
    onServiceChanged: configure()
    onPreferencesChanged: {
        configure();archiveCount=preferences.archiveRaceCount;cursorIndex=0;expanded=false
        if(archive && dashboardVisible && service)service.watchArchive(archiveMode,archiveCount,false)
    }
    onDemoChanged: settingsError=""
    onSettingsOpenChanged: Qt.callLater(function(){scroller.contentY=0})
    onFilterChanged: { cursorIndex = 0; expanded = false;if(!archive && service){service.stopArchive("recent");service.stopArchive("upcoming")} }
    onSelectedChanged: {
        var path = selected ? selected.path : ""
        if(path !== lastSelectedPath) {classificationKind="gc";detailView="overview";lastSelectedPath=path}
        if(dashboardVisible && expanded && service && selected) service.watch(selected.path)
    }
    onDetailViewChanged: Qt.callLater(function(){scroller.contentY=0})
    onDashboardVisibleChanged: {
        if(dashboardVisible) {now=Date.now(); configure(); if(service){service.refresh();service.watchDay(dayDate);if(expanded && selected)service.watch(selected.path)} Qt.callLater(function(){keys.forceActiveFocus()})}
    }
    Connections {
        target:root
        function onDashboardVisibleChanged() {
            if(root.archive && root.service) {
                if(root.dashboardVisible && !root.expanded)root.service.watchArchive(root.archiveMode,root.archiveCount,false)
                else root.service.stopArchive(root.archiveMode)
            }
        }
    }
    Timer { interval:15000; running:root.dashboardVisible || root.connection.visible; repeat:true; onTriggered:root.now=Date.now() }
    Connections {
        target:root.service
        function onUpdateIssuesChanged() {root.now=Date.now()}
        function onNextAllowedChanged() {root.now=Date.now()}
    }
    IpcHandler {
        target: "io.github.vip32.procyclingstats.panel"
        function detach(): void { root.detachDashboard() }
        function dock(): void { root.dockDashboard() }
        function open(): void { root.showDashboard() }
        function close(): void { root.hideDashboard() }
        function expand(): void { root.showDashboard(); root.select(root.cursorIndex, true) }
        function events(): void { root.showDashboard(); root.select(root.cursorIndex,true); root.detailView="events" }
        function setDetailView(view: string): void { root.detailView=view==="events" ? "events" : "overview" }
        function settings(): void { root.settingsOpen=true;root.showDashboard() }
        function settingsSection(section: string): void {
            root.settingsOpen=true;root.showDashboard()
            settingsPage.cursorIndex=section==="refresh" ? settingsPage.fieldsStart : 0
            Qt.callLater(function(){
                var y=section==="refresh" ? settingsPage.cursorItem().mapToItem(column,0,0).y-Style.space(30) : 0
                scroller.contentY=Math.max(0,Math.min(y,Math.max(0,scroller.contentHeight-scroller.height)))
            })
        }
        function restoreScroll(offset: int, cursor: int): void {
            settingsPage.cursorIndex=Math.max(0,Math.min(settingsPage.notificationIndex,cursor))
            Qt.callLater(function(){scroller.contentY=Math.max(0,Math.min(offset,Math.max(0,scroller.contentHeight-scroller.height)))})
        }
        function showDay(offset: int): void { root.showDay(offset) }
        function showRaces(): void { root.showFilter("Races") }
        function calendar(mode: string): void {root.showCalendar(mode);root.showDashboard()}
        function restoreCalendar(mode: string, count: int): void {
            root.archiveMode=mode==="upcoming" ? "upcoming" : "recent"
            root.archiveCount=Math.max(10,Math.min(100,count))
            root.showFilter("Calendar")
            if(root.service)root.service.watchArchive(root.archiveMode,root.archiveCount,false)
        }
        function compact(): void { root.expanded = false; root.showDashboard() }
        function selectRace(index: int): void { if(!root.archive)root.filter = "Races"; root.showDashboard(); root.select(index, true) }
        function restoreView(filterName: string, path: string, expanded: bool, opened: bool): void {
            root.filter = filterName === "Live" ? "Live" : filterName==="Calendar" ? "Calendar" : "Races"
            var i = root.rows.findIndex(function(r){return r.path === path})
            root.cursorIndex = Math.max(0,i)
            if(root.archive)root.archiveSelection=root.rows[root.cursorIndex] || null
            root.expanded = expanded
            if(opened) root.showDashboard(); else root.hideDashboard()
        }
        function status(): string {
            return JSON.stringify({opened:root.dashboardVisible,detached:root.detached,windowVisible:dashboardWindow.visible,expandedGroups:raceOverview.expandedGroupCount(), expanded:root.expanded, serviceReady:!!root.service,
                archiveMode:root.archiveMode,archiveCount:root.archiveCount,archiveBusy:root.archiveBusy,archiveDates:root.archiveData.dates || [],dayOffset:root.dayOffset,date:root.dayDate,dayState:root.dayData.state || "",detailView:root.detailView, eventsCount:(root.detail.events || []).length, eventsState:root.detail.eventsState || "", filter:root.filter, rows:root.rows.length, selected:root.selected ? root.selected.path : "", detailState:root.detail.state || "",
                geometry:{x:panel.cardOrigin.x,y:panel.cardOrigin.y,width:panel.contentWidth,height:panel.contentHeight,screen:panel.screen ? panel.screen.name : ""},
                riderCount:(root.detail.groups || []).reduce(function(n,g){return n+(g.riders || []).length},0),
                classificationRows:(root.classification.rows || []).length, classificationTitle:root.classification.title || "",
                filtersActive:root.filtersActive,unfilteredRows:root.unfilteredRaces.length,settingsCursor:settingsPage.cursorIndex,scrollY:Math.round(scroller.contentY),warning:root.connection,settingsOpen:root.settingsOpen,settings:root.preferences,
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
        tooltipText: "ProCyclingStats · road cycling\n" + (root.connection.visible ? root.connection.title+"\n"+root.connection.text : root.demo ? "DEMO — fictional races" : root.service && root.service.error ? root.service.error : root.todayRaces.filter(function(r){return r.status === "live"}).length + " live · " + root.todayRaces.length + " races today") + "\nLeft click: races · Right click: PCS · Middle click: refresh"
        onPressed: function(code) {
            if(code===Qt.LeftButton){if(root.detached || (root.service && root.service.windowOwner))root.showDashboard();else root.toggle()}
            else if(code===Qt.RightButton)root.openSource()
            else if(code===Qt.MiddleButton && root.service)root.service.refresh()
        }
        Rectangle {
            visible: !root.connection.visible && root.todayRaces.some(function(r){return r.status === "live"}) && !root.demo && root.service && root.service.state === "ready"
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
    FloatingWindow {
        id:dashboardWindow
        title:"ProCyclingStats — Race dashboard"
        visible:false
        // Synchronize the requested visibility after a compositor-initiated close.
        // Otherwise Quickshell can retain its old true request and ignore reopening.
        onClosed: visible=false
        color:Color.background
        implicitWidth:Style.space(760)
        implicitHeight:Style.space(760)
        minimumSize:Qt.size(Style.space(500),Style.space(360))
        Item {
            id:windowMount
            anchors.top:parent.top;anchors.bottom:parent.bottom
            anchors.topMargin:Style.space(16);anchors.bottomMargin:Style.space(16)
            anchors.horizontalCenter:parent.horizontalCenter
            width:Math.min(parent.width-Style.space(32),Style.space(900))
        }
    }
    KeyboardPanel {
        id: panel
        anchorItem:button
        owner:root
        bar:root.bar
        open:root.opened && !root.detached
        centerOnBar:false
        focusTarget:keys
        contentWidth:panel.fittedContentWidth(Style.space(root.expanded || root.settingsOpen || root.archive ? 590 : 420))
        contentHeight:panel.fittedContentHeight(column.implicitHeight+connectionBanner.height+(connectionBanner.visible ? Style.space(12) : 0),Style.space(root.expanded || root.settingsOpen || root.archive ? 720 : 560))
        Item {id:popupMount;anchors.fill:parent}
        PanelKeyCatcher {
            id:keys
            parent:root.detached ? windowMount : popupMount
            anchors.fill:parent
            onMoveRequested:function(dx,dy){if(root.settingsOpen)settingsPage.move(dx,dy);else if(dx!==0 && !root.expanded){if(root.archive)root.showCalendar(dx>0 ? "upcoming" : "recent");else root.showDay(root.dayOffset+dx)}else if(dy!==0)root.select(root.cursorIndex+dy,root.expanded)}
            onActivateRequested:{if(root.settingsOpen)settingsPage.activate();else root.select(root.cursorIndex,true)}
            onCloseRequested:{if(root.settingsOpen)root.settingsOpen=false;else if(root.expanded)root.expanded=false;else root.hideDashboard()}
            onTabRequested:function(direction){if(!root.detached)root.switchPanel(direction)}
            onTextKey:function(text){
                var k=text.toLowerCase()
                if(k==="p"){root.toggleWindow();return}
                if(k===","){root.settingsOpen=!root.settingsOpen;return}
                if(k==="1"){root.showFilter("Races");return}
                if(k==="2"){root.showFilter("Live");return}
                if(k==="3"){root.showCalendar(root.archiveMode);return}
                if(root.settingsOpen)return
                if(k==="r")root.refreshView()
                if(k==="o")root.openSource()
                if(k==="t" && root.expanded && !root.preview)root.detailView=root.detailView==="events" ? "overview" : "events"
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
                            RaceText {width:parent.width;text:root.settingsOpen ? "Settings" : root.archive && !root.expanded ? "Race calendar" : "ProCyclingStats";font.pixelSize:Style.font.title;font.bold:true;color:root.foreground}
                            RaceText {width:parent.width;text:root.demo ? "DEMO · fictional road races" : root.service && root.service.loading ? "Refreshing races…" : "Road cycling · " + root.age(root.dayData.fetchedAt || "");font.pixelSize:Style.font.caption;color:root.dim}
                        }
                        Row {
                            id:actions;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(6)
                            Button {text:"\uf11e";tooltipText:"Races (1)";Accessible.name:"Races";selected:root.filter==="Races" && !root.settingsOpen && !root.expanded;bordered:true;foreground:root.foreground;onClicked:root.showFilter("Races")}
                            Button {text:"◉";tooltipText:"Live races (2)";Accessible.name:"Live races";selected:root.filter==="Live" && !root.settingsOpen && !root.expanded;bordered:true;foreground:root.foreground;onClicked:root.showFilter("Live")}
                            Button {text:"↻";tooltipText:"Refresh races (R)";bordered:true;foreground:root.foreground;onClicked:root.refreshView()}
                            Button {text:root.detached ? "▣" : "□";tooltipText:root.detached ? "Dock back to bar (P)" : "Pop out to window (P)";Accessible.name:tooltipText;bordered:true;foreground:root.foreground;onClicked:root.toggleWindow()}
                            Button {text:"↗";tooltipText:"Open PCS in browser (O)";Accessible.name:"Open ProCyclingStats in browser";bordered:true;foreground:root.foreground;onClicked:root.openSource()}
                            Button {text:root.settingsOpen ? "←" : "⚙";tooltipText:root.settingsOpen ? "Back to races" : "Settings (,)";bordered:true;foreground:root.foreground;onClicked:{if(root.settingsOpen)root.showFilter("Races");else root.settingsOpen=true}}
                            Button {visible:root.expanded && !root.settingsOpen;text:"↙";tooltipText:"Back to race list";bordered:true;foreground:root.foreground;onClicked:{root.expanded=false;root.detailView="overview"}}
                        }
                    }
                    PanelSeparator {foreground:root.foreground}
                    SettingsPage {
                        id:settingsPage;width:parent.width;visible:root.settingsOpen
                        values:root.preferences;foreground:root.foreground;feedback:root.settingsError
                        onChanged:function(changes){root.persistSettings(changes)}
                        onReveal:function(item){
                            if(!item) return
                            var y=item.mapToItem(column,0,0).y
                            if(y<scroller.contentY)scroller.contentY=y
                            else if(y+item.height>scroller.contentY+scroller.height)scroller.contentY=y+item.height-scroller.height
                        }
                    }
                    Column {
                    width:parent.width;spacing:Style.spacing.panelGap;visible:!root.settingsOpen
                    RaceText {
                        width:parent.width
                        visible:!!root.dayData.error
                        text:(root.races.length ? "Showing previous data. " : "")+(root.dayData.error || "")
                        color:Color.urgent
                        wrapMode:Text.WordWrap
                        elide:Text.ElideNone
                    }
                    Column {
                        visible:!root.expanded || !root.selected
                        width:parent.width;spacing:Style.space(4)
                        Row {
                            visible:!root.archive
                            width:parent.width;spacing:Style.space(6)
                            Button {id:previousDay;text:"‹";enabled:root.dayOffset>-1;tooltipText:"Previous day (Left)";Accessible.name:"Previous day";bordered:true;foreground:root.foreground;onClicked:root.showDay(root.dayOffset-1)}
                            Button {width:parent.width-previousDay.width-nextDay.width-calendarButton.width-Style.space(18);text:Model.dayLabel(root.now,root.dayOffset);tooltipText:"Return to today";Accessible.name:text;foreground:root.foreground;onClicked:root.showDay(0)}
                            Button {id:nextDay;text:"›";enabled:root.dayOffset<1;tooltipText:"Next day (Right)";Accessible.name:"Next day";bordered:true;foreground:root.foreground;onClicked:root.showDay(root.dayOffset+1)}
                            Button {id:calendarButton;text:"\uf073";tooltipText:"Recent & upcoming races (3)";Accessible.name:"Race calendar";bordered:true;foreground:root.foreground;onClicked:root.showCalendar("recent")}
                        }
                        Row {
                            visible:root.archive;width:parent.width;spacing:Style.space(6)
                            Button {width:(parent.width-countButton.width-Style.space(12))/2;text:"Recent";selected:root.archiveMode==="recent";bordered:true;foreground:root.foreground;onClicked:root.showCalendar("recent")}
                            Button {width:(parent.width-countButton.width-Style.space(12))/2;text:"Upcoming";selected:root.archiveMode==="upcoming";bordered:true;foreground:root.foreground;onClicked:root.showCalendar("upcoming")}
                            Button {id:countButton;text:(root.archiveMode==="recent" ? "Last " : "Next ")+root.archiveCount;tooltipText:"Change the default race count in Settings";bordered:true;foreground:root.foreground;onClicked:{root.settingsOpen=true;Qt.callLater(function(){settingsPage.cursorIndex=settingsPage.fieldsStart;settingsPage.reveal(settingsPage.cursorItem())})}}
                        }
                        RaceText {
                            width:parent.width;visible:root.archive
                            text:root.archiveBusy ? "Searching the race calendar…" : root.archiveData.dates && root.archiveData.dates.length ? "Searched "+root.archiveData.dates[0]+" — "+root.archiveData.dates[root.archiveData.dates.length-1]+" · "+root.rows.length+" races" : "Choose recent or upcoming races"
                            font.pixelSize:Style.font.caption;color:root.dim;wrapMode:Text.WordWrap
                        }
                        RaceText {width:parent.width;visible:root.filtersActive;text:"Filters active · "+root.races.length+" of "+root.unfilteredRaces.length+" races · change in Settings";font.pixelSize:Style.font.caption;color:root.dim}
                        Repeater {
                            id:raceRepeater
                            model:root.rows
                            CursorSurface {
                                id:raceRow
                                required property var modelData
                                required property int index
                                width:parent.width;height:Math.max(Style.space(56),raceLabels.implicitHeight+Style.space(12))
                                bordered:true;foreground:root.foreground
                                hasCursor:root.cursorIndex===index
                                MouseArea {anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:root.cursorIndex=raceRow.index;onClicked:root.select(raceRow.index,true)}
                                Column {
                                    id:raceLabels
                                    anchors.left:parent.left;anchors.leftMargin:Style.space(8)
                                    anchors.right:miniProfile.left;anchors.rightMargin:Style.space(8)
                                    anchors.verticalCenter:parent.verticalCenter;spacing:Style.space(2)
                                    RaceText {width:parent.width;text:raceRow.modelData.name;font.bold:true;color:root.foreground}
                                    RaceText {width:parent.width;text:[root.archive ? raceRow.modelData.date : root.titleStatus(raceRow.modelData.status),raceRow.modelData.category,raceRow.modelData.eta ? "ETA "+raceRow.modelData.eta : ""].filter(Boolean).join(" · ");font.pixelSize:Style.font.caption;color:raceRow.modelData.status==="live" ? Color.accent : root.dim}
                                }
                                Column {
                                    id:miniProfile;anchors.right:parent.right;anchors.rightMargin:Style.space(8)
                                    readonly property bool hasProfile:(raceRow.modelData.profile || []).length>1
                                    anchors.verticalCenter:parent.verticalCenter;width:Style.space(hasProfile || raceRow.modelData.toGo ? 84 : 24)
                                    Profile {visible:miniProfile.hasProfile;width:parent.width;height:Style.space(20);points:raceRow.modelData.profile || [];lineColor:Color.accent}
                                    Row {
                                        width:parent.width;height:Style.space(24);spacing:Style.space(4)
                                        RaceText {width:parent.width-raceLink.width-parent.spacing;anchors.verticalCenter:parent.verticalCenter;text:raceRow.modelData.toGo || "";horizontalAlignment:Text.AlignRight;font.pixelSize:Style.font.caption;color:root.dim}
                                        Button {
                                            id:raceLink;width:Style.space(24);height:Style.space(24)
                                            text:"↗";foreground:root.foreground
                                            tooltipText:"Open "+raceRow.modelData.name+" on PCS"
                                            Accessible.name:tooltipText
                                            onClicked:root.openPcsPath(raceRow.modelData.path)
                                        }
                                    }
                                }

                            }
                        }
                        RaceText {
                            width:parent.width;visible:root.rows.length===0
                            text:root.dayData.error ? "Race data is unavailable. Use ↗ in the header to open PCS." : root.dayData.state==="loading" || root.archiveBusy ? "Loading races…" : root.archive ? "No matching races in the searched dates. Search further or change your filters." : root.filtersActive && root.unfilteredRaces.length ? "No races match these filters. Change them in Settings." : root.filter==="Live" ? "No live races listed right now." : "No races listed for this day."
                            color:root.dim;wrapMode:Text.WordWrap;elide:Text.ElideNone
                        }
                        Button {
                            visible:root.archive && (root.rows.length<root.archiveCount || root.archiveCount<100)
                            width:parent.width;enabled:!root.archiveBusy && (!root.archiveData.exhausted || root.archiveAvailableCount>root.archiveCount) && (!root.service || root.service.nextAllowed<=root.now)
                            text:root.archiveBusy ? "Searching…" : root.rows.length>=root.archiveCount && root.archiveCount<root.archiveAvailableCount ? "Show more races" : root.archiveData.exhausted ? (root.demo ? "End of demo calendar" : "Calendar search limit reached") : root.rows.length>=root.archiveCount ? "Show more races" : root.archiveMode==="recent" ? "Search older races" : "Search later races"
                            bordered:true;foreground:root.foreground
                            onClicked:{if(root.rows.length>=root.archiveCount)root.archiveCount=Math.min(100,root.archiveCount+25);if(root.service)root.service.watchArchive(root.archiveMode,root.archiveCount,true)}
                        }
                    }
                    Column {
                        visible:root.expanded && !!root.selected
                        width:parent.width;spacing:Style.space(12)
                        RaceText {width:parent.width;text:root.selected ? root.selected.name : "";font.pixelSize:Style.font.title;font.bold:true;wrapMode:Text.WordWrap;elide:Text.ElideNone;color:root.foreground}
                        RaceText {width:parent.width;text:[root.titleStatus(root.detail.status || (root.selected ? root.selected.status : "")),root.detail.date || (root.selected ? root.selected.date || "" : ""),root.demo ? "Fictional snapshot" : root.detail.fetchedAt ? root.age(root.detail.sourceAt || root.detail.fetchedAt) : root.detail.error ? "Race data unavailable" : root.finished ? "Loading results…" : root.preview ? "Loading race preview…" : "Loading LiveStats…"].filter(Boolean).join(" · ");font.pixelSize:Style.font.caption;color:Color.accent}
                        RaceText {width:parent.width;visible:!!root.detail.error;text:(root.detail.fetchedAt ? "Previous snapshot · " : "")+(root.detail.error || "");wrapMode:Text.WordWrap;elide:Text.ElideNone;color:Color.urgent}
                        Row {
                            visible:!root.preview
                            width:parent.width;spacing:Style.space(6)
                            Button {width:(parent.width-Style.space(6))/2;text:"Overview";selected:root.detailView==="overview";bordered:true;foreground:root.foreground;onClicked:root.detailView="overview"}
                            Button {width:(parent.width-Style.space(6))/2;text:"Race events";selected:root.detailView==="events";bordered:true;foreground:root.foreground;onClicked:root.detailView="events"}
                        }
                        Column {
                            visible:root.detailView==="events" && !root.preview
                            width:parent.width;spacing:Style.space(10)
                            RaceText {width:parent.width;text:root.demo ? "Fictional race events" : root.detail.eventsFetchedAt ? root.age(root.detail.eventsFetchedAt) : "";color:root.dim;font.pixelSize:Style.font.caption}
                            RaceEvents {width:parent.width;events:root.detail.events || [];state:root.detail.eventsState || "";error:root.detail.eventsError || (root.detail.error ? "Events could not be refreshed." : "");textColor:root.foreground}
                        }
                        Column {
                            visible:root.detailView==="overview" && root.finished
                            width:parent.width;spacing:Style.space(10)
                            RaceSummary {width:parent.width;detail:root.detail;foreground:root.foreground}
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
                        RacePreview {
                            visible:root.preview
                            width:parent.width;detail:root.detail;foreground:root.foreground
                        }
                        RaceOverview {
                            id:raceOverview
                            visible:root.detailView==="overview" && !root.finished && !root.preview
                            width:parent.width;detail:root.detail;foreground:root.foreground
                        }
                    }
                    RaceText {width:parent.width;text:root.expanded ? "J/K select · Enter details · R refresh · Esc back" : root.archive ? "←/→ Recent / Upcoming · Enter details · R refresh" : "←/→ day · J/K select · Enter details · R refresh";font.pixelSize:Style.font.caption;color:root.dim;horizontalAlignment:Text.AlignHCenter}
                    }
                }
            }
        }
    }
}

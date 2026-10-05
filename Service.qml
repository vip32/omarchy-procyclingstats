import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    // One detached dashboard across all bar instances/monitors.
    property QtObject windowOwner: null
    function claimWindow(owner) {
        if(windowOwner && windowOwner !== owner) return false
        windowOwner=owner
        return true
    }
    function releaseWindow(owner) { if(windowOwner === owner) windowOwner=null }
    property string state: "loading"
    property string error: ""
    property var races: []
    property var details: ({})
    property var dayLists: ({})
    property var archives: ({})
    property var archiveRequests: ({})
    property string today: Model.dayKey(Date.now(),0)
    property string currentRequestDate: today
    property string fetchedAt: ""
    property bool loading: worker.running
    property var queue: []
    property var watched: []
    property var lastRequests: ({})
    property string currentPath: ""
    property string output: ""
    property int refreshIntervalSec: 60
    property int overviewIntervalSec: 300
    property int resultsIntervalSec: 300
    property bool eventNotifications: false
    property int notificationDurationSec: 8
    property var updateIssues: ({})
    property string metadataFetchedAt: ""
    property var raceFilters: ({})
    onRaceFiltersChanged: eventBaselines = ({})
    property var eventBaselines: ({})
    readonly property var options: Model.settings(Object.assign({},raceFilters,{refreshIntervalSec:refreshIntervalSec,
        overviewIntervalSec:overviewIntervalSec,resultsIntervalSec:resultsIntervalSec,
        eventNotifications:eventNotifications,notificationDurationSec:notificationDurationSec}))
    property double nextAllowed: 0
    property bool demo: false
    onEventNotificationsChanged: eventBaselines = ({})

    function allRaces() {
        var all = races.slice()
        Object.keys(dayLists).forEach(function(date) { all = all.concat(dayLists[date].races || []) })
        Object.keys(archives).forEach(function(mode) {all=all.concat(archives[mode].races || [])})
        return all
    }
    function findRace(path) { return allRaces().filter(function(r) {return r.path === path})[0] }
    function checkDate(now) {
        var date = Model.dayKey(now,0)
        if (date === today || demo) return
        // Drop the old day's polling and snapshots; an in-flight response is
        // tagged with its start date and cannot populate the new today.
        today = date
        races = []; dayLists = ({}); details = ({}); watched = []
        archives=({});archiveRequests=({})
        queue = []; lastRequests = ({}); updateIssues = ({}); eventBaselines = ({})
        fetchedAt = ""; metadataFetchedAt = ""; state = "loading"; error = ""
    }
    function watchDay(date) {
        if ([Model.dayKey(Date.now(),-1),today,Model.dayKey(Date.now(),1)].indexOf(date)<0) return
        if (date === today) { enqueue(""); return }
        if (!dayLists[date]) {
            var next = Object.assign({},dayLists)
            next[date] = {state:"loading",races:[]}
            dayLists = next
        }
        enqueue("day:"+date)
    }
    function watchArchive(mode,count,more) {
        if(["recent","upcoming"].indexOf(mode)<0 || demo) return
        count=Math.max(10,Math.min(100,Math.round(count)||25))
        var data=archives[mode]
        if(!data) {
            var next=Object.assign({},archives)
            next[mode]={state:"loading",races:[],dates:[],nextDate:mode==="recent" ? today : Model.dayKey(Date.now(),1)}
            archives=next;data=next[mode]
        }
        if(!more && !data.reset && Model.archiveRows(data.races,mode,today,options,count).length>=count) return
        var requests=Object.assign({},archiveRequests)
        // Search at most 30 days per user action, stopping as soon as X matches exist.
        requests[mode]={count:count,remaining:data.reset ? 30 : Math.min(30,366-(data.dates || []).length)}
        archiveRequests=requests
        continueArchive(mode)
    }
    function refreshArchive(mode,count) {
        if(["recent","upcoming"].indexOf(mode)<0 || demo || archiveBusy(mode) || Date.now()<nextAllowed) return
        if(Date.now()-Number(lastRequests["archive:"+mode] || 0)<60000) return
        var next=Object.assign({},archives)
        next[mode]=Object.assign({},next[mode] || {},{reset:true,exhausted:false,nextDate:mode==="recent" ? today : Model.dayKey(Date.now(),1)})
        archives=next;watchArchive(mode,count,true)
    }
    function stopArchive(mode) {
        var requests=Object.assign({},archiveRequests);delete requests[mode];archiveRequests=requests
        queue=queue.filter(function(p){return p!=="archive:"+mode})
    }
    function continueArchive(mode) {
        var data=archives[mode], request=archiveRequests[mode]
        if(!data || !request || request.remaining<=0 || data.exhausted || Date.now()<nextAllowed) return
        if(!data.reset && Model.archiveRows(data.races,mode,today,options,request.count).length>=request.count) return
        enqueue("archive:"+mode)
    }
    function archiveBusy(mode) {return (worker.running && currentPath==="archive:"+mode) || queue.indexOf("archive:"+mode)>=0}
    function enqueue(path) {
        if (demo || Date.now() < nextAllowed) return
        var key = path || "overview"
        if ((worker.running && currentPath === path) || queue.indexOf(path) >= 0) return
        var race = findRace(path)
        var finished = race && (race.status === "finished" || race.date > today)
        if (path.indexOf("archive:")!==0 && Date.now() - Number(lastRequests[key] || 0) < Model.requestInterval(path, finished, options)) return
        queue = queue.concat([path]).slice(0, 5)
        runNext()
    }
    function watch(path) {
        if (!/^race\/[a-z0-9-]+\/\d{4}\/(result|gc|stage-\d+[a-z]?)$/.test(path)) return
        watched = [path].concat(watched.filter(function(p) { return p !== path })).slice(0, 3)
        enqueue(path)
    }
    function refresh() {
        checkDate(Date.now())
        enqueue("")
        Object.keys(dayLists).forEach(function(date) { enqueue("day:"+date) })
        for (var i = 0; i < watched.length; i++) enqueue(watched[i])
    }
    function runNext() {
        if (worker.running || !queue.length || demo || Date.now() < nextAllowed) return
        currentRequestDate = today
        currentPath = queue[0]
        queue = queue.slice(1)
        var times = Object.assign({}, lastRequests)
        times[currentPath || "overview"] = Date.now()
        lastRequests = times
        output = ""
        var script = decodeURIComponent(Qt.resolvedUrl("bin/pcs.py").toString().replace(/^file:\/\//, ""))
        worker.command = currentPath ? ["/usr/bin/python3", "-I", script, "race", "--race", currentPath]
                                     : ["/usr/bin/python3", "-I", script, "overview", "--date", today]
        if (currentPath.indexOf("day:") === 0)
            worker.command = ["/usr/bin/python3", "-I", script, "calendar", "--date", currentPath.slice(4)]
        else if(currentPath.indexOf("archive:")===0) {
            var mode=currentPath.slice(8)
            worker.command=["/usr/bin/python3","-I",script,"archive","--date",archives[mode].nextDate,"--direction",mode]
        }
        else {
            var race = findRace(currentPath)
            if (race && race.status === "finished") worker.command = worker.command.concat(["--finished"])
            else if (race && race.date > today) worker.command = worker.command.concat(["--upcoming"])
        }
        worker.running = true
    }
    function consume(code) {
        if (demo) return
        checkDate(Date.now())
        if (currentRequestDate !== today) { Qt.callLater(refresh); return }
        var result
        try { result = JSON.parse(output) } catch (e) { result = {state: "error", error: "Race data helper failed."} }
        if (code !== 0) result = {state: "error", error: "Race data helper could not run. Check Python 3 is installed."}
        var calendar = currentPath.indexOf("day:") === 0
        var archive = currentPath.indexOf("archive:") === 0
        var archiveMode=archive ? currentPath.slice(8) : ""
        var date = calendar ? currentPath.slice(4) : today
        var race = findRace(currentPath)
        var previousData = archive ? archives[archiveMode] || ({}) : calendar ? dayLists[date] || ({}) : currentPath ? details[currentPath] || ({}) : {fetchedAt:fetchedAt,metadataFetchedAt:metadataFetchedAt}
        if (!currentPath && (result.state === "ready" || result.state === "empty")) {
            result.races = (result.races || []).map(function(r) {
                var old=races.filter(function(p){return p.path===r.path})[0] || {}
                if(result.metadataError) {
                    ["competitionCategory","raceClass","category"].forEach(function(k){if(!r[k] && old[k])r[k]=old[k]})
                }
                return Object.assign({},r,{date:today})
            })
            result.retainedRaces = result.races.concat(allRaces().filter(function(r) {return r.date !== today}))
        }
        updateIssues = Model.updateIssues(updateIssues,currentPath,result,previousData,archive ? "Race calendar · "+archiveMode : calendar ? "Races · "+date : race ? race.name : "Selected race",Date.now())
        receiveEvents(currentPath,result,race)
        if(archive) {
            var archiveNext=Object.assign({},archives)
            archiveNext[archiveMode]=Model.mergeArchive(previousData,result,archiveMode,today)
            archives=archiveNext
            var requests=Object.assign({},archiveRequests)
            if(requests[archiveMode]) requests[archiveMode]=Object.assign({},requests[archiveMode],{remaining:requests[archiveMode].remaining-(result.dates || []).length})
            archiveRequests=requests
            if(result.state!=="ready" && result.state!=="empty") stopArchive(archiveMode)
        } else if (calendar) {
            var lists = Object.assign({},dayLists)
            lists[date] = result.state === "ready" || result.state === "empty" ? result
                : Object.assign({},previousData,{state:result.state,error:result.error})
            dayLists = lists
        } else if (currentPath) {
            var next = Object.assign({}, details)
            if (result.state === "ready") {
                var prior = next[currentPath] || ({})
                if (result.eventsError && prior.events) {
                    result.events = prior.events
                    result.eventsFetchedAt = prior.eventsFetchedAt || ""
                }
                if (result.profileError && prior.profile && prior.profile.length) {
                    result.profile = prior.profile
                    result.profileFetchedAt = prior.profileFetchedAt || prior.fetchedAt || ""
                }
                next[currentPath] = result
            }
            else {
                var previous = next[currentPath] || ({})
                next[currentPath] = Object.assign({}, previous, {state:result.state, error:result.error})
            }
            details = next
            var keep=Object.keys(details).filter(function(p){return watched.indexOf(p)>=0}).concat(Object.keys(details).slice(-12))
            var bounded={};keep.forEach(function(p){bounded[p]=next[p]});details=bounded
        } else {
            state = result.state
            error = result.error || ""
            if (state === "ready" || state === "empty") {
                races = result.races || []
                fetchedAt = result.fetchedAt || ""
                if(result.metadataFetchedAt) metadataFetchedAt=result.metadataFetchedAt
                var paths = allRaces().map(function(r) {return r.path})
                watched = watched.filter(function(p) {return paths.indexOf(p) >= 0})
                var retained = {}
                for (var i = 0; i < paths.length; i++) if (details[paths[i]]) retained[paths[i]] = details[paths[i]]
                details = retained
                var baselines = {}
                for (var j=0; j<watched.length; j++) if(eventBaselines[watched[j]]) baselines[watched[j]]=eventBaselines[watched[j]]
                eventBaselines = baselines
            }
        }
        var failures = [result.state,result.resultsState,result.eventsState,result.metadataState,result.profileState]
        var failureState = failures.indexOf("blocked") >= 0 ? "blocked" : failures.indexOf("rate-limited") >= 0 ? "rate-limited" : result.resultsState || result.state
        if (["blocked", "rate-limited"].indexOf(failureState) >= 0) {
            nextAllowed = Date.now() + 900000
            queue = []
        } else if (["offline", "error", "unsupported"].indexOf(result.state) >= 0 && !currentPath) {
            nextAllowed = Date.now() + 300000
            queue = []
        }
        Qt.callLater(runNext)
        if(archive && (result.state==="ready" || result.state==="empty")) Qt.callLater(function(){root.continueArchive(archiveMode)})
    }
    function receiveEvents(path,result,race) {
        if (!path || (race && !Model.matchesRace(race,raceFilters)) || !races.some(function(r){return r.path === path}) || demo || !eventNotifications || result.state !== "ready" || ["ready","empty"].indexOf(result.eventsState)<0) return
        var diff = Model.newEvents(eventBaselines[path],result.events || [],Date.now(),Math.max(300000,refreshIntervalSec*3000))
        var next = {}
        // Bound memory to the recently watched races.
        for(var i=0;i<watched.length;i++) if(eventBaselines[watched[i]]) next[watched[i]]=eventBaselines[watched[i]]
        next[path]=diff.baseline
        eventBaselines=next
        if(diff.fresh.length && race && (race.status==="live" || result.status==="live" || result.status==="finished"))
            Quickshell.execDetached(Model.notificationArgs(race.name,diff.fresh,notificationDurationSec))
    }
    // Explicit fictional failure preview; cannot mutate live fetch state.
    function demoWarning(kind) {
        if (!demo || ["ready","blocked","rate-limited","offline","error","unsupported"].indexOf(kind)<0) return false
        updateIssues = Model.updateIssues({},"",{state:kind,error:"Fictional connection failure."},{fetchedAt:new Date(Date.now()-180000).toISOString()},"",Date.now())
        nextAllowed = kind === "blocked" || kind === "rate-limited" ? Date.now()+900000 : 0
        return true
    }
    // Explicit fictional demo; never selected automatically on network failure.
    function setDemo(enabled) {
        if (worker.running) return false
        queue = []
        demo = enabled
        details = ({})
        races = []
        dayLists = ({})
        archives=({});archiveRequests=({})
        today = Model.dayKey(Date.now(),0)
        fetchedAt = ""
        metadataFetchedAt = ""
        error = ""
        watched = []
        lastRequests = ({})
        nextAllowed = 0
        updateIssues = ({})
        eventBaselines = ({})
        if (enabled) demoFile.reload()
        else { state = "loading"; refresh() }
        return true
    }
    FileView {
        id: demoFile
        path: Qt.resolvedUrl("demo/fixtures/example.json").toString().replace(/^file:\/\//, "")
        onLoaded: {
            if (!root.demo) return
            try {
                var fixture = JSON.parse(text())
                root.races = fixture.races
                root.details = fixture.details
                var lists = {}
                ;[-1,1].forEach(function(offset) {
                    var date = Model.dayKey(Date.now(),offset)
                    var entries = ((fixture.calendar || {})[offset<0 ? "yesterday" : "tomorrow"] || [])
                    lists[date] = {state:"ready",fetchedAt:new Date().toISOString(),races:entries.map(function(r) {return Object.assign({},r,{date:date})})}
                })
                root.dayLists = lists
                var archives={}
                ;["recent","upcoming"].forEach(function(mode) {
                    var entries=((fixture.archive || {})[mode] || []).map(function(r){return Object.assign({},r,{date:Model.dayKey(Date.now(),r.dayOffset)})})
                    archives[mode]={state:"ready",races:entries,dates:entries.map(function(r){return r.date}).sort(),fetchedAt:new Date().toISOString(),exhausted:true}
                })
                root.archives=archives
                root.state = "ready"
                root.fetchedAt = new Date().toISOString()
            } catch (e) { root.state = "error"; root.error = "Demo fixture could not be loaded." }
        }
    }
    Process {
        id: worker
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.output = text }
        onExited: function(code, status) { root.consume(code) }
    }
    Timer {
        // A short scheduler tick allows each source its own bounded interval.
        interval: 15000
        running: !root.demo
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refresh()
        }
    }
    IpcHandler {
        target: "io.github.vip32.procyclingstats"
        function refresh(): void { root.refresh() }
        function demo(enabled: bool): bool { return root.setDemo(enabled) }
        function demoWarning(kind: string): bool { return root.demoWarning(kind) }
        function open(): void { if (root.shell) root.shell.summon("io.github.vip32.procyclingstats", "{}") }
        function close(): void { if (root.shell) root.shell.hide("io.github.vip32.procyclingstats") }
        function status(): string {
            return JSON.stringify({state:root.state,error:root.error,loading:root.loading,demo:root.demo,
                                   today:root.today,days:root.dayLists,races:root.races.length,details:Object.keys(root.details),fetchedAt:root.fetchedAt,
                                   updateIssues:root.updateIssues,nextAllowed:root.nextAllowed,settings:root.options})
        }
    }
}

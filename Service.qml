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
    property var stageRaces: ({})
    property var pinnedRaces: []
    property var dayLists: ({})
    property var courses: ({})
    property var courseWanted: []
    property var courseRestoreQueue: []
    property var courseRestoreChecked: ({})
    property string courseRestorePath: ""
    property string courseRestoreDate: ""
    property string courseRestoreOutput: ""
    property int courseDiskHits: 0
    property var archives: ({})
    property var archiveRequests: ({})
    property string today: Model.dayKey(Date.now(),0)
    property string currentRequestDate: today
    property string fetchedAt: ""
    property bool loading: worker.running || courseReader.running
    property var queue: []
    property var watched: []
    property var lastRequests: ({})
    property string currentPath: ""
    property string output: ""
    property int refreshIntervalSec: 60
    property int overviewIntervalSec: 300
    property int resultsIntervalSec: 300
    property bool eventNotifications: false
    property bool revealMode: true
    property int notificationDurationSec: 8
    property var updateIssues: ({})
    property string metadataFetchedAt: ""
    property var raceFilters: ({})
    onRaceFiltersChanged: eventBaselines = ({})
    property var eventBaselines: ({})
    readonly property var options: Model.settings(Object.assign({},raceFilters,{refreshIntervalSec:refreshIntervalSec,
        overviewIntervalSec:overviewIntervalSec,resultsIntervalSec:resultsIntervalSec,
        revealMode:revealMode,eventNotifications:eventNotifications,notificationDurationSec:notificationDurationSec,pinnedRaces:pinnedRaces}))
    property double nextAllowed: 0
    property bool demo: false
    onEventNotificationsChanged: eventBaselines = ({})

    function allRaces() {
        var all = races.slice()
        Object.keys(dayLists).forEach(function(date) { all = all.concat(dayLists[date].races || []) })
        Object.keys(archives).forEach(function(mode) {all=all.concat(archives[mode].races || [])})
        return all
    }
    function findRace(path) { return allRaces().filter(function(r) {return r.path === path})[0] || stageRaces[path] }
    function checkDate(now) {
        var date = Model.dayKey(now,0)
        if (date === today || demo) return
        // Drop the old day's polling and snapshots; an in-flight response is
        // tagged with its start date and cannot populate the new today.
        today = date
        races = []; dayLists = ({}); details = ({}); stageRaces=({}); watched = []
        archives=({});archiveRequests=({});courses=({});courseWanted=[]
        courseRestoreQueue=[];courseRestoreChecked=({})
        queue = []; lastRequests = ({}); updateIssues = ({}); eventBaselines = ({})
        fetchedAt = ""; metadataFetchedAt = ""; state = "loading"; error = ""
    }
    function restoreCourses(paths) {
        if(demo)return
        var pending=courseRestoreQueue.slice()
        ;(paths || []).forEach(function(path) {
            if(!/^race\/[a-z0-9-]+\/\d{4}\/(result|gc|stage-\d+[a-z]?)$/.test(path) || courses[path] || courseRestoreChecked[path] || (courseReader.running && courseRestorePath===path) || pending.indexOf(path)>=0)return
            pending.push(path)
        })
        courseRestoreQueue=pending.slice(0,40)
        readNextCourse()
    }
    function readNextCourse() {
        if(demo || courseReader.running || !courseRestoreQueue.length)return
        courseRestorePath=courseRestoreQueue[0];courseRestoreQueue=courseRestoreQueue.slice(1)
        courseRestoreDate=today;courseRestoreOutput=""
        var script=decodeURIComponent(Qt.resolvedUrl("bin/pcs.py").toString().replace(/^file:\/\//,""))
        courseReader.command=["/usr/bin/python3","-I",script,"course-cache","--race",courseRestorePath]
        courseReader.running=true
    }
    function consumeCourseCache(code) {
        if(demo)return
        if(courseRestoreDate!==today) {Qt.callLater(readNextCourse);Qt.callLater(continueCourses);return}
        var checked=Object.assign({},courseRestoreChecked);delete checked[courseRestorePath];checked[courseRestorePath]=true
        var keys=Object.keys(checked);while(keys.length>100)delete checked[keys.shift()]
        courseRestoreChecked=checked
        var result={}
        try {if(code===0)result=JSON.parse(courseRestoreOutput)} catch(e) {}
        var prior=courses[courseRestorePath] || {}
        // A local read cannot replace a newer response or clear a connection warning.
        if(result && result.state==="ready" && result.cacheSavedAt && !prior.profileImage && !(prior.profile || []).length) {
            rememberCourse(courseRestorePath,result,true)
            var times=Object.assign({},lastRequests)
            times["course:"+courseRestorePath]=Math.max(Number(times["course:"+courseRestorePath] || 0),result.cacheSavedAt*1000)
            lastRequests=times;courseDiskHits++
        }
        Qt.callLater(readNextCourse)
        Qt.callLater(continueCourses)
    }
    function courseDue(path) {
        if(!courses[path])return true
        var failed=Model.isFailure(courses[path].state) || !!courses[path].profileError
        return Date.now()-Number(lastRequests["course:"+path] || 0)>=(failed ? 300000 : 3600000)
    }
    function watchCourses(paths) {
        var next=(paths || []).filter(function(p,i,all){return /^race\/[a-z0-9-]+\/\d{4}\/(result|gc|stage-\d+[a-z]?)$/.test(p) && all.indexOf(p)===i}).slice(0,40)
        if(JSON.stringify(next)!==JSON.stringify(courseWanted))courseWanted=next
        queue=queue.filter(function(p){return p.indexOf("course:")!==0 || next.indexOf(p.slice(7))>=0})
        courseRestoreQueue=courseRestoreQueue.filter(function(p){return next.indexOf(p)>=0 || watched.indexOf(p)>=0})
        continueCourses()
    }
    function continueCourses() {
        restoreCourses(courseWanted)
        if(demo || Date.now()<nextAllowed || (worker.running && currentPath.indexOf("course:")===0) || queue.some(function(p){return p.indexOf("course:")===0}))return
        var path=courseWanted.filter(function(p){return (courses[p] || courseRestoreChecked[p]) && courseDue(p)})[0]
        if(path)enqueue("course:"+path)
    }
    function rememberCourse(path,value,fromCache) {
        var next=Object.assign({},courses),prior=next[path] || {}
        delete next[path]
        if(Model.isFailure(value.state))next[path]=Object.assign({},prior,{state:value.state,error:value.error,profileError:value.error})
        else {
            var snapshot=Model.courseSnapshot(value)
            if(snapshot.distance===null || snapshot.distance===undefined)snapshot.distance=prior.distance
            if(value.profileError) {
                ;["profile","profileImage","profileImageWidth","profileImageHeight","profileFetchedAt"].forEach(function(k){if(prior[k])snapshot[k]=prior[k]})
            }
            next[path]=snapshot
        }
        var keys=Object.keys(next)
        while(keys.length>40) {
            var oldest=keys.filter(function(p){return courseWanted.indexOf(p)<0})[0] || keys[0]
            delete next[oldest];keys=Object.keys(next)
            var checked=Object.assign({},courseRestoreChecked);delete checked[oldest];courseRestoreChecked=checked
            var issues=Object.assign({},updateIssues);delete issues["course:"+oldest];updateIssues=issues
        }
        courses=next
        if(!fromCache && value.state==="ready" && !value.profileError && (value.profileState==="ready" || value.profileState==="unavailable" || (value.profile || []).length || value.profileImage)) {
            var recovered=Object.assign({},updateIssues);delete recovered["course:"+path];updateIssues=recovered
        }
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
        var finished = (race && (race.status === "finished" || race.date > today)) || (details[path] && details[path].status!=="live")
        if(path.indexOf("course:")===0 && !courseDue(path.slice(7)))return
        if (path.indexOf("archive:")!==0 && path.indexOf("course:")!==0 && Date.now() - Number(lastRequests[key] || 0) < Model.requestInterval(path, finished, options)) return
        queue = queue.concat([path]).slice(0, 5)
        runNext()
    }
    function watch(path) {
        if (!/^race\/[a-z0-9-]+\/\d{4}\/(result|gc|stage-\d+[a-z]?)$/.test(path)) return
        watched = [path].concat(watched.filter(function(p) { return p !== path })).slice(0, 3)
        restoreCourses([path])
        enqueue(path)
    }
    function watchStage(stage,parent) {
        if(!stage || !parent || Model.raceEdition(stage.path)!==Model.raceEdition(parent.path))return false
        var source=details[parent.path] || {}
        if(!(source.stages || []).some(function(s){return s.path===stage.path}))return false
        var next=Object.assign({},stageRaces)
        next[stage.path]={path:stage.path,name:Model.editionName(parent),status:"unknown",stageNavigation:true,stages:source.stages}
        var keys=Object.keys(next);while(keys.length>64)delete next[keys.shift()]
        stageRaces=next
        watch(stage.path)
        return true
    }
    function refresh() {
        checkDate(Date.now())
        enqueue("")
        Object.keys(dayLists).forEach(function(date) { enqueue("day:"+date) })
        for (var i = 0; i < watched.length; i++) enqueue(watched[i])
        continueCourses()
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
        else if(currentPath.indexOf("course:")===0)
            worker.command=["/usr/bin/python3","-I",script,"course","--race",currentPath.slice(7)]
        else if(currentPath.indexOf("archive:")===0) {
            var mode=currentPath.slice(8)
            worker.command=["/usr/bin/python3","-I",script,"archive","--date",archives[mode].nextDate,"--direction",mode]
        }
        else {
            var race = findRace(currentPath)
            if(stageRaces[currentPath]) worker.command=worker.command.concat(["--stage"])
            else if (race && race.status === "finished") worker.command = worker.command.concat(["--finished"])
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
        var course=currentPath.indexOf("course:")===0
        var coursePath=course ? currentPath.slice(7) : ""
        var calendar = currentPath.indexOf("day:") === 0
        var archive = currentPath.indexOf("archive:") === 0
        var archiveMode=archive ? currentPath.slice(8) : ""
        var date = calendar ? currentPath.slice(4) : today
        var race = findRace(course ? coursePath : currentPath)
        var previousData = course ? courses[coursePath] || ({}) : archive ? archives[archiveMode] || ({}) : calendar ? dayLists[date] || ({}) : currentPath ? details[currentPath] || ({}) : {fetchedAt:fetchedAt,metadataFetchedAt:metadataFetchedAt}
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
        var issueResult=course && result.profileError ? {state:result.profileState,error:result.profileError} : result
        var issuePrevious=course && result.profileError ? Object.assign({},previousData,{fetchedAt:previousData.profileFetchedAt || ""}) : previousData
        updateIssues = Model.updateIssues(updateIssues,currentPath,issueResult,issuePrevious,course ? "Course profile · "+(race ? race.name : "Selected race") : archive ? "Race calendar · "+archiveMode : calendar ? "Races · "+date : race ? race.name : "Selected race",Date.now())
        receiveEvents(currentPath,result,race)
        if(course) {
            rememberCourse(coursePath,result)
        } else if(archive) {
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
                if(!(result.stages || []).length && stageRaces[currentPath])result.stages=stageRaces[currentPath].stages || []
                result.groups=Model.gapTrends(prior,result,Date.now(),Math.max(180000,refreshIntervalSec*3000))
                next[currentPath] = result
                rememberCourse(currentPath,result)
                var times=Object.assign({},lastRequests);times["course:"+currentPath]=Date.now();lastRequests=times
                queue=queue.filter(function(p){return p!=="course:"+currentPath})
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
                var paths = allRaces().map(function(r) {return r.path}).concat(Object.keys(stageRaces))
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
        Qt.callLater(continueCourses)
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
        if(Model.resultsHidden(revealMode,race ? race.status : "",result.status || "",false))return
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
        if (loading) return false
        queue = []
        demo = enabled
        details = ({});stageRaces=({})
        races = []
        dayLists = ({})
        archives=({});archiveRequests=({});courses=({});courseWanted=[]
        courseRestoreQueue=[];courseRestoreChecked=({})
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
                var demoDetails=fixture.details
                Object.keys(demoDetails).forEach(function(path){
                    var d=demoDetails[path]
                    d.fetchedAt=new Date().toISOString()
                    if(d.status==="live")d.sourceAt=d.fetchedAt
                })
                root.details = demoDetails
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
    Process {
        // Local-only reads do not wait behind network requests or their cooldown.
        id: courseReader
        stdout: StdioCollector {waitForEnd:true;onStreamFinished:root.courseRestoreOutput=text}
        onExited: function(code,status) {root.consumeCourseCache(code)}
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
                                   updateIssues:root.updateIssues,nextAllowed:root.nextAllowed,courseDiskHits:root.courseDiskHits,settings:root.options})
        }
    }
}

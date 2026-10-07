import QtQuick
import QtTest
import Quickshell
import "../.." as Plugin
TestCase {
    name: "RaceService"
    property var service
    property string racePath: "race/fictional/2026/result"
    property var race: ({path:racePath,name:"Fictional race",status:"live"})
    Component {id:factory;Plugin.Service {}}
    Component {id:ownerFactory;QtObject {}}
    function init() {
        Quickshell.commands=[]
        service=createTemporaryObject(factory,this)
        wait(0)
        for(var i=0;i<service.data.length;i++) {
            if("command" in service.data[i]) service.data[i].running=false
        }
        service.queue=[]
        service.races=[race]
        service.watched=[racePath]
        service.currentPath=racePath
    }
    function deliver(result) {
        service.output=JSON.stringify(result)
        service.consume(0)
    }
    function snapshot(text) {
        return {state:"ready",status:"live",kmToGo:42,fetchedAt:new Date().toISOString(),eventsState:"ready",eventsFetchedAt:new Date().toISOString(),events:[{marker:"42",text:text}]}
    }
    function test_gap_trends_follow_successful_snapshot_history_only() {
        var groups=[{label:"Front",gap:"+0:00",riders:[{id:"rider/a"}]},{label:"Peloton",gap:"+1:20",riders:[]}]
        var first=snapshot("First");first.path=racePath;first.groups=groups;first.sourceAt=new Date(Date.now()-60000).toISOString()
        deliver(first)
        compare(service.details[racePath].groups[1].gapDelta,null)
        var next=snapshot("Next");next.path=racePath;next.groups=JSON.parse(JSON.stringify(groups));next.groups[1].gap="+1:10";next.sourceAt=new Date().toISOString()
        deliver(next)
        compare(service.details[racePath].groups[1].gapDelta,-10)
        deliver({state:"blocked",error:"Rejected"})
        next.sourceAt=new Date(Date.now()+1000).toISOString();deliver(next)
        compare(service.details[racePath].groups[1].gapDelta,null)
    }
    function test_stage_navigation_is_confined_and_uses_stage_resolver() {
        var parent={path:"race/tour/2026/stage-2",name:"Tour",status:"finished"}
        var stage={path:"race/tour/2026/stage-3",label:"Stage 3"}
        var details={};details[parent.path]={stages:[stage]};service.details=details
        verify(!service.watchStage({path:"race/other/2026/stage-3"},parent))
        verify(!service.watchStage({path:"race/tour/2026/stage-4"},parent))
        verify(service.watchStage(stage,parent))
        verify(worker().command.indexOf("--stage")>=0)
        verify(worker().command.indexOf("--finished")<0)
        var issues={};issues[stage.path]={path:stage.path,state:"offline",error:"Unavailable"};service.updateIssues=issues
        service.currentPath="";worker().running=false
        deliver({state:"ready",races:[race]})
        verify(service.watched.indexOf(stage.path)>=0)
        verify(service.updateIssues[stage.path]!==undefined)
    }
    function worker() {
        for(var i=0;i<service.data.length;i++) if("command" in service.data[i])return service.data[i]
    }
    function reader() {
        var found=false
        for(var i=0;i<service.data.length;i++)if("command" in service.data[i]) {
            if(found)return service.data[i]
            found=true
        }
    }
    function restore(result) {
        reader().running=false
        service.courseRestoreOutput=JSON.stringify(result)
        service.consumeCourseCache(0)
        wait(0)
    }
    function cached(age) {
        return {state:"ready",cacheSavedAt:(Date.now()-age)/1000,profile:[[0,80],[100,20]],distance:180,elevationGain:2450,profileState:"ready",fetchedAt:"saved"}
    }
    function test_invalid_cache_output_falls_back_to_normal_fetch_without_warning() {
        service.watchCourses([racePath])
        restore(null)
        compare(worker().command[3],"course")
        compare(Object.keys(service.updateIssues).length,0)
    }
    function test_disk_profile_restores_without_network_refresh_when_fresh() {
        service.watchCourses([racePath])
        verify(!worker().running)
        restore(cached(1000))
        compare(service.courses[racePath].distance,180)
        compare(service.courseDiskHits,1)
        verify(!worker().running)
        verify(!service.courseDue(racePath))
    }
    function test_old_cache_without_ascent_gets_one_refresh() {
        service.watchCourses([racePath])
        var old=cached(1000);delete old.elevationGain
        restore(old)
        compare(worker().command[3],"course")
        verify(worker().running)
        worker().running=false
        deliver({state:"ready",distance:180,elevationGain:null,profile:[[0,80],[100,20]],profileState:"ready"})
        wait(0)
        verify(!service.courseDue(racePath))
        verify(!worker().running)
    }
    function test_live_refresh_keeps_known_total_ascent() {
        service.rememberCourse(racePath,{state:"ready",elevationGain:2450,country:"VE"})
        service.rememberCourse(racePath,{state:"ready",elevation:620,country:""})
        compare(service.courses[racePath].elevationGain,2450)
        compare(service.courses[racePath].country,"VE")
    }
    function test_old_disk_profile_displays_while_normal_refresh_runs() {
        service.watchCourses([racePath])
        restore(cached(3601000))
        compare(service.courses[racePath].profile.length,2)
        compare(worker().command[3],"course")
        verify(worker().running)
    }
    function test_disk_restore_bypasses_network_cooldown_without_clearing_warning() {
        service.currentPath="course:"+racePath
        deliver({state:"blocked",error:"Rejected"})
        // First-time restore may already be running when the network rejects a request.
        service.courseRestorePath=racePath;service.courseRestoreDate=service.today
        restore(cached(3601000))
        compare(service.courses[racePath].distance,180)
        verify(service.updateIssues["course:"+racePath]!==undefined)
        verify(service.nextAllowed>Date.now())
        verify(!worker().running)
        service.watchCourses(["race/other/2026/result"])
        compare(reader().command[3],"course-cache")
    }
    function test_late_disk_result_cannot_replace_newer_network_profile() {
        service.watchCourses([racePath])
        service.rememberCourse(racePath,{state:"ready",distance:200,profile:[[0,10],[100,20]],profileState:"ready"})
        restore(cached(1000))
        compare(service.courses[racePath].distance,200)
        compare(service.courseDiskHits,0)
    }
    function test_cache_read_for_selected_race_does_not_delay_live_request() {
        service.watch(racePath)
        compare(reader().command[3],"course-cache")
        compare(worker().command[3],"race")
        verify(reader().running && worker().running)
        restore(cached(1000))
        compare(service.courses[racePath].distance,180)
        verify(worker().running)
    }
    function test_closing_list_cancels_remaining_disk_reads() {
        service.watched=[]
        service.watchCourses([racePath,"race/other/2026/result"])
        service.watchCourses([])
        restore(cached(1000))
        compare(service.courseRestoreQueue.length,0)
        verify(!reader().running && !worker().running)
    }
    function test_late_disk_result_is_discarded_after_day_change() {
        service.watchCourses([racePath])
        service.courseRestoreDate="2000-01-01"
        restore(cached(1000))
        compare(service.courseDiskHits,0)
        verify(!service.courses[racePath])
    }
    function test_archive_routes_serially_and_cancel_keeps_inflight_snapshot() {
        service.watchArchive("recent",25,false)
        compare(worker().command[3],"archive")
        compare(worker().command[5],service.today)
        service.watch(racePath)
        compare(worker().command[3],"archive")
        verify(service.queue.indexOf(racePath)>=0)
        service.stopArchive("recent")
        deliver({state:"ready",races:[],dates:[service.today],nextDate:"2026-01-01"})
        compare(service.archives.recent.dates.length,1)
        verify(!service.archiveRequests.recent)
    }
    function test_archive_stops_at_count_and_keeps_details_across_overview_refresh() {
        var records=[]
        for(var i=0;i<10;i++)records.push({path:"race/past-"+i+"/2026/gc",name:"Past "+i,date:"2026-01-01",status:"finished"})
        service.archives={recent:{races:records,dates:[]}}
        service.watchArchive("recent",10,false)
        verify(!service.loading)
        service.watch(records[0].path)
        verify(worker().command.indexOf("--finished")>=0)
        deliver({state:"ready",status:"finished",classifications:[]})
        service.currentPath=""
        deliver({state:"ready",races:[race]})
        verify(service.details[records[0].path]!==undefined)
        verify(service.watched.indexOf(records[0].path)>=0)
    }
    function test_archive_rejection_retains_data_and_sets_shared_cooldown() {
        service.archives={recent:{races:[race],dates:["2026-01-01"],fetchedAt:"saved",nextDate:"2025-12-31"}}
        service.watchArchive("recent",25,true)
        deliver({state:"blocked",error:"Rejected",races:[],dates:[],nextDate:"2025-12-31"})
        compare(service.archives.recent.races.length,1)
        compare(service.archives.recent.fetchedAt,"saved")
        verify(service.nextAllowed>Date.now()+890000)
        verify(!service.archiveRequests.recent)
        verify(service.updateIssues["archive:recent"]!==undefined)
    }
    function test_archive_search_budget_and_no_background_restart() {
        service.archives={recent:{races:[],dates:[],nextDate:service.today}}
        service.archiveRequests={recent:{count:25,remaining:3}}
        service.currentPath="archive:recent"
        deliver({state:"empty",races:[],dates:["2026-01-03","2026-01-02","2026-01-01"],nextDate:"2025-12-31"})
        wait(0)
        compare(service.archiveRequests.recent.remaining,0)
        verify(service.queue.indexOf("archive:recent")<0)
        service.refresh()
        verify(service.queue.indexOf("archive:recent")<0)
    }
    function test_courses_only_queue_visible_paths_and_stop_on_close() {
        service.watchCourses([racePath,"race/second/2026/result"])
        compare(reader().command[3],"course-cache")
        compare(reader().command[5],racePath)
        restore({state:"empty"})
        compare(worker().command[3],"course")
        compare(worker().command[5],racePath)
        service.watchCourses([])
        worker().running=false
        deliver({state:"ready",distance:180,profileState:"unavailable",profile:[]})
        wait(0)
        compare(service.courses[racePath].distance,180)
        compare(service.courseWanted.length,0)
        compare(service.queue.length,0)
    }
    function test_partial_live_snapshot_keeps_known_course_distance() {
        service.rememberCourse(racePath,{state:"ready",distance:180,profileState:"ready"})
        service.rememberCourse(racePath,{state:"ready",distance:null,profile:[[0,10],[100,90]]})
        compare(service.courses[racePath].distance,180)
    }
    function test_memory_eviction_allows_profile_to_restore_from_disk_again() {
        var checked={};checked[racePath]=true;service.courseRestoreChecked=checked
        service.rememberCourse(racePath,cached(1000))
        for(var i=0;i<40;i++)service.rememberCourse("race/new-"+i+"/2026/result",cached(1000))
        verify(!service.courses[racePath])
        service.watchCourses([racePath])
        compare(reader().command[3],"course-cache")
        compare(reader().command[5],racePath)
    }
    function test_course_cache_is_reused_and_bounded() {
        for(var i=0;i<45;i++)service.rememberCourse("race/demo-"+i+"/2026/result",{state:"ready",distance:i,profileState:"unavailable"})
        compare(Object.keys(service.courses).length,40)
        service.rememberCourse(racePath,{state:"ready",distance:180,elevationGain:2450,profileState:"ready",profileImage:"image"})
        var times={};times["course:"+racePath]=Date.now();service.lastRequests=times
        service.watchCourses([racePath])
        verify(!service.loading)
    }
    function test_course_failure_keeps_image_and_distance_with_cooldown() {
        service.rememberCourse(racePath,{state:"ready",distance:180,profileState:"ready",profileImage:"image",profileFetchedAt:"saved"})
        service.currentPath="course:"+racePath
        deliver({state:"ready",distance:181,profileState:"blocked",profileError:"Rejected"})
        compare(service.courses[racePath].profileImage,"image")
        compare(service.courses[racePath].distance,181)
        compare(service.updateIssues["course:"+racePath].lastSuccess,"saved")
        verify(service.nextAllowed>Date.now()+890000)
    }
    function test_details_satisfy_pending_course_request_and_clear_old_warning() {
        service.currentPath="course:"+racePath
        deliver({state:"error",error:"Unavailable"})
        verify(service.updateIssues["course:"+racePath]!==undefined)
        service.currentPath=racePath
        deliver({state:"ready",distance:180,elevationGain:2450,profileState:"ready",profileImage:"image"})
        compare(service.courses[racePath].profileImage,"image")
        verify(service.updateIssues["course:"+racePath]===undefined)
        verify(!service.courseDue(racePath))
    }
    function test_course_caches_and_interest_clear_at_midnight() {
        service.courses={test:{distance:100}}
        service.courseWanted=[racePath]
        service.today="2000-01-01"
        service.checkDate(Date.now())
        compare(Object.keys(service.courses).length,0)
        compare(service.courseWanted.length,0)
    }
    function test_failure_and_recovery() {
        deliver(snapshot("First event"))
        var stamp=service.details[racePath].fetchedAt
        deliver({state:"blocked",error:"Rejected"})
        compare(service.details[racePath].kmToGo,42)
        compare(service.details[racePath].fetchedAt,stamp)
        compare(Object.keys(service.updateIssues).length,1)
        verify(service.nextAllowed>Date.now()+890000)
        service.currentPath=""
        deliver({state:"ready",races:[race]})
        compare(Object.keys(service.updateIssues).length,1)
        service.currentPath=racePath
        deliver(snapshot("Recovered"))
        compare(Object.keys(service.updateIssues).length,0)
    }
    function test_partial_event_failure_keeps_events_and_timestamp() {
        deliver(snapshot("First event"))
        var stamp=service.details[racePath].eventsFetchedAt
        deliver({state:"ready",kmToGo:40,eventsState:"rate-limited",eventsError:"Rate limited"})
        compare(service.details[racePath].kmToGo,40)
        compare(service.details[racePath].events[0].text,"First event")
        compare(service.details[racePath].eventsFetchedAt,stamp)
        compare(Object.keys(service.updateIssues).length,1)
        verify(service.nextAllowed>Date.now()+890000)
    }
    function test_notification_toggle_baseline_and_dedup() {
        deliver(snapshot("Old event"))
        compare(Quickshell.commands.length,0)
        service.eventNotifications=true
        deliver(snapshot("Old event"))
        compare(Quickshell.commands.length,0)
        deliver(snapshot("New event"))
        compare(Quickshell.commands.length,1)
        deliver(snapshot("New event"))
        compare(Quickshell.commands.length,1)
        service.eventNotifications=false
        deliver(snapshot("While disabled"))
        compare(Quickshell.commands.length,1)
        service.eventNotifications=true
        deliver(snapshot("While disabled"))
        compare(Quickshell.commands.length,1)
    }
    function test_profile_failure_preserves_shape_and_triggers_cooldown() {
        deliver({state:"ready",profile:[[0,70],[50,10],[100,70]],profileState:"ready",profileFetchedAt:"saved"})
        deliver({state:"ready",distance:160,profile:[],profileState:"blocked",profileError:"Rejected"})
        compare(service.details[racePath].distance,160)
        compare(service.details[racePath].profile.length,3)
        compare(service.details[racePath].profileFetchedAt,"saved")
        compare(Object.keys(service.updateIssues).length,1)
        verify(service.nextAllowed>Date.now()+890000)
    }
    function test_finished_events_do_not_spoil_notifications_when_protected() {
        service.eventNotifications=true
        deliver(snapshot("Race continues"))
        var finish=snapshot("Winner crossed the line");finish.status="finished"
        deliver(finish)
        compare(Quickshell.commands.length,0)
        service.revealMode=false
        finish.events=[{marker:"F",text:"Final result update"}]
        deliver(finish)
        compare(Quickshell.commands.length,1)
    }
    function test_finished_list_status_also_suppresses_event_notifications() {
        service.eventNotifications=true
        service.races=[Object.assign({},race,{status:"finished"})]
        deliver(snapshot("First"));deliver(snapshot("Winner"))
        compare(Quickshell.commands.length,0)
    }
    function test_failed_event_fetch_never_notifies() {
        service.eventNotifications=true
        deliver(snapshot("Old event"))
        deliver({state:"ready",eventsState:"offline",eventsError:"Offline",events:[{text:"Stale event"}]})
        compare(Quickshell.commands.length,0)
    }
    function test_demo_never_sends_notifications() {
        service.eventNotifications=true
        service.demo=true
        service.receiveEvents(racePath,snapshot("Demo event"),race)
        compare(Quickshell.commands.length,0)
        verify(service.demoWarning("blocked"))
        compare(Object.keys(service.updateIssues).length,1)
        verify(service.demoWarning("ready"))
        compare(Object.keys(service.updateIssues).length,0)
    }
    function test_independent_intervals() {
        service.refreshIntervalSec=120
        service.overviewIntervalSec=600
        service.resultsIntervalSec=900
        var recent={overview:Date.now()-400000}
        recent[racePath]=Date.now()-90000
        service.lastRequests=recent
        service.enqueue("")
        service.enqueue(racePath)
        compare(service.queue.length,0)
        verify(!service.loading)
        recent[racePath]=Date.now()-130000
        service.lastRequests=Object.assign({},recent)
        service.enqueue(racePath)
        verify(service.loading)
    }
    function test_calendar_response_cannot_replace_today() {
        var yesterday = new Date(Date.now()-86400000)
        var date = yesterday.getFullYear()+"-"+String(yesterday.getMonth()+1).padStart(2,"0")+"-"+String(yesterday.getDate()).padStart(2,"0")
        service.currentPath="day:"+date
        var past={path:"race/past/2026/stage-2",name:"Past",date:date,status:"finished"}
        deliver({state:"ready",races:[past],fetchedAt:"saved"})
        compare(service.races[0].path,racePath)
        compare(service.dayLists[date].races[0].path,past.path)
        service.watch(past.path)
        var command=worker().command
        verify(command.indexOf("--finished")>=0)
    }
    function test_calendar_failure_keeps_snapshot_and_recovers_independently() {
        service.currentPath="day:"+service.today
        deliver({state:"ready",races:[race],fetchedAt:"saved"})
        deliver({state:"blocked",error:"Rejected"})
        compare(service.dayLists[service.today].races.length,1)
        compare(service.dayLists[service.today].fetchedAt,"saved")
        service.currentPath=""
        deliver({state:"ready",races:[race]})
        compare(Object.keys(service.updateIssues).length,1)
        service.currentPath="day:"+service.today
        deliver({state:"empty",races:[]})
        compare(Object.keys(service.updateIssues).length,0)
    }
    function test_historical_events_never_notify() {
        service.races=[]
        service.eventNotifications=true
        deliver(snapshot("Old"))
        deliver(snapshot("New historical event"))
        compare(Quickshell.commands.length,0)
    }
    function test_midnight_retires_old_day_and_discards_inflight_response() {
        service.today="2000-01-01"
        service.currentRequestDate="2000-01-01"
        service.currentPath=""
        deliver({state:"ready",races:[race]})
        verify(service.today!=="2000-01-01")
        compare(service.races.length,0)
        compare(service.watched.length,0)
    }
    function test_today_upcoming_and_scheduled_use_preview_then_switch_to_live() {
        for(var i=0;i<2;i++) {
            service.races=[Object.assign({},race,{date:service.today,status:i===0 ? "upcoming" : "scheduled"})]
            service.lastRequests={};worker().running=false;service.queue=[]
            service.watch(racePath)
            verify(worker().command.indexOf("--upcoming")>=0)
        }
        service.races=[Object.assign({},race,{date:service.today,status:"live"})]
        service.lastRequests={};worker().running=false;service.queue=[]
        service.watch(racePath)
        verify(worker().command.indexOf("--upcoming")<0)
        verify(worker().command.indexOf("--finished")<0)
    }
    function test_preview_success_clears_old_livestats_warning() {
        deliver({state:"unsupported",error:"LiveStats unavailable"})
        verify(service.updateIssues[racePath]!==undefined)
        deliver({path:racePath,state:"ready",status:"upcoming",date:service.today,distance:22.1})
        verify(service.updateIssues[racePath]===undefined)
        compare(service.details[racePath].status,"upcoming")
    }
    function test_tomorrow_routes_to_preview_without_events() {
        var future={path:"race/future/2026/stage-2",name:"Future",date:"9999-01-01",status:"scheduled"}
        service.dayLists={future:{races:[future]}}
        service.watch(future.path)
        var command=worker().command
        verify(command.indexOf("--upcoming")>=0)
    }
    function test_metadata_failure_retains_known_filters_and_sets_cooldown() {
        service.currentPath=""
        deliver({state:"ready",metadataState:"ready",metadataFetchedAt:"saved",races:[Object.assign({},race,{competitionCategory:"ME",raceClass:"2.Pro"})]})
        deliver({state:"ready",metadataState:"blocked",metadataError:"Rejected",races:[race]})
        compare(service.races[0].raceClass,"2.Pro")
        compare(service.races[0].competitionCategory,"ME")
        compare(service.updateIssues["overview/metadata"].lastSuccess,"saved")
        verify(service.nextAllowed>Date.now()+890000)
        deliver({state:"ready",metadataState:"ready",races:[race]})
        compare(Object.keys(service.updateIssues).length,0)
    }
    function test_filtered_race_events_do_not_notify() {
        service.eventNotifications=true
        service.raceFilters={categoryME:false}
        var hidden=Object.assign({},race,{competitionCategory:"ME"})
        service.races=[hidden]
        deliver(snapshot("Old"));deliver(snapshot("New"))
        compare(Quickshell.commands.length,0)
        service.raceFilters={categoryME:true}
        deliver(snapshot("New"))
        compare(Quickshell.commands.length,0)
        deliver(snapshot("Newest"))
        compare(Quickshell.commands.length,1)
    }
    function test_detached_window_has_one_owner() {
        var first=createTemporaryObject(ownerFactory,this)
        var second=createTemporaryObject(ownerFactory,this)
        verify(service.claimWindow(first))
        verify(service.claimWindow(first))
        verify(!service.claimWindow(second))
        compare(service.windowOwner,first)
    }
    function test_only_the_window_owner_can_release_it() {
        var first=createTemporaryObject(ownerFactory,this)
        var second=createTemporaryObject(ownerFactory,this)
        service.claimWindow(first)
        service.releaseWindow(second)
        compare(service.windowOwner,first)
        service.releaseWindow(first)
        compare(service.windowOwner,null)
        verify(service.claimWindow(second))
    }
    function test_destroyed_window_owner_does_not_block_reopening() {
        var first=createTemporaryObject(ownerFactory,this)
        service.claimWindow(first)
        first.destroy()
        wait(0)
        compare(service.windowOwner,null)
        verify(service.claimWindow(createTemporaryObject(ownerFactory,this)))
    }
}

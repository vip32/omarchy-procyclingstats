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
}

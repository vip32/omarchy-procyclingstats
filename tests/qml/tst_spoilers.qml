import QtQuick
import QtTest
import "../.." as Plugin
TestCase {
    name:"SpoilerSummary"
    when:windowShown
    visible:true
    width:640;height:350
    Plugin.RaceSummary {
        id:summary;width:600
        detail:({state:"ready",distance:180,elapsed:"3:12:08",avgSpeed:56.2,profileLabel:"Stage 2",profile:[[0,80],[50,10],[100,80]]})
    }
    Plugin.Classification {id:classification;width:600;concealed:true}
    Plugin.RaceEvents {id:events;width:600;concealed:true}
    function visibleTexts(item) {
        if(!item.visible)return []
        var result=[]
        if("text" in item)result.push(item.text)
        for(var i=0;i<item.children.length;i++)result=result.concat(visibleTexts(item.children[i]))
        return result
    }
    function test_empty_tables_and_events_remain_readable() {
        classification.classification={rows:[]}
        events.events=[];events.state="empty";events.error=""
        wait(0)
        verify(!classification.rowsHidden)
        verify(!events.rowsHidden)
        verify(visibleTexts(classification).indexOf("Results not published yet")>=0)
        verify(visibleTexts(events).indexOf("No race events published yet.")>=0)
        events.state="loading"
        verify(visibleTexts(events).indexOf("Loading race events…")>=0)
        events.state="unavailable";events.error="Events unavailable."
        verify(visibleTexts(events).indexOf("Events unavailable.")>=0)
    }
    function test_arriving_data_is_concealed_and_empty_updates_remove_veil() {
        classification.concealed=true;events.concealed=true
        classification.classification={rows:[{rank:"1",name:"Fictional Winner",time:"3:12:08"}]}
        events.events=[{marker:"F",text:"Fictional Winner wins."}]
        wait(0)
        verify(classification.rowsHidden)
        verify(events.rowsHidden)
        verify(texts(classification).indexOf("Fictional Winner")<0)
        verify(texts(events).indexOf("Fictional Winner wins.")<0)
        classification.concealed=false;events.concealed=false
        wait(0)
        verify(visibleTexts(classification).indexOf("Fictional Winner")>=0)
        verify(visibleTexts(events).indexOf("Fictional Winner wins.")>=0)
        classification.concealed=true;events.concealed=true
        classification.classification={rows:[]};events.events=[]
        verify(!classification.rowsHidden)
        verify(!events.rowsHidden)
    }
    function test_missing_metrics_remain_dashes() {
        var previous=summary.detail
        summary.detail={distance:180};summary.concealed=true
        wait(0)
        var values=texts(summary)
        verify(values.indexOf("Hidden")<0)
        compare(values.filter(function(v){return v==="—"}).length,2)
        summary.detail=previous
    }
    function texts(item) {
        var result=[]
        if("text" in item)result.push(item.text)
        for(var i=0;i<item.children.length;i++)result=result.concat(texts(item.children[i]))
        return result
    }
    function test_concealed_summary_keeps_course_but_has_no_winner_metrics() {
        summary.concealed=true
        wait(0)
        var values=texts(summary)
        verify(values.indexOf("180 km")>=0)
        verify(values.indexOf("Stage 2 · elevation profile")>=0)
        verify(values.indexOf("Hidden")>=0)
        verify(values.indexOf("3:12:08")<0)
        verify(values.indexOf("56.2")<0)
    }
    function test_reveal_restores_winner_metrics() {
        summary.concealed=false
        wait(0)
        var values=texts(summary)
        verify(values.indexOf("3:12:08")>=0)
        verify(values.indexOf("56.2")>=0)
    }
}

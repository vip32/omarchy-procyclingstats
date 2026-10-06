import QtQuick
import QtTest
import "../.." as Plugin
TestCase {
    name:"SpoilerSummary"
    when:windowShown
    width:640;height:350
    Plugin.RaceSummary {
        id:summary;width:600
        detail:({state:"ready",distance:180,elapsed:"3:12:08",avgSpeed:56.2,profileLabel:"Stage 2",profile:[[0,80],[50,10],[100,80]]})
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

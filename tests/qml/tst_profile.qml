import QtQuick
import QtTest
import "../.." as Plugin

TestCase {
    id:testCase
    name:"InlineProfile"
    when:windowShown
    width:640;height:300
    property string fixture:""
    Canvas {
        id:source
        width:120;height:60
        onPaint: {
            var c=getContext("2d")
            c.fillStyle="white";c.fillRect(0,0,width,height)
            c.fillStyle="#8ebe2d"
            c.beginPath();c.moveTo(4,48);c.lineTo(35,30);c.lineTo(60,40);c.lineTo(85,12);c.lineTo(116,45);c.lineTo(116,55);c.lineTo(4,55);c.closePath();c.fill()
            testCase.fixture=toDataURL()
        }
    }
    Plugin.Profile {id:chart;x:130;width:420;height:80;imageSource:testCase.fixture}
    function test_trace_published_image_into_inline_curve() {
        tryVerify(function(){return fixture.length>0},3000)
        tryVerify(function(){return chart.hasCurve},5000)
        verify(chart.tracedPoints.length>100)
        compare(chart.tracedPoints[0][0],0)
        compare(chart.tracedPoints[chart.tracedPoints.length-1][0],100)
    }
    function test_native_coordinates_take_precedence() {
        chart.points=[[0,50],[50,10],[100,50]]
        compare(chart.drawingPoints.length,3)
        compare(chart.drawingPoints[1][1],10)
        chart.points=[]
    }
}

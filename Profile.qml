import QtQuick
import qs.Commons

Canvas {
    id: root
    property var points: []
    property string imageSource: ""
    Image {
        anchors.fill:parent
        visible:root.points.length<2
        source:visible && /^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(root.imageSource) && root.imageSource.length<350000 ? root.imageSource : ""
        fillMode:Image.PreserveAspectFit
        sourceSize.width:1200
        sourceSize.height:600
        asynchronous:true
        smooth:true
    }
    property real progress: -1
    property color lineColor: Color.accent
    property color foreground: Color.foreground
    antialiasing: true
    onPointsChanged: requestPaint()
    onProgressChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c=getContext("2d")
        c.reset()
        if (points.length < 2) return
        var h=height-6, w=width-2
        c.beginPath(); c.moveTo(1,h)
        for (var i=0;i<points.length;i++) c.lineTo(1+points[i][0]/100*w,3+points[i][1]/100*(h-3))
        c.lineTo(w,h); c.closePath()
        c.fillStyle=Qt.alpha(lineColor,0.15); c.fill()
        c.beginPath()
        for (var j=0;j<points.length;j++) {
            var x=1+points[j][0]/100*w, y=3+points[j][1]/100*(h-3)
            if(j===0)c.moveTo(x,y);else c.lineTo(x,y)
        }
        c.strokeStyle=lineColor; c.lineWidth=1.5; c.stroke()
        if(progress>=0) {
            var px=1+Math.min(1,Math.max(0,progress))*w
            c.beginPath(); c.moveTo(px,0); c.lineTo(px,height)
            c.strokeStyle=foreground; c.lineWidth=1; c.stroke()
            c.beginPath(); c.arc(px,3,2.7,0,Math.PI*2); c.fillStyle=foreground; c.fill()
        }
    }
}

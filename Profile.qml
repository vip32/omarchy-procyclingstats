import QtQuick
import qs.Commons
import "ProfileTrace.js" as Trace

Canvas {
    id: root
    property var points: []
    property string imageSource: ""
    property var tracedPoints: []
    readonly property var drawingPoints:points.length>1 ? points : tracedPoints
    readonly property bool hasCurve:drawingPoints.length>1
    readonly property bool validImage:/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(imageSource) && imageSource.length<350000
    function resolveOutline() {
        tracedPoints=[]
        if(raster.pendingSource) {raster.unloadImage(raster.pendingSource);raster.pendingSource=""}
        if(points.length>1 || !validImage)return
        var known=Trace.cached(imageSource)
        if(known!==null) {tracedPoints=known;return}
        raster.pendingSource=imageSource
        raster.loadImage(imageSource)
        if(raster.isImageLoaded(imageSource))raster.trace()
    }
    onImageSourceChanged: Qt.callLater(resolveOutline)
    onTracedPointsChanged: requestPaint()
    Canvas {
        id:raster
        // Canvas pixel reads use physical pixels, including fractional display scaling.
        readonly property real pixelRatio:(root.Window.window && root.Window.window.devicePixelRatio) || Screen.devicePixelRatio || 1
        width:480/pixelRatio;height:240/pixelRatio;visible:false
        contextType:"2d"
        property string pendingSource:""
        function trace() {
            if(!available || !root.validImage || !isImageLoaded(root.imageSource))return
            var source=root.imageSource
            var c=getContext("2d")
            c.reset();c.drawImage(source,0,0,width,height)
            root.tracedPoints=Trace.remember(source,Trace.outline(c.getImageData(0,0,480,240).data,480,240))
            c.reset();unloadImage(source);pendingSource=""
        }
        onImageLoaded:trace()
        onAvailableChanged:if(available)Qt.callLater(root.resolveOutline)
    }
    Image {
        anchors.fill:parent
        visible:!root.hasCurve
        source:visible && root.validImage ? root.imageSource : ""
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
    onPointsChanged: {requestPaint();Qt.callLater(resolveOutline)}
    onProgressChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c=getContext("2d")
        c.reset()
        var points=root.drawingPoints
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

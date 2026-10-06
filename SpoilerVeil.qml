import QtQuick
import qs.Commons

// Draw a blurred stand-in, never real names or times. Hidden results cannot be
// read through accessibility, text selection or the shape of a rider's name.
Item {
    id:root
    property color foreground:Color.foreground
    implicitHeight:Style.space(152)
    Accessible.role:Accessible.StaticText
    Accessible.name:"Results hidden. Use Reveal results to show them."
    Canvas {
        id:veil
        anchors.fill:parent
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        Connections {target:root;function onForegroundChanged(){veil.requestPaint()}}
        onPaint: {
            var c=getContext("2d");c.reset()
            for(var row=0;row<4;row++) {
                var y=Style.space(16+row*34)
                // A soft blur of anonymous rows; no extra effects dependency.
                for(var spread=7;spread>=0;spread--) {
                    c.fillStyle=Qt.alpha(root.foreground,spread===0 ? 0.13 : 0.015)
                    c.fillRect(Style.space(18-spread),y-Style.space(spread/2),width*0.45+Style.space(spread*2),Style.space(7+spread))
                    c.fillRect(width*0.79-Style.space(spread),y-Style.space(spread/2),width*0.15+Style.space(spread*2),Style.space(7+spread))
                }
            }
        }
    }
}

import QtQuick

Canvas {
    id: root
    property color color: "white"
    antialiasing: true
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d")
        c.reset()
        c.scale(width / 32, height / 32)
        c.strokeStyle = color
        c.lineWidth = 1.65
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        c.arc(7, 22, 5.8, 0, Math.PI * 2)
        c.moveTo(30.8, 22)
        c.arc(25, 22, 5.8, 0, Math.PI * 2)
        c.stroke()
        c.beginPath()
        c.moveTo(7,22); c.lineTo(12,12); c.lineTo(17,22); c.lineTo(7,22)
        c.moveTo(12,12); c.lineTo(21,12); c.lineTo(17,22)
        c.moveTo(25,22); c.lineTo(20.5,9); c.lineTo(25,9)
        c.bezierCurveTo(28,9,28,13,24,13)
        c.moveTo(12,12); c.lineTo(11,9)
        c.moveTo(8.5,9); c.lineTo(13.5,9)
        c.moveTo(17,22); c.lineTo(19,24); c.lineTo(21,24)
        c.stroke()
    }
}

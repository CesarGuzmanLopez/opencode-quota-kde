import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Raíz ColumnLayout: en modo barra muestra una fila (etiquetas + barra),
// en modo círculo muestra una columna centrada (círculo + reset debajo).
ColumnLayout {
    id: metric

    // Configurable desde main.qml
    property string lbl: ""
    property real pct: 0
    property string rst: ""
    property bool circle: false
    property int diameter: 48
    property bool showPercent: true
    // Contraste en modo sin fondo (lo pasa main.qml)
    property bool flat: false
    // Más grande en modo barra cuando el widget es ancho (lo pasa main.qml)
    property bool big: false
    // Colores configurables (los pasa main.qml desde la configuración)
    property color colorValue: "#E93DAE"
    property color colorTrack: "#3DAEE9"
    readonly property color fgMain: flat ? "white" : Kirigami.Theme.textColor
    readonly property color fgSub: flat ? "#f5f5f5" : Kirigami.Theme.disabledTextColor

    spacing: Kirigami.Units.smallSpacing / 2

    // ---------- Modo barra: fila con etiquetas a la izq. y barra a la der. ----------
    RowLayout {
        visible: !metric.circle
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents3.Label {
                text: metric.lbl + ": " + Math.round(metric.pct) + "%"
                font.pixelSize: metric.big ? Kirigami.Theme.defaultFont.pixelSize + 3 : Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                color: metric.fgMain
                style: metric.flat ? Text.Outline : Text.Normal
                styleColor: "#d0000000"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: metric.rst !== ""
                text: metric.rst
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
                color: metric.fgSub
                style: metric.flat ? Text.Outline : Text.Normal
                styleColor: "#d0000000"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 100
            Layout.maximumWidth: 140
            height: metric.big ? 14 : 10
            radius: height / 2
            clip: true
            color: Qt.rgba(metric.colorTrack.r, metric.colorTrack.g, metric.colorTrack.b, 0.3)
            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, metric.pct / 100))
                height: parent.height
                radius: height / 2
                color: metric.colorTrack
            }
        }
    }

    // ---------- Modo círculo: columna centrada ----------
    ColumnLayout {
        visible: metric.circle
        spacing: Kirigami.Units.smallSpacing / 2
        Layout.alignment: Qt.AlignHCenter

        Item {
            width: metric.diameter
            height: metric.diameter
            Layout.preferredWidth: metric.diameter
            Layout.preferredHeight: metric.diameter
            Layout.alignment: Qt.AlignHCenter

            Canvas {
                id: cv
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    if (!ctx) return
                    ctx.reset()
                    var cx = width / 2
                    var cy = height / 2
                    var lw = Math.max(2, Math.round(metric.diameter / 16))
                    var r = Math.max(1, Math.min(width, height) / 2 - lw / 2 - 1)

                    // pista de fondo
                    ctx.lineWidth = lw
                    ctx.strokeStyle = Qt.rgba(metric.colorTrack.r, metric.colorTrack.g, metric.colorTrack.b, 0.35)
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.stroke()

                    // arco de valor
                    var frac = Math.min(1, Math.max(0, metric.pct / 100))
                    if (frac > 0) {
                        ctx.strokeStyle = metric.colorValue
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + Math.PI * 2 * frac)
                        ctx.stroke()
                    }
                }
                Component.onCompleted: cv.requestPaint()
            }

            // Dentro: etiqueta + %
            Column {
                anchors.centerIn: parent
                spacing: -1
                PlasmaComponents3.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: metric.lbl
                    font.pixelSize: Math.max(7, Math.round(metric.diameter / 6.5))
                    font.bold: true
                    color: metric.fgSub
                    style: metric.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                }
                PlasmaComponents3.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: metric.showPercent
                    text: Math.round(metric.pct) + "%"
                    font.pixelSize: Math.max(9, Math.round(metric.diameter / 4))
                    font.bold: true
                    color: metric.fgMain
                    style: metric.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                }
            }

            Connections {
                target: metric
                function onPctChanged() { cv.requestPaint() }
                function onDiameterChanged() { cv.requestPaint() }
                function onCircleChanged() { if (metric.circle) cv.requestPaint() }
            }
        }

        // Reset debajo del círculo
        PlasmaComponents3.Label {
            visible: metric.rst !== ""
            text: metric.rst
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
            color: metric.fgSub
            style: metric.flat ? Text.Outline : Text.Normal
            styleColor: "#d0000000"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}

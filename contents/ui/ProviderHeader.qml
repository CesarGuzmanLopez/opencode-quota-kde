import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// Cabecera de proveedor: insignia con glifo y color de marca + título + sufijo.
// Todo en una línea: no alarga el widget.
RowLayout {
    id: header

    property string badge: ""
    property color accent: Kirigami.Theme.highlightColor
    property string title: ""
    property string suffix: ""
    // Modo sin fondo: texto claro con contorno (lo decide main.qml)
    property bool flat: false
    property color textColor: flat ? "white" : Kirigami.Theme.textColor

    spacing: Kirigami.Units.smallSpacing
    Layout.alignment: Qt.AlignHCenter

    // Insignia: cuadro redondeado del color de marca con el glifo encima
    Rectangle {
        id: badgeBox

        readonly property real side: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.35)

        width: side
        height: side
        radius: Math.round(side * 0.28)
        color: header.accent
        Layout.alignment: Qt.AlignVCenter

        PlasmaComponents3.Label {
            anchors.centerIn: parent
            text: header.badge
            font.pixelSize: Math.round(badgeBox.side * 0.58)
            font.bold: true
            // Texto oscuro sobre la marca clara, blanco sobre la oscura
            color: badgeBox.color.lightness < 0.55 ? "white" : "#1b1b1b"
        }

    }

    PlasmaComponents3.Label {
        text: header.title + header.suffix
        font.bold: true
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
        color: header.textColor
        style: header.flat ? Text.Outline : Text.Normal
        styleColor: "#d0000000"
        elide: Text.ElideMiddle
        Layout.fillWidth: true
    }

}

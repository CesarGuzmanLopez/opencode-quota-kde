import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // === Datos del backend (null = sin credenciales = no mostrar) ===
    property var quotaData: null
    property string lastError: ""

    // === Preferencias ===
    readonly property bool circleMode: plasmoid.configuration.displayMode === 1
    // Diámetro base (diálogo) + diámetros efectivos que crecen al redimensionar
    readonly property int cfgDia: plasmoid.configuration.circleDiameter || 48
    // Ancho: 1 col (apilado) · 2 col (OC arriba + Qwen|DS) · 3 col (todo lateral)
    // layoutMode: 0 automática · 1 tres en fila · 2 OpenCode a la izquierda
    readonly property int layoutMode: plasmoid.configuration.layoutMode || 0
    readonly property bool lateral: layoutMode === 2
    readonly property bool wide: root.width > 480
    readonly property bool wide3: root.width > 900
    readonly property int autoCols: wide3 ? 3 : (wide ? 2 : 1)
    readonly property int effCols: layoutMode === 1 ? 3 : (lateral ? 2 : autoCols)
    readonly property int contentW: Math.max(0, root.width - Kirigami.Units.largeSpacing * 2)
    readonly property int cellW: effCols === 1 ? contentW : Math.floor((contentW - (effCols - 1) * Kirigami.Units.largeSpacing) / effCols)
    readonly property int ocSpan: lateral ? 1 : (effCols === 1 ? 1 : (effCols === 2 ? 2 : 1))
    readonly property int ocCellW: (lateral || effCols === 3) ? cellW : contentW
    readonly property int qdCellW: effCols === 1 ? contentW : cellW
    readonly property bool ocRow: circleMode && ocCellW >= 280
    readonly property int trioDia: circleMode ? (ocRow ? Math.max(32, Math.min(160, Math.max(cfgDia, Math.floor(ocCellW / 3) - 8)))
                                                          : Math.max(40, Math.min(160, Math.max(cfgDia, Math.floor(ocCellW * 0.32))))) : cfgDia
    readonly property int singleDia: circleMode ? Math.max(40, Math.min(160, Math.max(cfgDia, Math.floor(qdCellW * 0.32)))) : cfgDia
    readonly property bool showQwen: plasmoid.configuration.showQwen !== false
    readonly property bool showOpencode: plasmoid.configuration.showOpencode !== false
    readonly property bool showDeepseek: plasmoid.configuration.showDeepseek !== false
    readonly property bool showOpenai: plasmoid.configuration.showOpenai !== false
    readonly property bool showAnthropic: plasmoid.configuration.showAnthropic !== false
    readonly property bool showOc5h: plasmoid.configuration.showOc5h !== false
    readonly property bool showOcWeek: plasmoid.configuration.showOcWeek !== false
    readonly property bool showOcMonth: plasmoid.configuration.showOcMonth !== false

    // === Fondo: flag estándar KDE 6 (el sistema muestra el toggle "Mostrar/Ocultar fondo").
    // Contraste: sigue los hints EFECTIVOS en vivo (respeta el toggle estándar).
    readonly property bool flat: (Plasmoid.effectiveBackgroundHints & PlasmaCore.Types.StandardBackground) === 0
                              && (Plasmoid.effectiveBackgroundHints & PlasmaCore.Types.TranslucentBackground) === 0
    readonly property color colMain: flat ? "white" : Kirigami.Theme.textColor
    readonly property color colSub: flat ? "#f5f5f5" : Kirigami.Theme.disabledTextColor
    readonly property color circleColor: plasmoid.configuration.circleColor ?? "#E93DAE"
    readonly property color trackColor: plasmoid.configuration.trackColor ?? "#3DAEE9"

    // === Fondo: patrón estándar KDE 6 (igual que systemmonitor y otros applets).
    // ConfigurableBackground = el sistema expone "Mostrar/Ocultar fondo" al usuario.
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: fullRepresentation
    fullRepresentation: mainRep
    compactRepresentation: null

    // ---- Formato de reset ----
    function resetStr(sec) {
        if (typeof sec !== "number" || !isFinite(sec)) return "–"
        sec = Math.max(0, Math.floor(sec))
        var d = Math.floor(sec / 86400)
        var h = Math.floor((sec % 86400) / 3600)
        var m = Math.floor((sec % 3600) / 60)
        if (d > 0) return i18np("%1d %2h", "%1d %2h", d, h)
        if (h > 0) return i18np("%1h %2m", "%1h %2m", h, m)
        return i18np("%1m", "%1m", m)
    }
    function esc(s) {
        return String(s || "").replace(/'/g, "'\\''")
    }

    // === Backend ===
    function refresh() {
        var key = esc(plasmoid.configuration.opencodeApiKey)
        var cookie = esc(plasmoid.configuration.qwenCookie)
        var token = esc(plasmoid.configuration.qwenSecToken)
        var dsKey = esc(plasmoid.configuration.deepseekApiKey)
        var dsBase = Number(plasmoid.configuration.deepseekBaseline) || 10
        var oaiKey = esc(plasmoid.configuration.openaiApiKey)
        var antKey = esc(plasmoid.configuration.anthropicApiKey)
        var script = Qt.resolvedUrl("../quota_fetch.py").toString().replace("file://", "")
        var cmd = "python3 '" + script + "' --opencode-key '" + key +
                  "' --qwen-cookie '" + cookie + "' --qwen-sec-token '" + token +
                  "' --deepseek-key '" + dsKey + "' --deepseek-baseline " + dsBase +
                  " --openai-key '" + oaiKey + "' --anthropic-key '" + antKey +
                  "' >/dev/null 2>&1; cat /tmp/opencode/ia-quota.json 2>/dev/null"
        dataSource.exec(cmd)
    }

    P5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []
        function exec(cmd) { if (cmd) connectSource(cmd) }
        onNewData: function(sourceName, data) {
            var out = data["stdout"]
            if (out && out.trim().length > 0) {
                try {
                    root.quotaData = JSON.parse(out)
                    root.lastError = ""
                } catch (e) { root.lastError = i18n("Error reading data") }
            } else {
                root.lastError = i18n("No backend response")
            }
            disconnectSource(sourceName)
        }
    }

    Timer {
        id: refreshTimer
        interval: 4 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()

    // Refrescar al cambiar la configuración (hash de propiedades)
    property string _cfgHash: [
        plasmoid.configuration.opencodeApiKey,
        plasmoid.configuration.qwenCookie,
        plasmoid.configuration.qwenSecToken,
        plasmoid.configuration.deepseekApiKey,
        plasmoid.configuration.deepseekBaseline,
        plasmoid.configuration.openaiApiKey,
        plasmoid.configuration.anthropicApiKey,
        plasmoid.configuration.displayMode,
        plasmoid.configuration.layoutMode,
        plasmoid.configuration.circleDiameter,
        plasmoid.configuration.circleColor,
        plasmoid.configuration.trackColor,
        plasmoid.configuration.showQwen,
        plasmoid.configuration.showOpencode,
        plasmoid.configuration.showDeepseek,
        plasmoid.configuration.showOpenai,
        plasmoid.configuration.showAnthropic,
        plasmoid.configuration.showOc5h,
        plasmoid.configuration.showOcWeek,
        plasmoid.configuration.showOcMonth
    ].join("\u0001")
    on_CfgHashChanged: Qt.callLater(root.refresh)

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        }
    ]

    // === UI ===
    Component {
        id: mainRep

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            // Margen estándar del tema (igual que el resto de applets: kdeconnect, etc.)
            Layout.margins: Kirigami.Units.smallSpacing

            // Sin credenciales
            PlasmaComponents3.Label {
                visible: !root.quotaData ||
                         (!root.quotaData.opencode && !root.quotaData.qwen && !root.quotaData.deepseek &&
                      !root.quotaData.openai && !root.quotaData.anthropic)
                text: i18n("Configure your credentials to see the quota")
                font: Kirigami.Theme.defaultFont
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                color: root.colSub
                style: root.flat ? Text.Outline : Text.Normal
                styleColor: "#d0000000"
            }

            // ---------- Proveedores: 1, 2 o 3 columnas según el ancho ----------
            GridLayout {
                id: provGrid
                columns: root.effCols
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

            // ---------- OpenCode Go ----------
            ColumnLayout {
                visible: root.showOpencode && root.quotaData && root.quotaData.opencode &&
                         !root.quotaData.opencode.error
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.columnSpan: root.ocSpan
                Layout.rowSpan: root.lateral ? 2 : 1

                PlasmaComponents3.Label {
                    text: i18n("OpenCode Go")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                GridLayout {
                    columns: root.ocRow ? 3 : 1
                    columnSpacing: root.circleMode ? Kirigami.Units.largeSpacing : 0
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter

                    MetricDisplay {
                        visible: root.showOc5h && !!root.quotaData.opencode.rolling
                        flat: root.flat
                        lbl: i18n("5h")
                        pct: (root.quotaData.opencode.rolling && root.quotaData.opencode.rolling.percent) || 0
                        rst: i18n("reset %1", resetStr(root.quotaData.opencode.rolling ? root.quotaData.opencode.rolling.reset_in_sec : 0))
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.trioDia
                    }
                    MetricDisplay {
                        visible: root.showOcWeek && !!root.quotaData.opencode.weekly
                        flat: root.flat
                        lbl: i18n("Weekly")
                        pct: (root.quotaData.opencode.weekly && root.quotaData.opencode.weekly.percent) || 0
                        rst: i18n("reset %1", resetStr(root.quotaData.opencode.weekly ? root.quotaData.opencode.weekly.reset_in_sec : 0))
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.trioDia
                    }
                    MetricDisplay {
                        visible: root.showOcMonth && !!root.quotaData.opencode.monthly
                        flat: root.flat
                        lbl: i18n("Monthly")
                        pct: (root.quotaData.opencode.monthly && root.quotaData.opencode.monthly.percent) || 0
                        rst: i18n("reset %1", resetStr(root.quotaData.opencode.monthly ? root.quotaData.opencode.monthly.reset_in_sec : 0))
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.trioDia
                    }
                }
            }

            // Separador (solo apilado o OC-arriba; en lateral y 3-col estorba)
            Kirigami.Separator {
                visible: !root.lateral && root.effCols !== 3 && root.quotaData && ((root.showOpencode && root.quotaData.opencode && !root.quotaData.opencode.error) ||
                                             (root.showQwen && root.quotaData.qwen && !root.quotaData.qwen.error))
                Layout.fillWidth: true
                Layout.columnSpan: root.effCols
            }

            // ---------- QwenCloud ----------
            ColumnLayout {
                visible: root.showQwen && root.quotaData && root.quotaData.qwen &&
                         !root.quotaData.qwen.error
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                PlasmaComponents3.Label {
                    text: i18n("QwenCloud") + (root.quotaData.qwen.plan ? " · " + root.quotaData.qwen.plan : "")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                MetricDisplay {
                    flat: root.flat
                    lbl: i18n("Free")
                    pct: root.quotaData.qwen.remaining_pct || 0
                    rst: i18n("quota %1", root.quotaData.qwen.plan_quota || "–")
                    circle: root.circleMode
                    colorValue: root.circleColor
                    colorTrack: root.trackColor
                    big: root.wide
                    diameter: root.singleDia
                    Layout.alignment: Qt.AlignHCenter
                }
                PlasmaComponents3.Label {
                    text: i18n("Expires: %1 · Reset: %2",
                               root.quotaData.qwen.expiry || "–",
                               root.quotaData.qwen.reset || "–")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: root.colSub
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ---------- DeepSeek ----------
            ColumnLayout {
                visible: root.showDeepseek && root.quotaData && root.quotaData.deepseek &&
                         !root.quotaData.deepseek.error
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                PlasmaComponents3.Label {
                    text: i18n("DeepSeek") +
                          (root.quotaData.deepseek.currency ? " · " + root.quotaData.deepseek.currency : "") +
                          (root.quotaData.deepseek.total_balance != null ? " " + root.quotaData.deepseek.total_balance : "")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                MetricDisplay {
                    flat: root.flat
                    visible: root.quotaData.deepseek.percent !== null
                    lbl: i18n("Balance")
                    pct: root.quotaData.deepseek.percent || 0
                    rst: i18n("of $%1", root.quotaData.deepseek.baseline)
                    circle: root.circleMode
                    colorValue: root.circleColor
                    colorTrack: root.trackColor
                    big: root.wide
                    diameter: root.singleDia
                    Layout.alignment: Qt.AlignHCenter
                }
                PlasmaComponents3.Label {
                    text: root.quotaData.deepseek.is_available
                          ? i18n("Available")
                          : i18n("Not available")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: root.colSub
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ---------- OpenAI ----------
            ColumnLayout {
                visible: root.showOpenai && root.quotaData && root.quotaData.openai &&
                         !root.quotaData.openai.error
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                PlasmaComponents3.Label {
                    text: i18n("OpenAI") +
                          (root.quotaData.openai.total_available != null ? " · $" + root.quotaData.openai.total_available : "")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                MetricDisplay {
                    flat: root.flat
                    visible: root.quotaData.openai.percent !== null && root.quotaData.openai.percent !== undefined
                    lbl: i18n("Balance")
                    pct: root.quotaData.openai.percent || 0
                    rst: i18n("of $%1", root.quotaData.openai.baseline)
                    circle: root.circleMode
                    colorValue: root.circleColor
                    colorTrack: root.trackColor
                    big: root.wide
                    diameter: root.singleDia
                    Layout.alignment: Qt.AlignHCenter
                }
                PlasmaComponents3.Label {
                    visible: root.quotaData.openai.percent == null && !!root.quotaData.openai.key_valid
                    text: i18n("Valid key · %1 models", root.quotaData.openai.model_count || 0)
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.bold: true
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                PlasmaComponents3.Label {
                    visible: root.quotaData.openai.percent == null && !!root.quotaData.openai.key_valid
                    text: i18n("Quota not public")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: root.colSub
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ---------- Anthropic ----------
            ColumnLayout {
                visible: root.showAnthropic && root.quotaData && root.quotaData.anthropic &&
                         !root.quotaData.anthropic.error
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                PlasmaComponents3.Label {
                    text: i18n("Anthropic") +
                          (root.quotaData.anthropic.spent_month != null ? " · " + (root.quotaData.anthropic.currency || "") + " " + root.quotaData.anthropic.spent_month : "")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                PlasmaComponents3.Label {
                    visible: root.quotaData.anthropic.spent_month != null
                    text: i18n("Spent this month")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: root.colSub
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                PlasmaComponents3.Label {
                    visible: root.quotaData.anthropic.spent_month == null && !!root.quotaData.anthropic.key_valid
                    text: i18n("Valid key · %1 models", root.quotaData.anthropic.model_count || 0)
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.bold: true
                    color: root.colMain
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                PlasmaComponents3.Label {
                    visible: root.quotaData.anthropic.spent_month == null && !!root.quotaData.anthropic.key_valid
                    text: i18n("Quota not public")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: root.colSub
                    style: root.flat ? Text.Outline : Text.Normal
                    styleColor: "#d0000000"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            } // fin provGrid

            // Errores
            PlasmaComponents3.Label {
                visible: (root.quotaData && (root.quotaData.opencode && root.quotaData.opencode.error ||
                                              root.quotaData.qwen && root.quotaData.qwen.error ||
                                              root.quotaData.deepseek && root.quotaData.deepseek.error ||
                                              root.quotaData.openai && root.quotaData.openai.error ||
                                              root.quotaData.anthropic && root.quotaData.anthropic.error)) || root.lastError !== ""
                text: root.lastError ||
                      ((root.quotaData && root.quotaData.opencode && root.quotaData.opencode.error) ||
                       (root.quotaData && root.quotaData.qwen && root.quotaData.qwen.error) ||
                       (root.quotaData && root.quotaData.deepseek && root.quotaData.deepseek.error) ||
                       (root.quotaData && root.quotaData.openai && root.quotaData.openai.error) ||
                       (root.quotaData && root.quotaData.anthropic && root.quotaData.anthropic.error)) || ""
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.negativeTextColor
                style: root.flat ? Text.Outline : Text.Normal
                styleColor: "#d0000000"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}

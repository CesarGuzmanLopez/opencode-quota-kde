import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

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
    readonly property int trioDia: circleMode ? (ocRow ? Math.max(32, Math.min(160, Math.max(cfgDia, Math.floor(ocCellW / 3) - 8))) : Math.max(40, Math.min(160, Math.max(cfgDia, Math.floor(ocCellW * 0.32))))) : cfgDia
    readonly property int singleDia: circleMode ? Math.max(40, Math.min(160, Math.max(cfgDia, Math.floor(qdCellW * 0.32)))) : cfgDia
    readonly property bool showQwen: plasmoid.configuration.showQwen !== false
    readonly property bool showOpencode: plasmoid.configuration.showOpencode !== false
    readonly property bool showDeepseek: plasmoid.configuration.showDeepseek !== false
    readonly property bool showOpenai: plasmoid.configuration.showOpenai !== false
    readonly property bool showAnthropic: plasmoid.configuration.showAnthropic !== false
    // Acceso seguro (objeto vacío cuando el proveedor es null: evita TypeError)
    readonly property var oai: (quotaData && quotaData.openai) ? quotaData.openai : ({
    })
    readonly property var ant: (quotaData && quotaData.anthropic) ? quotaData.anthropic : ({
    })
    readonly property var oc: (quotaData && quotaData.opencode) ? quotaData.opencode : ({
    })
    readonly property var qw: (quotaData && quotaData.qwen) ? quotaData.qwen : ({
    })
    readonly property var ds: (quotaData && quotaData.deepseek) ? quotaData.deepseek : ({
    })
    readonly property bool showOc5h: plasmoid.configuration.showOc5h !== false
    readonly property bool showOcWeek: plasmoid.configuration.showOcWeek !== false
    readonly property bool showOcMonth: plasmoid.configuration.showOcMonth !== false
    // === Fondo: flag estándar KDE 6 (el sistema muestra el toggle "Mostrar/Ocultar fondo").
    // Contraste: sigue los hints EFECTIVOS en vivo (respeta el toggle estándar).
    readonly property bool flat: (Plasmoid.effectiveBackgroundHints & PlasmaCore.Types.StandardBackground) === 0 && (Plasmoid.effectiveBackgroundHints & PlasmaCore.Types.TranslucentBackground) === 0
    readonly property color colMain: flat ? "white" : Kirigami.Theme.textColor
    readonly property color colSub: flat ? "#f5f5f5" : Kirigami.Theme.disabledTextColor
    readonly property color circleColor: plasmoid.configuration.circleColor ?? "#E93DAE"
    readonly property color trackColor: plasmoid.configuration.trackColor ?? "#3DAEE9"
    // Identidad de marca por proveedor (los arcos usan los colores configurables)
    readonly property color accOc: "#3DAEE9"
    readonly property color accQwen: "#6172F3"
    readonly property color accDs: "#4D6BFE"
    readonly property color accOai: "#10A37F"
    readonly property color accAnt: "#D97757"
    // Datos envejecidos: el backend no respondió hace demasiado
    readonly property int staleMinutes: {
        if (!quotaData || !quotaData.updated_at)
            return -1;

        var t = Date.parse(String(quotaData.updated_at).replace(" ", "T"));
        if (isNaN(t))
            return -1;

        return Math.floor((Date.now() - t) / 60000);
    }
    readonly property bool stale: staleMinutes > 12
    readonly property string ageText: staleMinutes < 0 ? "" : (staleMinutes < 60 ? i18np("%1 min ago", "%1 min ago", staleMinutes) : i18np("%1 h ago", "%1 h ago", Math.floor(staleMinutes / 60)))
    // Refrescar al cambiar la configuración (hash de propiedades)
    property string _cfgHash: [plasmoid.configuration.opencodeApiKey, plasmoid.configuration.qwenCookie, plasmoid.configuration.qwenSecToken, plasmoid.configuration.deepseekApiKey, plasmoid.configuration.deepseekBaseline, plasmoid.configuration.openaiApiKey, plasmoid.configuration.anthropicApiKey, plasmoid.configuration.displayMode, plasmoid.configuration.layoutMode, plasmoid.configuration.circleDiameter, plasmoid.configuration.circleColor, plasmoid.configuration.trackColor, plasmoid.configuration.showQwen, plasmoid.configuration.showOpencode, plasmoid.configuration.showDeepseek, plasmoid.configuration.showOpenai, plasmoid.configuration.showAnthropic, plasmoid.configuration.showOc5h, plasmoid.configuration.showOcWeek, plasmoid.configuration.showOcMonth].join("\u0001")

    // ---- Formato de reset ----
    function resetStr(sec) {
        if (typeof sec !== "number" || !isFinite(sec))
            return "–";

        sec = Math.max(0, Math.floor(sec));
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return i18np("%1d %2h", "%1d %2h", d, h);

        if (h > 0)
            return i18np("%1h %2m", "%1h %2m", h, m);

        return i18np("%1m", "%1m", m);
    }

    // Días restantes (para el título, en la misma línea: no alarga el widget)
    function daysFromSec(sec) {
        if (typeof sec !== "number" || !isFinite(sec) || sec <= 0)
            return "";

        return Math.ceil(sec / 86400);
    }

    function daysFromDate(text) {
        if (!text)
            return "";

        var t = Date.parse(String(text).replace(" ", "T"));
        if (isNaN(t))
            return "";

        var d = Math.ceil((t - Date.now()) / 8.64e+07);
        return d > 0 ? d : "";
    }

    function headerSuffix(days) {
        return days ? " · " + i18n("reset %1d", days) : "";
    }

    function esc(s) {
        return String(s || "").replace(/'/g, "'\\''");
    }

    // Codifica UTF-8 a hex: las credenciales viajan sin texto en claro por argv
    // y sin caracteres especiales de shell (solo [0-9a-f]).
    function hex2(n) {
        var h = n.toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    function utf8Hex(str) {
        var out = "";
        for (var i = 0; i < str.length; ++i) {
            var c = str.charCodeAt(i);
            if (c < 128) {
                out += hex2(c);
            } else if (c < 2048) {
                out += hex2(192 | (c >> 6)) + hex2(128 | (c & 63));
            } else if (c >= 55296 && c <= 56319 && i + 1 < str.length) {
                var cp = 65536 + ((c - 55296) << 10) + (str.charCodeAt(++i) - 56320);
                out += hex2(240 | (cp >> 18)) + hex2(128 | ((cp >> 12) & 63)) + hex2(128 | ((cp >> 6) & 63)) + hex2(128 | (cp & 63));
            } else {
                out += hex2(224 | (c >> 12)) + hex2(128 | ((c >> 6) & 63)) + hex2(128 | (c & 63));
            }
        }
        return out;
    }

    // === Backend ===
    function refresh() {
        var creds = JSON.stringify({
            "opencode_api_key": plasmoid.configuration.opencodeApiKey || "",
            "qwen_cookie": plasmoid.configuration.qwenCookie || "",
            "qwen_sec_token": plasmoid.configuration.qwenSecToken || "",
            "deepseek_api_key": plasmoid.configuration.deepseekApiKey || "",
            "deepseek_baseline": Number(plasmoid.configuration.deepseekBaseline) || 10,
            "openai_api_key": plasmoid.configuration.openaiApiKey || "",
            "anthropic_api_key": plasmoid.configuration.anthropicApiKey || ""
        });
        var script = Qt.resolvedUrl("../quota_fetch.py").toString().replace("file://", "");
        var cmd = "python3 '" + script + "' --creds-hex " + utf8Hex(creds) + " >/dev/null 2>&1; cat /tmp/opencode/ia-quota.json 2>/dev/null";
        dataSource.exec(cmd);
    }

    // === Fondo: patrón estándar KDE 6 (igual que systemmonitor y otros applets).
    // ConfigurableBackground = el sistema expone "Mostrar/Ocultar fondo" al usuario.
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation
    fullRepresentation: mainRep
    compactRepresentation: null
    Component.onCompleted: root.refresh()
    on_CfgHashChanged: Qt.callLater(root.refresh)
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        }
    ]

    P5Support.DataSource {
        id: dataSource

        function exec(cmd) {
            if (cmd)
                connectSource(cmd);

        }

        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var out = data["stdout"];
            if (out && out.trim().length > 0) {
                try {
                    root.quotaData = JSON.parse(out);
                    root.lastError = "";
                } catch (e) {
                    root.lastError = i18n("Error reading data");
                }
            } else {
                root.lastError = i18n("No backend response");
            }
            disconnectSource(sourceName);
        }
    }

    Timer {
        id: refreshTimer

        interval: 4 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    // === UI ===
    Component {
        id: mainRep

        ColumnLayout {
            // fin provGrid

            spacing: Kirigami.Units.smallSpacing
            // Margen estándar del tema (igual que el resto de applets: kdeconnect, etc.)
            Layout.margins: Kirigami.Units.smallSpacing

            // Sin credenciales
            PlasmaComponents3.Label {
                visible: !root.quotaData || (!root.quotaData.opencode && !root.quotaData.qwen && !root.quotaData.deepseek && !root.quotaData.openai && !root.quotaData.anthropic)
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
                    visible: root.showOpencode && root.quotaData && root.quotaData.opencode && !root.oc.error
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.columnSpan: root.ocSpan
                    Layout.rowSpan: root.lateral ? 2 : 1

                    ProviderHeader {
                        badge: "OC"
                        accent: root.accOc
                        title: i18n("OpenCode Go")
                        suffix: root.headerSuffix(root.daysFromSec(root.oc.monthly ? root.oc.monthly.reset_in_sec : 0))
                        flat: root.flat
                        textColor: root.colMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    GridLayout {
                        columns: root.ocRow ? 3 : 1
                        columnSpacing: root.circleMode ? Kirigami.Units.largeSpacing : 0
                        rowSpacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        MetricDisplay {
                            visible: root.showOc5h && !!root.oc.rolling
                            flat: root.flat
                            lbl: i18n("5h")
                            stale: root.stale
                            pct: (root.oc.rolling && root.oc.rolling.percent) || 0
                            rst: i18n("reset %1", resetStr(root.oc.rolling ? root.oc.rolling.reset_in_sec : 0))
                            circle: root.circleMode
                            colorValue: root.circleColor
                            colorTrack: root.trackColor
                            big: root.wide
                            diameter: root.trioDia
                        }

                        MetricDisplay {
                            visible: root.showOcWeek && !!root.oc.weekly
                            flat: root.flat
                            lbl: i18n("Weekly")
                            stale: root.stale
                            pct: (root.oc.weekly && root.oc.weekly.percent) || 0
                            rst: i18n("reset %1", resetStr(root.oc.weekly ? root.oc.weekly.reset_in_sec : 0))
                            circle: root.circleMode
                            colorValue: root.circleColor
                            colorTrack: root.trackColor
                            big: root.wide
                            diameter: root.trioDia
                        }

                        MetricDisplay {
                            visible: root.showOcMonth && !!root.oc.monthly
                            flat: root.flat
                            lbl: i18n("Monthly")
                            stale: root.stale
                            pct: (root.oc.monthly && root.oc.monthly.percent) || 0
                            rst: i18n("reset %1", resetStr(root.oc.monthly ? root.oc.monthly.reset_in_sec : 0))
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
                    visible: !root.lateral && root.effCols !== 3 && root.quotaData && ((root.showOpencode && root.quotaData.opencode && !root.oc.error) || (root.showQwen && root.quotaData.qwen && !root.qw.error))
                    Layout.fillWidth: true
                    Layout.columnSpan: root.effCols
                }

                // ---------- QwenCloud ----------
                ColumnLayout {
                    visible: root.showQwen && root.quotaData && root.quotaData.qwen && !root.qw.error
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ProviderHeader {
                        badge: "Q"
                        accent: root.accQwen
                        title: i18n("QwenCloud") + (root.qw.plan ? " · " + root.qw.plan : "")
                        suffix: root.headerSuffix(root.daysFromDate(root.qw.reset))
                        flat: root.flat
                        textColor: root.colMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    MetricDisplay {
                        flat: root.flat
                        lbl: i18n("Used")
                        stale: root.stale
                        pct: 100 - (root.qw.remaining_pct || 0)
                        rst: i18n("quota %1", root.qw.plan_quota || "–")
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.singleDia
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        text: i18n("Expires: %1 · Reset: %2", root.qw.expiry || "–", root.qw.reset || "–")
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
                    visible: root.showDeepseek && root.quotaData && root.quotaData.deepseek && !root.ds.error
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ProviderHeader {
                        badge: "DS"
                        accent: root.accDs
                        title: i18n("DeepSeek") + (root.ds.total_balance != null ? " · " + (root.ds.currency || "") + " " + root.ds.total_balance : "")
                        suffix: ""
                        flat: root.flat
                        textColor: root.colMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    MetricDisplay {
                        flat: root.flat
                        visible: root.ds.percent !== null
                        lbl: i18n("Used")
                        stale: root.stale
                        pct: 100 - (root.ds.percent || 0)
                        rst: i18n("of $%1", root.ds.baseline)
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.singleDia
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        text: root.ds.is_available ? i18n("Available") : i18n("Not available")
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
                    visible: root.showOpenai && root.quotaData && root.quotaData.openai && !root.oai.error
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ProviderHeader {
                        badge: "AI"
                        accent: root.accOai
                        title: i18n("OpenAI") + (root.oai.total_available != null ? " · $" + root.oai.total_available : "")
                        suffix: ""
                        flat: root.flat
                        textColor: root.colMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    MetricDisplay {
                        flat: root.flat
                        visible: root.oai.percent !== null && root.oai.percent !== undefined
                        lbl: i18n("Used")
                        stale: root.stale
                        pct: 100 - (root.oai.percent || 0)
                        rst: i18n("of $%1", root.oai.baseline)
                        circle: root.circleMode
                        colorValue: root.circleColor
                        colorTrack: root.trackColor
                        big: root.wide
                        diameter: root.singleDia
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        visible: root.oai.percent == null && !!root.oai.key_valid
                        text: i18n("Valid key · %1 models", root.oai.model_count || 0)
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        font.bold: true
                        color: root.colMain
                        style: root.flat ? Text.Outline : Text.Normal
                        styleColor: "#d0000000"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        visible: root.oai.percent == null && !!root.oai.key_valid
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
                    visible: root.showAnthropic && root.quotaData && root.quotaData.anthropic && !root.ant.error
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ProviderHeader {
                        badge: "An"
                        accent: root.accAnt
                        title: i18n("Anthropic") + (root.ant.spent_month != null ? " · " + (root.ant.currency || "") + " " + root.ant.spent_month : "")
                        suffix: ""
                        flat: root.flat
                        textColor: root.colMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        visible: root.ant.spent_month != null
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
                        visible: root.ant.spent_month == null && !!root.ant.key_valid
                        text: i18n("Valid key · %1 models", root.ant.model_count || 0)
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        font.bold: true
                        color: root.colMain
                        style: root.flat ? Text.Outline : Text.Normal
                        styleColor: "#d0000000"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PlasmaComponents3.Label {
                        visible: root.ant.spent_month == null && !!root.ant.key_valid
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

            }

            // Aviso de datos envejecidos
            PlasmaComponents3.Label {
                visible: root.quotaData && root.stale
                text: "⚠ " + i18n("Data from %1", root.ageText)
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
                color: Kirigami.Theme.neutralTextColor
                style: root.flat ? Text.Outline : Text.Normal
                styleColor: "#d0000000"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // Errores
            PlasmaComponents3.Label {
                visible: (root.quotaData && (root.quotaData.opencode && root.oc.error || root.quotaData.qwen && root.qw.error || root.quotaData.deepseek && root.ds.error || root.quotaData.openai && root.oai.error || root.quotaData.anthropic && root.ant.error)) || root.lastError !== ""
                text: root.lastError || ((root.quotaData && root.quotaData.opencode && root.oc.error) || (root.quotaData && root.quotaData.qwen && root.qw.error) || (root.quotaData && root.quotaData.deepseek && root.ds.error) || (root.quotaData && root.quotaData.openai && root.oai.error) || (root.quotaData && root.quotaData.anthropic && root.ant.error)) || ""
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

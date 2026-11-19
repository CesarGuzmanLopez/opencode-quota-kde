import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQC

KCM.SimpleKCM {
    // Credenciales (una sección por proveedor en el formulario)
    property alias cfg_opencodeApiKey: ocKey.text
    property alias cfg_qwenCookie: qwenCookie.text
    property alias cfg_qwenSecToken: qwenToken.text
    property alias cfg_deepseekApiKey: dsKey.text
    property alias cfg_deepseekBaseline: dsBaseline.value
    property alias cfg_openaiApiKey: oaiKey.text
    property alias cfg_showOpenai: showOpenai.checked
    property alias cfg_anthropicApiKey: antKey.text
    property alias cfg_showAnthropic: showAnthropic.checked
    // Apariencia
    property alias cfg_displayMode: displayModeBox.currentIndex
    property alias cfg_circleDiameter: circleDiameterSpin.value
    property alias cfg_circleColor: valueColorBtn.color
    property alias cfg_trackColor: trackColorBtn.color
    property alias cfg_layoutMode: layoutBox.currentIndex
    // Visibilidad
    property alias cfg_showQwen: showQwen.checked
    property alias cfg_showOpencode: showOpencode.checked
    property alias cfg_showDeepseek: showDeepseek.checked
    property alias cfg_showOc5h: showOc5h.checked
    property alias cfg_showOcWeek: showOcWeek.checked
    property alias cfg_showOcMonth: showOcMonth.checked

    Kirigami.FormLayout {
        // ----- OpenCode Go -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("OpenCode Go")
        }

        Controls.TextField {
            id: ocKey

            Kirigami.FormData.label: i18n("OpenCode Go API Key:")
            placeholderText: "API key (opencode.ai)"
            echoMode: TextInput.Password
        }

        Controls.CheckBox {
            id: showOpencode

            text: i18n("Show OpenCode Go")
            checked: true
        }

        Controls.CheckBox {
            id: showOc5h

            text: i18n("   · 5h window")
            checked: true
            enabled: showOpencode.checked
        }

        Controls.CheckBox {
            id: showOcWeek

            text: i18n("   · Weekly")
            checked: true
            enabled: showOpencode.checked
        }

        Controls.CheckBox {
            id: showOcMonth

            text: i18n("   · Monthly")
            checked: true
            enabled: showOpencode.checked
        }

        // ----- QwenCloud -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("QwenCloud")
        }

        Controls.TextField {
            id: qwenCookie

            Kirigami.FormData.label: i18n("QwenCloud Cookie:")
            placeholderText: "Full Cookie header"
            echoMode: TextInput.Password
        }

        Controls.TextField {
            id: qwenToken

            Kirigami.FormData.label: i18n("Qwen sec_token:")
            placeholderText: i18n("Auto-detected if left empty")
            echoMode: TextInput.Password
        }

        Controls.CheckBox {
            id: showQwen

            text: i18n("Show QwenCloud")
            checked: true
        }

        // ----- DeepSeek -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("DeepSeek")
        }

        Controls.TextField {
            id: dsKey

            Kirigami.FormData.label: i18n("DeepSeek API Key:")
            placeholderText: "sk-... (api.deepseek.com)"
            echoMode: TextInput.Password
        }

        Controls.SpinBox {
            id: dsBaseline

            Kirigami.FormData.label: i18n("Target quota ($):")
            from: 1
            to: 10000
            stepSize: 1
            value: 10
        }

        Controls.CheckBox {
            id: showDeepseek

            text: i18n("Show DeepSeek")
            checked: true
        }

        // ----- OpenAI -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("OpenAI")
        }

        Controls.TextField {
            id: oaiKey

            Kirigami.FormData.label: i18n("OpenAI API Key:")
            placeholderText: "sk-... (api.openai.com)"
            echoMode: TextInput.Password
        }

        Controls.CheckBox {
            id: showOpenai

            text: i18n("Show OpenAI")
            checked: true
        }

        // ----- Anthropic -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Anthropic")
        }

        Controls.TextField {
            id: antKey

            Kirigami.FormData.label: i18n("Anthropic API Key:")
            placeholderText: "sk-ant-... (api.anthropic.com)"
            echoMode: TextInput.Password
        }

        Controls.CheckBox {
            id: showAnthropic

            text: i18n("Show Anthropic")
            checked: true
        }

        // ----- Apariencia -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }

        // Nota: "Mostrar/Ocultar fondo" lo provee el sistema (modo edición del
        // escritorio) porque el widget declara ConfigurableBackground (estándar KDE 6).
        Controls.ComboBox {
            id: layoutBox

            Kirigami.FormData.label: i18n("Layout:")
            model: [i18n("Automatic"), i18n("Three in a row"), i18n("OpenCode on the left")]
        }

        Controls.ComboBox {
            id: displayModeBox

            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Bars"), i18n("Circles")]
        }

        Controls.SpinBox {
            id: circleDiameterSpin

            Kirigami.FormData.label: i18n("Base circle size:")
            from: 32
            to: 112
            stepSize: 4
            value: 48
            enabled: displayModeBox.currentIndex === 1
        }

        KQC.ColorButton {
            id: valueColorBtn

            Kirigami.FormData.label: i18n("Value color:")
            dialogTitle: i18n("Value color")
            showAlphaChannel: false
        }

        KQC.ColorButton {
            id: trackColorBtn

            Kirigami.FormData.label: i18n("Track color:")
            dialogTitle: i18n("Track color")
            showAlphaChannel: false
        }

        Kirigami.Separator {
        }

        Controls.Button {
            icon.name: "emblem-favorite"
            text: i18n("⭐ Give me a star on GitHub")
            Layout.fillWidth: true
            onClicked: Qt.openUrlExternally("https://github.com/CesarGuzmanLopez/ia-quota-widget")
        }

    }

}

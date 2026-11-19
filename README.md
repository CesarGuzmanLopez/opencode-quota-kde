# IA Quota

Desktop widget for KDE Plasma 6 showing your AI quotas.

![Widget](widget.png)

Shows OpenCode Go (5h, weekly, monthly), QwenCloud, DeepSeek
(balance over a configurable target), OpenAI and Anthropic,
as bars or circles, with automatic refresh.

## Install

```bash
kpackagetool6 -i .
cp icon.svg ~/.local/share/icons/hicolor/scalable/apps/org.cesar.iaquota.svg
kbuildsycoca6
```

Then right-click the desktop → _Add to panel_ → **IA Quota**.

## Setup

Right-click the widget → _Configure widget_ and paste your keys:

![Settings](configuraciones.png)

- **OpenCode Go / DeepSeek / OpenAI / Anthropic**: your API key.
- **QwenCloud**: your session cookie. In Firefox, open
  `home.qwencloud.com`, press F12 → _Network_ tab, reload,
  pick the main request → _Headers_ → right-click
  `Cookie` → _Copy value_ and paste it in the field.

![Where to copy the cookie](cookieQwenCloud.png)

Without credentials the widget just asks you to configure them.
The background follows the standard Plasma toggle (edit mode),
and the text adapts on its own.

_Versión en español: [README.es.md](README.es.md)_

## Author

Cesar Guzman — GPL-2.0+

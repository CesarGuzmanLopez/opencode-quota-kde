# IA Quota

Widget para KDE Plasma 6 que muestra tus cuotas de IA en el escritorio.

![Widget](widget.png)

Muestra OpenCode Go (5h, semanal, mensual), QwenCloud, DeepSeek
(balance sobre cuota configurable), OpenAI y Anthropic,
en barras o círculos, con actualización automática.

## Instalación

```bash
kpackagetool6 -i .
cp icon.svg ~/.local/share/icons/hicolor/scalable/apps/org.cesar.iaquota.svg
kbuildsycoca6
```

Luego clic derecho en el escritorio → _Añadir al panel_ → **IA Quota**.

## Configuración

Clic derecho en el widget → _Configurar widget_ y pega tus claves:

![Configuración](configuraciones.png)

- **OpenCode Go / DeepSeek / OpenAI / Anthropic**: su API key.
- **QwenCloud**: la cookie de sesión. En Firefox, abre
  `home.qwencloud.com`, pulsa F12 → pestaña _Red_, recarga,
  elige la petición principal → _Cabeceras_ → clic derecho en
  `Cookie` → _Copiar valor_ y pégalo en el campo.

![Dónde copiar la cookie](cookieQwenCloud.png)

Sin credenciales el widget solo pide configurarlas.
El fondo se oculta/muestra desde el modo de edición
(estándar de Plasma), y el texto se adapta solo.

_English version: [README.md](README.md)_

## Autor

Cesar Guzman — GPL-2.0+

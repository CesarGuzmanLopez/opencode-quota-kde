# OpenCode Quota

Widget de cuotas para KDE Plasma 6, centrado en **OpenCode Go** (ventanas de 5 h,
semanal y mensual). También lee QwenCloud, DeepSeek, OpenAI y Anthropic, así que
sirve como monitor general de cuotas de IA.

![Widget](widget.png)

Barras o círculos, diseño adaptable, fondo según el tema y 5 idiomas.

## Instalación

```bash
kpackagetool6 -t Plasma/Applet -i org.cesar.iaquota.plasmoid
```

Clic derecho en el escritorio → *Añadir al panel* → **IA Quota**.

## Configuración

Clic derecho en el widget → *Configurar widget* y pega tus claves:

![Configuración](configuraciones.png)

- **OpenCode Go / DeepSeek / OpenAI / Anthropic**: su API key.
- **QwenCloud**: la cookie de sesión. En Firefox abre `home.qwencloud.com`,
  pulsa F12 → *Red*, recarga, elige la petición principal → *Cabeceras* →
  clic derecho en `Cookie` → *Copiar valor* y pégala.

![Dónde copiar la cookie](cookieQwenCloud.png)

Sin credenciales el widget solo pide configurarlas. El fondo sigue el toggle
estándar de Plasma (modo edición) y el contraste del texto se adapta solo.

*Versión en inglés: [README.md](README.md)*

## Autor

Cesar Guzman — GPL-2.0+

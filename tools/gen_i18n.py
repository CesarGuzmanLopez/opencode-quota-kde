#!/usr/bin/env python3
"""Genera .po ES/FR/ZH/JA para org.cesar.iaquota y compila .mo."""

import os
import subprocess

BS = chr(92)
Q = chr(34)
NL = chr(10)


# Plurales con formas propias por idioma
PLURAL_EXTRA = {
    "%1 min ago": {
        "es": ("hace %1 minuto", "hace %1 minutos"),
        "fr": ("il y a %1 minute", "il y a %1 minutes"),
        "zh": ("%1 分钟前", "%1 分钟前"),
        "ja": ("%1分前", "%1分前"),
    },
    "%1 h ago": {
        "es": ("hace %1 hora", "hace %1 horas"),
        "fr": ("il y a %1 heure", "il y a %1 heures"),
        "zh": ("%1 小时前", "%1 小时前"),
        "ja": ("%1時間前", "%1時間前"),
    },
}


def pq(s):
    return Q + s.replace(BS, BS + BS).replace(Q, BS + Q) + Q


T = {
    "Configure your credentials to see the quota": {
        "es": "Configura tus credenciales para ver la cuota",
        "fr": "Configurez vos identifiants pour voir le quota",
        "zh": "配置您的凭据以查看配额",
        "ja": "クレデンシャルを設定してクォータを表示",
    },
    "OpenCode Go": {
        "es": "OpenCode Go",
        "fr": "OpenCode Go",
        "zh": "OpenCode Go",
        "ja": "OpenCode Go",
    },
    "5h": {"es": "5h", "fr": "5h", "zh": "5小时", "ja": "5時間"},
    "reset %1": {
        "es": "reset %1",
        "fr": "réinitialisation %1",
        "zh": "重置 %1",
        "ja": "リセット %1",
    },
    "Weekly": {"es": "Semanal", "fr": "Hebdomadaire", "zh": "每周", "ja": "週間"},
    "Monthly": {"es": "Mensual", "fr": "Mensuel", "zh": "每月", "ja": "月間"},
    "QwenCloud": {
        "es": "QwenCloud",
        "fr": "QwenCloud",
        "zh": "QwenCloud",
        "ja": "QwenCloud",
    },
    "Expires: %1 · Reset: %2": {
        "es": "Expira: %1 · Reset: %2",
        "fr": "Expire : %1 · Réinitialisation : %2",
        "zh": "过期：%1 · 重置：%2",
        "ja": "有効期限：%1 · リセット：%2",
    },
    "DeepSeek": {
        "es": "DeepSeek",
        "fr": "DeepSeek",
        "zh": "DeepSeek",
        "ja": "DeepSeek",
    },
    "Not available": {
        "es": "No disponible",
        "fr": "Non disponible",
        "zh": "不可用",
        "ja": "利用不可",
    },
    "Refresh now": {
        "es": "Actualizar ahora",
        "fr": "Actualiser",
        "zh": "立即刷新",
        "ja": "今すぐ更新",
    },
    "Error reading data": {
        "es": "Error al leer datos",
        "fr": "Erreur de lecture des données",
        "zh": "读取数据出错",
        "ja": "データ読み取りエラー",
    },
    "OpenCode Go API Key:": {
        "es": "Clave API de OpenCode Go:",
        "fr": "Clé API OpenCode Go :",
        "zh": "OpenCode Go API 密钥：",
        "ja": "OpenCode Go APIキー：",
    },
    "Show OpenCode Go": {
        "es": "Mostrar OpenCode Go",
        "fr": "Afficher OpenCode Go",
        "zh": "显示 OpenCode Go",
        "ja": "OpenCode Goを表示",
    },
    "   · 5h window": {
        "es": "   · Ventana 5h",
        "fr": "   · Fenêtre 5h",
        "zh": "   · 5小时窗口",
        "ja": "   · 5時間ウィンドウ",
    },
    "   · Weekly": {
        "es": "   · Semanal",
        "fr": "   · Hebdomadaire",
        "zh": "   · 每周",
        "ja": "   · 週間",
    },
    "   · Monthly": {
        "es": "   · Mensual",
        "fr": "   · Mensuel",
        "zh": "   · 每月",
        "ja": "   · 月間",
    },
    "QwenCloud Cookie:": {
        "es": "Cookie de QwenCloud:",
        "fr": "Cookie QwenCloud :",
        "zh": "QwenCloud Cookie：",
        "ja": "QwenCloud Cookie：",
    },
    "Qwen sec_token:": {
        "es": "Qwen sec_token:",
        "fr": "Qwen sec_token :",
        "zh": "Qwen sec_token：",
        "ja": "Qwen sec_token：",
    },
    "Auto-detected if left empty": {
        "es": "Se auto-detecta si se deja vacío",
        "fr": "Détecté automatiquement si vide",
        "zh": "留空则自动检测",
        "ja": "空の場合は自動検出",
    },
    "Show QwenCloud": {
        "es": "Mostrar QwenCloud",
        "fr": "Afficher QwenCloud",
        "zh": "显示 QwenCloud",
        "ja": "QwenCloudを表示",
    },
    "DeepSeek API Key:": {
        "es": "Clave API de DeepSeek:",
        "fr": "Clé API DeepSeek :",
        "zh": "DeepSeek API 密钥：",
        "ja": "DeepSeek APIキー：",
    },
    "Show DeepSeek": {
        "es": "Mostrar DeepSeek",
        "fr": "Afficher DeepSeek",
        "zh": "显示 DeepSeek",
        "ja": "DeepSeekを表示",
    },
    "Used": {
        "es": "Usado",
        "fr": "Utilis\u00e9",
        "zh": "已用",
        "ja": "使用済み",
    },
    "Available": {
        "es": "Disponible",
        "fr": "Disponible",
        "zh": "可用",
        "ja": "利用可能",
    },
    "quota %1": {
        "es": "cuota %1",
        "fr": "quota %1",
        "zh": "配额 %1",
        "ja": "クォータ %1",
    },
    "of $%1": {"es": "de $%1", "fr": "sur $%1", "zh": "共 $%1", "ja": "$%1のうち"},
    "Appearance": {"es": "Apariencia", "fr": "Apparence", "zh": "外观", "ja": "外観"},
    "Style:": {"es": "Estilo:", "fr": "Style :", "zh": "样式：", "ja": "スタイル："},
    "Bars": {"es": "Barras", "fr": "Barres", "zh": "条形", "ja": "バー"},
    "Circles": {"es": "Círculos", "fr": "Cercles", "zh": "圆形", "ja": "サークル"},
    "Base circle size:": {
        "es": "Tamaño base de círculo:",
        "fr": "Taille de base des cercles :",
        "zh": "圆形基准大小：",
        "ja": "基準サークルサイズ：",
    },
    "Value color:": {
        "es": "Color de valor:",
        "fr": "Couleur de la valeur :",
        "zh": "数值颜色：",
        "ja": "値の色：",
    },
    "Value color": {
        "es": "Color de valor",
        "fr": "Couleur de la valeur",
        "zh": "数值颜色",
        "ja": "値の色",
    },
    "Track color:": {
        "es": "Color de pista:",
        "fr": "Couleur de la piste :",
        "zh": "轨道颜色：",
        "ja": "トラックの色：",
    },
    "Track color": {
        "es": "Color de pista",
        "fr": "Couleur de la piste",
        "zh": "轨道颜色",
        "ja": "トラックの色",
    },
    "Target quota ($):": {
        "es": "Cuota objetivo ($):",
        "fr": "Quota cible ($):",
        "zh": "目标配额（$）：",
        "ja": "目標クォータ（$）：",
    },
    "Layout:": {
        "es": "Distribución:",
        "fr": "Disposition :",
        "zh": "布局：",
        "ja": "レイアウト：",
    },
    "Automatic": {
        "es": "Automática",
        "fr": "Automatique",
        "zh": "自动",
        "ja": "自動",
    },
    "Three in a row": {
        "es": "Tres en fila",
        "fr": "Trois en ligne",
        "zh": "三并排",
        "ja": "3つ横並び",
    },
    "OpenCode on the left": {
        "es": "OpenCode a la izquierda",
        "fr": "OpenCode à gauche",
        "zh": "OpenCode 在左侧",
        "ja": "OpenCodeを左に",
    },
    "OpenAI": {
        "es": "OpenAI",
        "fr": "OpenAI",
        "zh": "OpenAI",
        "ja": "OpenAI",
    },
    "OpenAI API Key:": {
        "es": "Clave API de OpenAI:",
        "fr": "Clé API OpenAI :",
        "zh": "OpenAI API 密钥：",
        "ja": "OpenAI APIキー：",
    },
    "Show OpenAI": {
        "es": "Mostrar OpenAI",
        "fr": "Afficher OpenAI",
        "zh": "显示 OpenAI",
        "ja": "OpenAIを表示",
    },
    "Anthropic": {
        "es": "Anthropic",
        "fr": "Anthropic",
        "zh": "Anthropic",
        "ja": "Anthropic",
    },
    "Anthropic API Key:": {
        "es": "Clave API de Anthropic:",
        "fr": "Clé API Anthropic :",
        "zh": "Anthropic API 密钥：",
        "ja": "Anthropic APIキー：",
    },
    "Show Anthropic": {
        "es": "Mostrar Anthropic",
        "fr": "Afficher Anthropic",
        "zh": "显示 Anthropic",
        "ja": "Anthropicを表示",
    },
    "Valid key · %1 models": {
        "es": "Key válida · %1 modelos",
        "fr": "Clé valide · %1 modèles",
        "zh": "有效密钥 · %1 个模型",
        "ja": "有効なキー · %1 モデル",
    },
    "Quota not public": {
        "es": "Cuota no pública",
        "fr": "Quota non public",
        "zh": "配额不公开",
        "ja": "クォータ非公開",
    },
    "Spent this month": {
        "es": "Gasto del mes",
        "fr": "Dépensé ce mois-ci",
        "zh": "本月支出",
        "ja": "今月の支出",
    },
    "No backend response": {
        "es": "Sin respuesta del backend",
        "fr": "Pas de réponse du backend",
        "zh": "后端无响应",
        "ja": "バックエンド応答なし",
    },
    "reset %1d": {
        "es": "reset %1 d",
        "fr": "reset %1 j",
        "zh": "%1 天后重置",
        "ja": "%1日後にリセット",
    },
    "⭐ Star on GitHub": {
        "es": "\u2b50 Dale una estrella en GitHub",
        "fr": "\u2b50 Donnez une étoile sur GitHub",
        "zh": "\u2b50 在 GitHub 给我一颗星",
        "ja": "\u2b50 GitHubでスターをください",
    },
    "Data from %1": {
        "es": "Datos de hace %1",
        "fr": "Données de %1",
        "zh": "数据来自 %1",
        "ja": "データ: %1",
    },
}

PLURALS = ["%1d %2h", "%1h %2m", "%1m"]

META = {
    "es": ("es", "nplurals=2; plural=(n != 1);", 2),
    "fr": ("fr", "nplurals=2; plural=(n > 1);", 2),
    "zh": ("zh_CN", "nplurals=1; plural=0;", 1),
    "ja": ("ja", "nplurals=1; plural=0;", 1),
}

DOMAINS = ["plasma_applet_org.cesar.iaquota", "org.cesar.iaquota"]


def header(lang, plural):
    lines = []
    lines.append("msgid " + Q + Q)
    lines.append("msgstr " + Q + Q)
    lines.append(Q + "Project-Id-Version: org.cesar.iaquota 1.0" + BS + "n" + Q)
    lines.append(Q + "Content-Type: text/plain; charset=UTF-8" + BS + "n" + Q)
    lines.append(Q + "Content-Transfer-Encoding: 8bit" + BS + "n" + Q)
    lines.append(Q + "Language: " + lang + BS + "n" + Q)
    lines.append(Q + "Plural-Forms: " + plural + BS + "n" + Q)
    return NL.join(lines)


def build(lang, nforms):
    parts = [header(META[lang][0], META[lang][1])]
    for msgid in sorted(T.keys()):
        parts.append("msgid " + pq(msgid))
        parts.append("msgstr " + pq(T[msgid][lang]))
        parts.append("")
    for p, forms in sorted(PLURAL_EXTRA.items()):
        sing, plur = forms[lang]
        parts.append("msgid " + pq(p))
        parts.append("msgid_plural " + pq(p))
        parts.append("msgstr[0] " + pq(sing))
        if nforms > 1:
            parts.append("msgstr[1] " + pq(plur))
        parts.append("")
    for p in PLURALS:
        parts.append("msgid " + pq(p))
        parts.append("msgid_plural " + pq(p))
        for i in range(nforms):
            parts.append("msgstr[" + str(i) + "] " + pq(p))
        parts.append("")
    return NL.join(parts)


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    podir = os.path.join(ROOT, "po")
    os.makedirs(podir, exist_ok=True)
    targets = [os.path.join(ROOT, "contents", "locale")]
    user = os.path.expanduser("~/.local/share/locale")
    if os.path.isdir(user):
        targets.append(user)
    for lang, (locale, _p, nforms) in META.items():
        popath = os.path.join(podir, lang + ".po")
        with open(popath, "w", encoding="utf-8") as f:
            f.write(build(lang, nforms))
        for base in targets:
            # dentro del paquete solo hace falta el dominio de la applet;
            # el alias sin prefijo solo sirve en ~/.local/share/locale
            doms = (
                DOMAINS
                if base != os.path.join(ROOT, "contents", "locale")
                else DOMAINS[:1]
            )
            for dom in doms:
                modir = os.path.join(base, locale, "LC_MESSAGES")
                os.makedirs(modir, exist_ok=True)
                mo = os.path.join(modir, dom + ".mo")
                r = subprocess.run(
                    ["msgfmt", "--check", popath, "-o", mo],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if r.returncode != 0:
                    print("MSGFMT ERROR", lang, r.stderr)
                    raise SystemExit(1)
        print("OK", lang, "->", locale)
    print(
        "cadenas:",
        len(T),
        "plurales:",
        len(PLURALS),
        "+",
        len(PLURAL_EXTRA),
    )


if __name__ == "__main__":
    main()

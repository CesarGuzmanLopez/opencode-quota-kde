#!/usr/bin/env python3

"""Fetch AI quota snapshots from OpenCode Go + QwenCloud Token Plan.

Writes one JSON document to /tmp/opencode/ia-quota.json (creates the dir).

Usage:
    quota_fetch.py [--opencode-key KEY] [--qwen-cookie COOKIE]
                   [--qwen-sec-token TOKEN] [--config PATH]
                   [--output PATH] [--timeout SECONDS]

Credentials passed on the command line take precedence over the config file.
Config file (default /tmp/opencode/ia-quota-config.json):
    {"opencode_api_key": "...", "qwen_cookie": "...", "qwen_sec_token": "..."}

No credentials -> {"opencode": null, "qwen": null, ...}. Secrets are never printed.
Stdlib only (urllib.request); TLS verified; 10s timeout; all errors handled.
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime
from typing import Any

# --------------------------------------------------------------- constants --
DEFAULT_CONFIG = "/tmp/opencode/ia-quota-config.json"
DEFAULT_OUTPUT = "/tmp/opencode/ia-quota.json"
DEFAULT_TIMEOUT = 10.0

OPENCODE_USAGE_URL = "https://opencode.ai/zen/go/v1/usage"
DEEPSEEK_BALANCE_URL = "https://api.deepseek.com/user/balance"
DEEPSEEK_BASELINE_USD = 10.0
ANTHROPIC_MODELS_URL = "https://api.anthropic.com/v1/models"
ANTHROPIC_COST_URL = "https://api.anthropic.com/v1/organizations/analytics/cost"
ANTHROPIC_VERSION = "2023-06-01"
ANTHROPIC_BETA = "analytics-usage-cost-2026-08-24"
OPENAI_GRANTS_URL = "https://api.openai.com/dashboard/billing/credit_grants"
OPENAI_MODELS_URL = "https://api.openai.com/v1/models"
QWEN_INFO_URL = "https://home.qwencloud.com/tool/user/info.json"
# Primary URL per spec; fallback is the gateway used by the official console
# (CodexBar issue #2328, verified end-to-end against a live personal plan).
QWEN_GATEWAY_PRIMARY = "https://home.qwencloud.com/"
QWEN_GATEWAY_FALLBACK = "https://cs-data.qwencloud.com/data/api.json"
QWEN_API_PREFIX = "zeldaHttp.apikeyMgr./tokenplan/personal/api/v2/"
CORNERSTONE = {
    "domain": "home.qwencloud.com",
    "consoleSite": "QWENCLOUD",
    "console": "ONE_CONSOLE",
    "xsp_lang": "en-US",
    "protocol": "V2",
    "productCode": "p_efm",
}
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) ia-quota-widget/1.0"
LOGIN_MARKERS = (
    "needlogin",
    "console need login",
    "need login",
    "unauthorized",
    "forbidden",
    "sessionexpired",
    "session expired",
    "expired",
    "invalidtoken",
    "invalid token",
    "notloggedin",
    "not logged in",
    "credential",
    "authfail",
    "authentication",
)

PCT_KEYS = {
    "rolling": (
        "per5HourPercentage",
        "fiveHourPercentage",
        "per5HourRatio",
        "five_hour_percentage",
        "rollingPercentage",
    ),
    "weekly": (
        "per1WeekPercentage",
        "perWeekPercentage",
        "weeklyPercentage",
        "per1WeekRatio",
        "weekly_ratio",
    ),
    "monthly": (
        "per1MonthPercentage",
        "perMonthPercentage",
        "monthlyPercentage",
        "per1MonthRatio",
        "monthly_ratio",
    ),
}
RESET_KEYS = {
    "rolling": ("per5HourResetTime", "fiveHourResetTime", "per5HourResetAt"),
    "weekly": ("per1WeekResetTime", "perWeekResetTime", "per1WeekResetAt"),
    "monthly": ("per1MonthResetTime", "perMonthResetTime", "per1MonthResetAt"),
}
PAYLOAD_KEYS = {
    "usage": (
        "per5HourPercentage",
        "per1WeekPercentage",
        "per1MonthPercentage",
        "fiveHourPercentage",
        "weeklyPercentage",
        "monthlyPercentage",
    ),
    "subscription": (
        "specCode",
        "spec_code",
        "specName",
        "tier",
        "endTime",
        "remainingDays",
    ),
}
TIER_KEYS = ("lite", "standard", "pro", "basic", "premium", "free")


# -------------------------------------------------------------- basic utils --
def _text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def _num(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        raw = value.strip().replace(",", "")
        if not raw:
            return None
        try:
            return float(raw)
        except ValueError:
            return None
    return None


def _iso_ms(value: Any) -> int | None:
    """Parse an ISO8601 timestamp (Z or explicit offset) into epoch ms."""
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    if text.endswith(("Z", "z")):
        text = text[:-1] + "+00:00"
    try:
        moment = datetime.fromisoformat(text)
    except ValueError:
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y/%m/%d %H:%M"):
            try:
                moment = datetime.strptime(text, fmt)
                break
            except ValueError:
                continue
        else:
            return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=UTC)
    return int(moment.timestamp() * 1000)


def _epoch_ms(value: Any) -> int | None:
    number = _num(value)
    if number is not None:
        if number > 1e11:
            return int(number)
        if number > 1e8:
            return int(number * 1000)
        return None
    return _iso_ms(value)


def _sec_until(milliseconds: int | None, now: float) -> int:
    if milliseconds is None:
        return 0
    return max(0, int(milliseconds / 1000.0 - now))


def _fmt_local(milliseconds: int | None) -> str | None:
    if milliseconds is None:
        return None
    try:
        return datetime.fromtimestamp(milliseconds / 1000.0).strftime("%Y-%m-%d %H:%M")
    except (OverflowError, OSError, ValueError):
        return None


def _deep_find(obj: Any, wanted: tuple, depth: int = 0) -> dict | None:
    """Find the first dict containing any of the wanted keys, at any depth."""
    if depth > 6:
        return None
    if isinstance(obj, dict):
        if any(key in obj for key in wanted):
            return obj
        for value in obj.values():
            found = _deep_find(value, wanted, depth + 1)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for value in obj:
            found = _deep_find(value, wanted, depth + 1)
            if found is not None:
                return found
    return None


def _login_error(doc: Any) -> bool:
    """Stale Qwen sessions answer HTTP 200 with an error code in the body."""
    if not isinstance(doc, dict):
        return False
    keys = ("errorCode", "errorMsg", "error_message", "message", "msg", "error", "code")
    scopes = [doc]
    data = doc.get("data")
    if isinstance(data, dict):
        scopes.append(data)
    for scope in scopes:
        for key in keys:
            value = scope.get(key)
            if isinstance(value, str) and any(
                m in value.lower() for m in LOGIN_MARKERS
            ):
                return True
        if _num(scope.get("httpStatus")) in (401.0, 403.0):
            return True
    return False


def _find_quota_config(obj: Any, depth: int = 0) -> dict | None:
    if depth > 6:
        return None
    if isinstance(obj, dict):
        if any(isinstance(obj.get(key), dict) for key in TIER_KEYS):
            return obj
        for value in obj.values():
            found = _find_quota_config(value, depth + 1)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for value in obj:
            found = _find_quota_config(value, depth + 1)
            if found is not None:
                return found
    return None


# ----------------------------------------------------------------- network --
def _request(url, headers, data=None, timeout=DEFAULT_TIMEOUT, context=None):
    request = urllib.request.Request(
        url,
        data=data,
        headers=headers,
        method="POST" if data is not None else "GET",
    )
    options = {"timeout": timeout}
    if context is not None:
        options["context"] = context
    with urllib.request.urlopen(request, **options) as response:
        return int(response.status), response.read()


# --------------------------------------------------------------- OpenCode --
def fetch_opencode(api_key: str, now: float, context, timeout: float) -> dict | None:
    api_key = _text(api_key)
    if not api_key:
        return None
    headers = {
        "Authorization": "Bearer " + api_key,
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    }
    try:
        _status, raw = _request(
            OPENCODE_USAGE_URL, headers, timeout=timeout, context=context
        )
    except urllib.error.HTTPError as exc:
        code = int(exc.code)
        return {"error": "auth-expired" if code in (401, 403) else "http-" + str(code)}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}

    try:
        doc = json.loads(raw.decode("utf-8", "replace"))
    except Exception:  # noqa: BLE001
        return {"error": "parse-error"}
    usage = doc.get("usage") if isinstance(doc, dict) else None
    if not isinstance(usage, dict):
        return {"error": "parse-error"}

    result = {}
    for window in ("rolling", "weekly", "monthly"):
        block = usage.get(window)
        entry = {"percent": None, "reset_in_sec": 0}
        if isinstance(block, dict):
            percent = _num(block.get("percent"))
            if percent is not None:
                entry["percent"] = round(percent, 2)
            entry["reset_in_sec"] = _sec_until(_epoch_ms(block.get("resetsAt")), now)
            if block.get("status") is not None:
                entry["status"] = _text(block.get("status"))
        result[window] = entry
    if all(entry["percent"] is None for entry in result.values()):
        return {"error": "parse-error"}
    return result


# ------------------------------------------------------------------- Qwen --
def _resolve_sec_token(
    cookie: str, provided: str, context, timeout: float
) -> str | None:
    token = _text(provided)
    if token:
        return token
    headers = {
        "Cookie": cookie,
        "Accept": "application/json, text/plain, */*",
        "Referer": "https://home.qwencloud.com/",
        "User-Agent": USER_AGENT,
    }
    try:
        status, raw = _request(QWEN_INFO_URL, headers, timeout=timeout, context=context)
    except Exception:  # noqa: BLE001
        return None
    if status >= 400:
        return None
    try:
        doc = json.loads(raw.decode("utf-8", "replace"))
    except Exception:  # noqa: BLE001
        return None
    found = _deep_find(doc, ("secToken", "sec_token", "securityToken"))
    if found:
        for key in ("secToken", "sec_token", "securityToken"):
            token = _text(found.get(key))
            if token:
                return token
    return None


def _gateway_urls():
    override = os.environ.get("QWEN_CLOUD_QUOTA_URL", "").strip()
    urls = []
    if override.startswith("https://"):
        urls.append(override)
    for candidate in (QWEN_GATEWAY_PRIMARY, QWEN_GATEWAY_FALLBACK):
        if candidate not in urls:
            urls.append(candidate)
    return urls


def _qwen_api(endpoint, token, cookie, context, timeout):
    api_name = QWEN_API_PREFIX + endpoint
    params = {
        "Api": api_name,
        "Data": {"cornerstoneParam": dict(CORNERSTONE)},
        "V": "1.0",
    }
    fields = {
        "product": "sfm_bailian",
        "action": "IntlBroadScopeAspnGateway",
        "region": "ap-southeast-1",
        "language": "en-US",
        "sec_token": token,
        "params": json.dumps(params, ensure_ascii=False, separators=(",", ":")),
    }
    body = urllib.parse.urlencode(fields).encode("utf-8")
    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Cookie": cookie,
        "Origin": "https://home.qwencloud.com",
        "Referer": "https://home.qwencloud.com/billing/subscription/token-plan-individual",
        "Accept": "application/json, text/plain, */*",
        "User-Agent": USER_AGENT,
    }
    query = urllib.parse.urlencode(
        {
            "product": "sfm_bailian",
            "action": "IntlBroadScopeAspnGateway",
            "api": api_name,
        }
    )
    last_error = "network-error"
    for base in _gateway_urls():
        url = base + ("&" if "?" in base else "?") + query
        try:
            status, raw = _request(
                url, headers, data=body, timeout=timeout, context=context
            )
        except urllib.error.HTTPError as exc:
            code = int(exc.code)
            last_error = "auth-required" if code in (401, 403) else "http-" + str(code)
            continue
        except Exception:  # noqa: BLE001
            last_error = "network-error"
            continue
        if status >= 400:
            last_error = "http-" + str(status)
            continue
        try:
            doc = json.loads(raw.decode("utf-8", "replace"))
        except Exception:  # noqa: BLE001
            last_error = "parse-error"
            continue
        if _login_error(doc):
            last_error = "auth-required"
            continue
        payload = (
            _find_quota_config(doc)
            if endpoint == "quota-config"
            else _deep_find(doc, PAYLOAD_KEYS.get(endpoint, ()))
        )
        if payload is not None:
            return payload, None
        last_error = "parse-error"
    return None, last_error


def _ratio(payload, keys):
    for key in keys:
        if key not in payload:
            continue
        value = _num(payload[key])
        if value is None:
            continue
        # API returns fractions (0.01 == 1%); tolerate already-percent values.
        return value if value <= 1.0001 else value / 100.0
    return None


def _first_ms(payload, keys):
    for key in keys:
        if key in payload:
            milliseconds = _epoch_ms(payload.get(key))
            if milliseconds is not None:
                return milliseconds
    return None


def _window(payload, window: str, now: float) -> dict:
    entry = {"percent": None, "reset_in_sec": 0}
    if not isinstance(payload, dict):
        return entry
    ratio = _ratio(payload, PCT_KEYS[window])
    if ratio is not None:
        entry["percent"] = round(ratio * 100.0, 2)
    entry["reset_in_sec"] = _sec_until(_first_ms(payload, RESET_KEYS[window]), now)
    return entry


def _plan_quota(quota_cfg, tier):
    if not isinstance(quota_cfg, dict):
        return None
    tiers = {}
    for key, value in quota_cfg.items():
        if isinstance(value, dict):
            tiers[_text(key).lower()] = value
    cfg = tiers.get(_text(tier).lower()) if tier else None
    if cfg is None:
        cfg = next(iter(tiers.values()), None)
    if cfg is None:
        return None
    for key in (
        "monthly",
        "per1Month",
        "perMonth",
        "total",
        "quota",
        "credits",
        "weekly",
        "per1Week",
        "five_hour",
        "fiveHour",
    ):
        value = _num(cfg.get(key))
        if value is not None:
            return round(value)
    return None


def fetch_qwen(cookie, provided_token, now, context, timeout) -> dict | None:
    cookie = _text(cookie)
    if not cookie:
        return None
    token = _resolve_sec_token(cookie, provided_token, context, timeout)
    if not token:
        return {"error": "auth-required"}

    usage, error_usage = _qwen_api("usage", token, cookie, context, timeout)
    subscription, _ = _qwen_api("subscription", token, cookie, context, timeout)
    quota_cfg, _ = _qwen_api("quota-config", token, cookie, context, timeout)

    if usage is None and subscription is None and quota_cfg is None:
        return {"error": error_usage or "auth-required"}

    windows = {
        name: _window(usage, name, now) for name in ("rolling", "weekly", "monthly")
    }

    tier = None
    if isinstance(subscription, dict):
        for key in ("specCode", "spec_code", "specName", "tier", "planName", "plan"):
            tier = _text(subscription.get(key))
            if tier:
                break
    plan = tier.replace("_", " ").replace("-", " ").title() if tier else None
    plan_quota = _plan_quota(quota_cfg, tier)

    # Prefer a direct remaining field; else derive it from the weekly window,
    # falling back to 5h and then monthly.
    direct = None
    if isinstance(usage, dict):
        for key in (
            "remainingPercentage",
            "remainingRatio",
            "freePercentage",
            "surplusPercentage",
        ):
            direct = _ratio(usage, (key,))
            if direct is not None:
                break
    if direct is not None:
        remaining_pct = round(direct * 100.0, 1)
    else:
        base_frac = None
        for name in ("weekly", "rolling", "monthly"):
            if windows[name]["percent"] is not None:
                base_frac = windows[name]["percent"] / 100.0
                break
        remaining_pct = (
            round((1.0 - base_frac) * 100.0, 1) if base_frac is not None else None
        )

    expiry = None
    if isinstance(subscription, dict):
        expiry = _fmt_local(
            _first_ms(subscription, ("endTime", "endTimeMs", "expiry", "expiresAt"))
        )
        if expiry is None:
            days = _num(subscription.get("remainingDays"))
            if days is not None:
                expiry = _fmt_local(int(now * 1000) + int(days * 86400 * 1000))

    reset = None
    if isinstance(usage, dict):
        for name in ("weekly", "rolling", "monthly"):
            milliseconds = _first_ms(usage, RESET_KEYS[name])
            if milliseconds is not None:
                reset = _fmt_local(milliseconds)
                break

    return {
        "plan": plan,
        "plan_quota": plan_quota,
        "remaining_pct": remaining_pct,
        "expiry": expiry,
        "reset": reset,
        "rolling": windows["rolling"],
        "weekly": windows["weekly"],
        "monthly": windows["monthly"],
    }


def fetch_deepseek(
    api_key: str, context, timeout: float, baseline: float
) -> dict | None:
    """DeepSeek balance as a percentage over a configurable $ baseline.

    GET https://api.deepseek.com/user/balance →
    {"is_available": bool,
     "balance_infos": [{"currency":"USD"|"CNY", "total_balance":"...",
                        "granted_balance":"...", "topped_up_balance":"..."}]}
    """
    if not api_key:
        return None
    request = urllib.request.Request(
        DEEPSEEK_BALANCE_URL,
        headers={
            "Authorization": "Bearer " + api_key,
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(
            request, timeout=timeout, context=context
        ) as response:
            doc = json.loads(response.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return {"error": "auth-expired"}
        return {"error": f"http-{exc.code}"}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}

    try:
        infos = doc.get("balance_infos") or []
        if not isinstance(infos, list):
            return {"error": "parse-error"}
        # Prefer USD, then CNY, then first entry
        chosen = None
        for info in infos:
            if not isinstance(info, dict):
                continue
            if _text(info.get("currency")).upper() == "USD":
                chosen = info
                break
            if chosen is None:
                chosen = info
        if chosen is None:
            return {"error": "parse-error"}

        currency = _text(chosen.get("currency")).upper() or "USD"
        total = _num(chosen.get("total_balance"))
        granted = _num(chosen.get("granted_balance")) or 0.0
        topped = _num(chosen.get("topped_up_balance")) or 0.0
        if total is None:
            total = granted + topped
        if total is None:
            return {"error": "parse-error"}

        pct = None
        base = baseline if baseline and baseline > 0 else DEEPSEEK_BASELINE_USD
        if currency == "USD":
            pct = max(0.0, min(100.0, total / base * 100.0))

        return {
            "is_available": bool(doc.get("is_available", False)),
            "currency": currency,
            "total_balance": round(total, 4),
            "granted_balance": round(granted, 4),
            "topped_up_balance": round(topped, 4),
            "percent": round(pct, 2) if pct is not None else None,
            "baseline": base,
        }
    except Exception:  # noqa: BLE001
        return {"error": "parse-error"}


def fetch_anthropic(api_key: str, context, timeout: float) -> dict | None:
    """Anthropic: gasto del mes (Admin/Analytics key) o validación de key.

    Una API key normal NO expone cuota (no hay endpoint público de saldo).
    Con Admin/Analytics key: GET /v1/organizations/analytics/cost →
    {"cost": {"currency": "USD", "amount": "41280.000000", ...}}.
    Sin permiso de admin: GET /v1/models valida la key (sin datos de cuota).
    """
    if not api_key:
        return None

    def _get(url, headers):
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(
            request, timeout=timeout, context=context
        ) as response:
            return json.loads(response.read().decode("utf-8", "replace"))

    base_headers = {
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_VERSION,
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    }
    now = datetime.now(UTC)
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    fmt = "%Y-%m-%dT%H:%M:%SZ"

    # 1) Coste del mes (requiere Admin o Analytics key)
    try:
        query = (
            "starting_at="
            + urllib.parse.quote(start.strftime(fmt))
            + "&ending_at="
            + urllib.parse.quote(now.strftime(fmt))
        )
        doc = _get(
            ANTHROPIC_COST_URL + "?" + query,
            dict(base_headers, **{"anthropic-beta": ANTHROPIC_BETA}),
        )
        cost = doc.get("cost") if isinstance(doc, dict) else None
        amount = _num(cost.get("amount")) if isinstance(cost, dict) else None
        if amount is not None:
            currency = _text(cost.get("currency")).upper() or "USD"
            return {
                "spent_month": round(amount, 4),
                "currency": currency,
                "month": start.strftime("%Y-%m"),
                "key_type": "admin",
            }
    except urllib.error.HTTPError as exc:
        if exc.code not in (400, 401, 403, 404):
            return {"error": f"http-{exc.code}"}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}

    # 2) Validación de key normal (sin datos de cuota públicos)
    try:
        doc = _get(ANTHROPIC_MODELS_URL, base_headers)
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return {"error": "auth-expired"}
        return {"error": f"http-{exc.code}"}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}
    try:
        data = doc.get("data") if isinstance(doc, dict) else None
        count = len(data) if isinstance(data, list) else 0
        return {"key_valid": True, "model_count": count, "quota_public": False}
    except Exception:  # noqa: BLE001
        return {"error": "parse-error"}


def fetch_openai(api_key: str, context, timeout: float) -> dict | None:
    """OpenAI: saldo de créditos (legacy) o validación de key.

    GET /dashboard/billing/credit_grants → credit_summary con
    total_granted/total_used/total_available. En cuentas nuevas ese endpoint
    exige session key (401 con API key normal): en ese caso se valida la key
    con GET /v1/models (sin datos de cuota públicos).
    """
    if not api_key:
        return None

    headers = {
        "Authorization": "Bearer " + api_key,
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    }

    def _get(url):
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(
            request, timeout=timeout, context=context
        ) as response:
            return json.loads(response.read().decode("utf-8", "replace"))

    # 1) Créditos (solo funciona con session key / cuentas con grants)
    try:
        doc = _get(OPENAI_GRANTS_URL)
        granted = _num(doc.get("total_granted")) or 0.0
        used = _num(doc.get("total_used")) or 0.0
        available = _num(doc.get("total_available"))
        if available is None:
            available = max(0.0, granted - used)
        pct = None
        if granted > 0:
            pct = max(0.0, min(100.0, available / granted * 100.0))
        return {
            "total_available": round(available, 4),
            "total_granted": round(granted, 4),
            "total_used": round(used, 4),
            "percent": round(pct, 2) if pct is not None else None,
            "baseline": round(granted, 4),
        }
    except urllib.error.HTTPError as exc:
        if exc.code not in (401, 403, 404):
            return {"error": f"http-{exc.code}"}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}

    # 2) Validación de key normal (sin datos de cuota públicos)
    try:
        doc = _get(OPENAI_MODELS_URL)
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return {"error": "auth-expired"}
        return {"error": f"http-{exc.code}"}
    except Exception:  # noqa: BLE001
        return {"error": "network-error"}
    try:
        data = doc.get("data") if isinstance(doc, dict) else None
        count = len(data) if isinstance(data, list) else 0
        return {"key_valid": True, "model_count": count, "quota_public": False}
    except Exception:  # noqa: BLE001
        return {"error": "parse-error"}


# --------------------------------------------------------------- plumbing --
def _read_config(path: str) -> dict:
    result = {
        "opencode_api_key": "",
        "qwen_cookie": "",
        "qwen_sec_token": "",
        "deepseek_api_key": "",
        "deepseek_baseline": 0.0,
        "openai_api_key": "",
        "anthropic_api_key": "",
    }
    try:
        with open(path, "r", encoding="utf-8") as handle:
            doc = json.load(handle)
    except Exception:  # noqa: BLE001
        return result
    if not isinstance(doc, dict):
        return result
    result.update(
        {
            "opencode_api_key": _text(doc.get("opencode_api_key")),
            "qwen_cookie": _text(doc.get("qwen_cookie")),
            "qwen_sec_token": _text(doc.get("qwen_sec_token")),
            "deepseek_api_key": _text(doc.get("deepseek_api_key")),
            "deepseek_baseline": _num(doc.get("deepseek_baseline")) or 0.0,
            "openai_api_key": _text(doc.get("openai_api_key")),
            "anthropic_api_key": _text(doc.get("anthropic_api_key")),
        }
    )
    return result


def _resolve_credentials(args, config: dict) -> dict:
    """Command-line values (when supplied) override config-file values."""
    result = dict(config)
    for option, target in (
        ("opencode_key", "opencode_api_key"),
        ("qwen_cookie", "qwen_cookie"),
        ("qwen_sec_token", "qwen_sec_token"),
        ("deepseek_key", "deepseek_api_key"),
        ("openai_key", "openai_api_key"),
        ("anthropic_key", "anthropic_api_key"),
    ):
        supplied = getattr(args, option, None)
        if supplied is not None:
            result[target] = _text(supplied)
    return result


def _write_output(path: str, payload: dict) -> bool:
    try:
        directory = os.path.dirname(os.path.abspath(path))
        os.makedirs(directory, exist_ok=True)
        temporary = path + ".tmp"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
        os.replace(temporary, path)
        return True
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("ia-quota: no se pudo escribir la salida: " + str(exc) + "\n")
        return False


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Consultar cuotas de OpenCode Go y QwenCloud Token Plan."
    )
    parser.add_argument(
        "--opencode-key",
        default=None,
        help="Bearer token de OpenCode Go (precede al config)",
    )
    parser.add_argument(
        "--qwen-cookie",
        default=None,
        help="Cookie completa de QwenCloud (precede al config)",
    )
    parser.add_argument(
        "--qwen-sec-token",
        default=None,
        help="sec_token de QwenCloud (precede al config)",
    )
    parser.add_argument(
        "--deepseek-key",
        default=None,
        help="API key de DeepSeek (precede al config)",
    )
    parser.add_argument(
        "--deepseek-baseline",
        type=float,
        default=None,
        help="Cuota objetivo DeepSeek en USD (default: 10)",
    )
    parser.add_argument(
        "--openai-key",
        default=None,
        help="API key de OpenAI (precede al config)",
    )
    parser.add_argument(
        "--anthropic-key",
        default=None,
        help="API key de Anthropic (precede al config)",
    )
    parser.add_argument(
        "--config", default=DEFAULT_CONFIG, help="Ruta del JSON de configuracion"
    )
    parser.add_argument(
        "--output", default=DEFAULT_OUTPUT, help="Ruta del JSON de salida"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help="Timeout de red en segundos (default: 10)",
    )
    args = parser.parse_args(argv)

    credentials = _resolve_credentials(args, _read_config(args.config))
    now = datetime.now(UTC).timestamp()
    try:
        context = ssl.create_default_context()
    except Exception:  # noqa: BLE001
        context = None

    payload = {
        "updated_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "opencode": fetch_opencode(
            credentials["opencode_api_key"], now, context, args.timeout
        ),
        "qwen": fetch_qwen(
            credentials["qwen_cookie"],
            credentials["qwen_sec_token"],
            now,
            context,
            args.timeout,
        ),
        "deepseek": fetch_deepseek(
            credentials["deepseek_api_key"],
            context,
            args.timeout,
            args.deepseek_baseline
            or credentials.get("deepseek_baseline")
            or DEEPSEEK_BASELINE_USD,
        ),
        "openai": fetch_openai(credentials["openai_api_key"], context, args.timeout),
        "anthropic": fetch_anthropic(
            credentials["anthropic_api_key"], context, args.timeout
        ),
    }
    return 0 if _write_output(args.output, payload) else 1


if __name__ == "__main__":
    sys.exit(main())

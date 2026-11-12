"""IMN CAP RSS. Keep active items that concern Guanacaste or the Pacific."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

RSS_URL = "https://cap-sources.s3.amazonaws.com/cr-imn-es/rss.xml"

PACIFIC = (
    "guanacaste", "pacífico", "pacifico", "nicoya", "sámara", "samara",
    "puntarenas", "papagayo", "nosara", "carrillo", "península de nicoya",
)
CARIBBEAN = ("caribe", "limón", "limon", "atlántico", "atlantico", "caribe norte")


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def relevant(title: str, description: str) -> bool:
    text = f"{title} {description}".lower()
    pacific = any(word in text for word in PACIFIC)
    if pacific:
        return True
    if any(word in text for word in CARIBBEAN):
        return False
    return True


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    value = value.strip()
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S.%f%z", "%a, %d %b %Y %H:%M:%S %z"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def parse_cap(xml_bytes: bytes) -> dict:
    root = ET.fromstring(xml_bytes)
    found: dict[str, str] = {}
    for el in root.iter():
        name = _local(el.tag)
        if name in {"headline", "description", "expires", "event", "web", "areaDesc"} and el.text:
            found.setdefault(name, el.text.strip())
    return found


def alerts_from_rss(rss_bytes: bytes, cap_lookup, now: datetime) -> list[dict]:
    """cap_lookup(url) -> bytes or None. Drops expired and Caribbean-only items."""
    root = ET.fromstring(rss_bytes)
    channel = root.find("channel")
    if channel is None:
        return []
    kept: list[dict] = []
    for item in channel.findall("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        description = (item.findtext("description") or "").strip()
        published = _parse_dt(item.findtext("pubDate"))
        expires = None
        if link:
            payload = cap_lookup(link)
            if payload:
                cap = parse_cap(payload)
                title = cap.get("headline") or title
                description = cap.get("description") or description
                expires = _parse_dt(cap.get("expires"))
                link = cap.get("web") or link
        if expires is None and published is not None:
            expires = published + timedelta(hours=36)
        if expires is not None and expires <= now:
            continue
        if not relevant(title, description):
            continue
        kept.append({
            "title": title,
            "summary": description,
            "url": link,
            "expires": expires.isoformat() if expires else None,
        })
    return kept

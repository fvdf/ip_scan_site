from __future__ import annotations

import csv
import io
import ipaddress
import json
import urllib.parse
import urllib.request
from typing import Any
from urllib.error import HTTPError, URLError


MAX_CSV_BYTES = 1_000_000
MAX_UNIQUE_IPS = 100

IP_API_FIELDS = [
    "status",
    "message",
    "query",
    "continent",
    "continentCode",
    "country",
    "countryCode",
    "region",
    "regionName",
    "city",
    "district",
    "zip",
    "lat",
    "lon",
    "timezone",
    "offset",
    "currency",
    "isp",
    "org",
    "as",
    "asname",
    "reverse",
    "mobile",
    "proxy",
    "hosting",
]

IP_HEADER_NAMES = {
    "ip",
    "ips",
    "ip_address",
    "ipaddress",
    "adresse_ip",
    "adresseip",
    "address",
}

KNOWN_MOBILE_KEYWORDS = [
    "orange",
    "sfr",
    "bouygues",
    "free mobile",
    "free",
    "telefonica",
    "vodafone",
    "verizon",
    "at&t",
    "tmobile",
    "t-mobile",
]

KNOWN_HOSTING_KEYWORDS = [
    "ovh",
    "hetzner",
    "online sas",
    "scaleway",
    "amazon",
    "aws",
    "google cloud",
    "microsoft",
    "azure",
    "digitalocean",
    "akamai",
    "cloudflare",
    "fastly",
]


class PayloadTooLargeError(ValueError):
    pass


class TooManyIpsError(ValueError):
    pass


class UpstreamRateLimitError(RuntimeError):
    def __init__(self, ttl: int | None = None) -> None:
        self.ttl = ttl
        message = "Le quota temporaire du fournisseur IP est atteint."
        if ttl is not None:
            message = f"{message} Reessayez dans {ttl} secondes."
        super().__init__(message)


def lower_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip().lower()


def unique_preserve_order(items: list[str]) -> list[str]:
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def count_ip_occurrences(ips: list[str]) -> dict[str, int]:
    counts = {}
    for ip in ips:
        counts[ip] = counts.get(ip, 0) + 1
    return counts


def is_valid_ip(value: str) -> bool:
    try:
        ipaddress.ip_address(value)
        return True
    except ValueError:
        return False


def normalize_ip_list(raw_ips: list[Any]) -> list[str]:
    normalized = []
    for item in raw_ips:
        if item is None:
            continue
        value = str(item).strip()
        if value:
            normalized.append(value)
    return normalized


def normalize_header(value: str) -> str:
    return lower_text(value).replace(" ", "_").replace("-", "_").replace(".", "_")


def detect_csv_dialect(csv_text: str) -> csv.Dialect:
    sample = csv_text[:4096]
    try:
        return csv.Sniffer().sniff(sample, delimiters=",;\t")
    except csv.Error:
        class FallbackDialect(csv.excel):
            delimiter = ";" if sample.count(";") >= sample.count(",") else ","

        return FallbackDialect


def parse_csv_ips(csv_text: str) -> list[str]:
    if len(csv_text.encode("utf-8")) > MAX_CSV_BYTES:
        raise PayloadTooLargeError("Le fichier CSV depasse la limite de 1 MB.")

    reader = csv.reader(io.StringIO(csv_text), dialect=detect_csv_dialect(csv_text))
    rows = [[cell.strip().strip('"').strip("'") for cell in row] for row in reader]
    rows = [row for row in rows if any(cell for cell in row)]
    if not rows:
        return []

    header_index = None
    first_row_headers = [normalize_header(cell) for cell in rows[0]]
    for index, header in enumerate(first_row_headers):
        if header in IP_HEADER_NAMES:
            header_index = index
            break

    candidates = []
    if header_index is not None:
        for row in rows[1:]:
            if header_index < len(row):
                candidates.append(row[header_index])
    else:
        for row in rows:
            candidates.extend(row)

    return [candidate for candidate in candidates if candidate and is_valid_ip(candidate)]


def enforce_unique_ip_limit(ips: list[str]) -> None:
    if len(unique_preserve_order(ips)) > MAX_UNIQUE_IPS:
        raise TooManyIpsError(
            f"Maximum {MAX_UNIQUE_IPS} IP uniques par analyse CSV pour cette version."
        )


def first_non_empty(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def classify_ip(result: dict) -> dict:
    network = result.get("network", {})
    flags = result.get("flags", {})

    org = lower_text(network.get("org"))
    isp = lower_text(network.get("isp"))
    reverse_dns = lower_text(network.get("reverse_dns"))
    asn_full = lower_text(network.get("asn_full"))
    asn_name = lower_text(network.get("asn_name"))

    reasons = []
    anonymization_score = 0
    score = 0
    category = "indetermine"
    origin_ip_visible = True
    investigative_value = "moyenne"
    confidence = "moyenne"

    if flags.get("is_proxy_or_vpn_or_tor"):
        anonymization_score += 60
        reasons.append("L'API signale un proxy, VPN ou relais d'anonymisation.")
        origin_ip_visible = False

    if flags.get("is_hosting_or_datacenter"):
        anonymization_score += 40
        reasons.append("L'API signale une IP d'hebergement ou de datacenter.")

    if flags.get("is_mobile"):
        reasons.append("L'API signale une connexion mobile.")

    if "icloud private relay" in org:
        anonymization_score += 80
        reasons.append("Organisation detectee : iCloud Private Relay.")
        origin_ip_visible = False

    if "private relay" in org:
        anonymization_score += 30
        reasons.append("Le nom d'organisation evoque un relais d'anonymisation.")
        origin_ip_visible = False

    if "warp" in org:
        anonymization_score += 40
        reasons.append("L'organisation mentionne WARP, qui correspond a un service de tunnel ou relais Cloudflare.")
        origin_ip_visible = False

    if "akamai" in isp or "akamai" in asn_full or "akamai" in asn_name:
        anonymization_score += 20
        reasons.append("Le reseau passe par Akamai, souvent utilise comme infrastructure de sortie ou CDN.")

    if "cloudflare" in isp or "cloudflare" in org or "cloudflare" in asn_full or "cloudflare" in asn_name:
        anonymization_score += 20
        reasons.append("Le reseau passe par Cloudflare, souvent utilise comme infrastructure de sortie, proxy ou tunnel.")

    if "akamai" in reverse_dns or "akamaitechnologies" in reverse_dns:
        anonymization_score += 20
        reasons.append("Le reverse DNS pointe vers Akamai.")

    if "cloudflare" in reverse_dns:
        anonymization_score += 20
        reasons.append("Le reverse DNS pointe vers Cloudflare.")

    if ".mobile." in reverse_dns:
        reasons.append("Le reverse DNS contient 'mobile', indice supplementaire d'un acces mobile.")

    if any(keyword in isp or keyword in org or keyword in asn_full for keyword in KNOWN_HOSTING_KEYWORDS):
        anonymization_score += 20
        reasons.append("Le fournisseur ressemble a un hebergeur, CDN ou infrastructure technique.")

    if any(keyword in isp or keyword in org for keyword in KNOWN_MOBILE_KEYWORDS):
        reasons.append("Le fournisseur ressemble a un operateur grand public ou mobile.")

    if flags.get("is_mobile"):
        category = "mobile_probable"
        investigative_value = "moyenne"
        confidence = "elevee"
        score = 60
        if origin_ip_visible:
            score += 10
    elif anonymization_score >= 80:
        category = "anonymisation_probable"
        investigative_value = "faible"
        confidence = "elevee"
        score = 10
    elif flags.get("is_hosting_or_datacenter") or anonymization_score >= 40:
        category = "infrastructure_ou_relais_probable"
        investigative_value = "faible"
        confidence = "moyenne"
        if not flags.get("is_proxy_or_vpn_or_tor"):
            origin_ip_visible = False
        score = 20
    else:
        category = "residential_or_isp_probable"
        investigative_value = "elevee"
        confidence = "moyenne"
        score = 85
        if origin_ip_visible:
            score += 10

    if origin_ip_visible:
        score += 5
    if result.get("occurrences", 1) > 1:
        score += min(result.get("occurrences", 1) - 1, 15)

    score = max(0, min(score, 100))

    if not reasons:
        reasons.append("Aucun indicateur fort d'anonymisation ou d'hebergement n'a ete detecte par cette source.")

    return {
        "category": category,
        "score": score,
        "anonymization_score": anonymization_score,
        "reasons": unique_preserve_order(reasons),
        "origin_ip_visible": origin_ip_visible,
        "investigative_value": investigative_value,
        "confidence": confidence,
    }


def build_identity_requirements(result: dict) -> list[str]:
    category = result.get("analysis", {}).get("category")
    origin_ip_visible = result.get("analysis", {}).get("origin_ip_visible")
    network = result.get("network", {})
    flags = result.get("flags", {})

    requirements = [
        "L'identite civile de l'utilisateur n'est pas deductible a partir de cette IP seule.",
        "Pour identifier une personne, il faut en general obtenir les journaux de connexion du fournisseur reseau concerne avec la date, l'heure, le fuseau horaire et l'IP exacts.",
        "Il faut aussi idealement le port source, surtout en IPv4 avec CGNAT, car plusieurs abonnes peuvent partager la meme IP publique.",
    ]

    if flags.get("is_mobile") or category == "mobile_probable":
        requirements.append("Si l'acces est mobile, il faut les journaux de l'operateur mobile a l'instant precis pour remonter a la ligne ou a l'abonnement utilise.")

    if category in {"anonymisation_probable", "infrastructure_ou_relais_probable"}:
        requirements.append("Cette IP semble passer par une infrastructure intermediaire ou un relais. Il faut alors d'abord les journaux de ce service intermediaire pour esperer remonter vers l'IP d'origine.")

    if "icloud private relay" in lower_text(network.get("org")):
        requirements.append("Dans le cas d'iCloud Private Relay, l'IP visible est une IP de sortie Apple/Akamai. L'IP d'origine n'est pas recuperable depuis cette IP seule.")

    if "warp" in lower_text(network.get("org")):
        requirements.append("Dans le cas de Cloudflare WARP, l'IP visible correspond a un noeud de sortie du service. L'IP d'origine n'est pas visible directement.")

    if origin_ip_visible is True:
        requirements.append("Cette IP semble plus proche d'une IP d'acces que d'une simple IP de sortie, mais elle ne suffit toujours pas seule a nommer un utilisateur sans journaux operateur.")
    else:
        requirements.append("L'IP d'origine ne semble pas visible directement depuis cette seule adresse IP.")

    requirements.append("La localisation affichee par l'API est approximative et ne permet pas d'identifier un domicile ou une personne avec fiabilite.")
    return unique_preserve_order(requirements)


def enrich_analysis(result: dict) -> dict:
    if not result.get("ok"):
        return result

    result["analysis"] = classify_ip(result)
    result["identity_requirements"] = build_identity_requirements(result)
    return result


def get_requisition_target(result: dict) -> str:
    network = result.get("network", {})
    flags = result.get("flags", {})

    org = lower_text(network.get("org"))
    isp = network.get("isp") or ""

    if "icloud private relay" in org:
        return "Apple / Akamai"
    if "warp" in org:
        return "Cloudflare"
    if flags.get("is_mobile"):
        return isp or "Operateur mobile"
    if isp:
        return isp
    return "Fournisseur reseau a determiner"


def build_global_summary(results: list[dict]) -> dict:
    summary = {
        "total": len(results),
        "ok": 0,
        "errors": 0,
        "categories": {},
        "investigative_values": {},
        "origin_ip_visible": {"true": 0, "false": 0},
        "priority_ips": [],
    }

    valid_results = []
    for result in results:
        if result.get("ok"):
            summary["ok"] += 1
            analysis = result.get("analysis", {})
            category = analysis.get("category", "inconnue")
            value = analysis.get("investigative_value", "inconnue")
            origin_ip_visible = analysis.get("origin_ip_visible")

            summary["categories"][category] = summary["categories"].get(category, 0) + 1
            summary["investigative_values"][value] = summary["investigative_values"].get(value, 0) + 1
            summary["origin_ip_visible"]["true" if origin_ip_visible is True else "false"] += 1
            valid_results.append(result)
        else:
            summary["errors"] += 1

    valid_results.sort(
        key=lambda item: (
            0 if item.get("analysis", {}).get("investigative_value") == "elevee" else 1 if item.get("analysis", {}).get("investigative_value") == "moyenne" else 2,
            item.get("analysis", {}).get("origin_ip_visible") is not True,
            -item.get("analysis", {}).get("score", 0),
            -item.get("occurrences", 1),
        )
    )

    already_seen_ips = set()
    for item in valid_results:
        ip = item.get("ip")
        if not ip or ip in already_seen_ips:
            continue
        already_seen_ips.add(ip)
        if item.get("analysis", {}).get("investigative_value") == "faible":
            continue
        summary["priority_ips"].append(
            {
                "ip": ip,
                "category": item.get("analysis", {}).get("category"),
                "score": item.get("analysis", {}).get("score"),
                "investigative_value": item.get("analysis", {}).get("investigative_value"),
                "requisition_target": get_requisition_target(item),
                "occurrences": item.get("occurrences", 1),
            }
        )

    return summary


def map_primary_ip_api_data(data: dict, input_ip: str) -> dict:
    if data.get("status") != "success":
        return {
            "ok": False,
            "error": data.get("message", "Erreur inconnue"),
            "input": input_ip,
            "raw": data,
        }

    return {
        "ok": True,
        "input": input_ip,
        "ip": data.get("query") or input_ip,
        "location": {
            "continent": data.get("continent"),
            "continent_code": data.get("continentCode"),
            "country": data.get("country"),
            "country_code": data.get("countryCode"),
            "region": data.get("region"),
            "region_name": data.get("regionName"),
            "city": data.get("city"),
            "district": data.get("district"),
            "zip": data.get("zip"),
            "lat": data.get("lat"),
            "lon": data.get("lon"),
            "timezone": data.get("timezone"),
            "utc_offset_seconds": data.get("offset"),
            "currency": data.get("currency"),
        },
        "network": {
            "isp": data.get("isp"),
            "org": data.get("org"),
            "asn_full": data.get("as"),
            "asn_name": data.get("asname"),
            "reverse_dns": data.get("reverse"),
        },
        "flags": {
            "is_mobile": data.get("mobile"),
            "is_proxy_or_vpn_or_tor": data.get("proxy"),
            "is_hosting_or_datacenter": data.get("hosting"),
        },
        "country_details": {},
        "raw": data,
    }


def lookup_ip_ipapi(ip: str) -> dict:
    url = f"https://ipapi.co/{urllib.parse.quote(ip)}/json/"

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 IP-Lookup-Script/1.0"},
        )

        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read().decode("utf-8")
            data = json.loads(raw)

        if not isinstance(data, dict):
            return {
                "ok": False,
                "error": "Unexpected response format from ipapi.co",
                "input": ip,
            }

        if data.get("error"):
            return {
                "ok": False,
                "error": str(data.get("reason") or data.get("error")),
                "input": ip,
                "raw": data,
            }

        return {
            "ok": True,
            "input": ip,
            "raw": data,
            "provider": "ipapi.co",
            "location": {
                "continent_code": data.get("continent_code"),
                "country": data.get("country_name"),
                "country_code": data.get("country_code"),
                "region_name": data.get("region"),
                "region_code": data.get("region_code"),
                "city": data.get("city"),
                "postal": data.get("postal"),
                "lat": data.get("latitude"),
                "lon": data.get("longitude"),
                "timezone": data.get("timezone"),
                "utc_offset": data.get("utc_offset"),
                "currency": data.get("currency"),
                "currency_name": data.get("currency_name"),
            },
            "network": {
                "network": data.get("network"),
                "version": data.get("version"),
                "asn": data.get("asn"),
                "org": data.get("org"),
            },
            "country_details": {
                "country_name": data.get("country_name"),
                "country_code": data.get("country_code"),
                "country_code_iso3": data.get("country_code_iso3"),
                "country_capital": data.get("country_capital"),
                "country_tld": data.get("country_tld"),
                "country_calling_code": data.get("country_calling_code"),
                "country_area": data.get("country_area"),
                "country_population": data.get("country_population"),
                "in_eu": data.get("in_eu"),
                "languages": data.get("languages"),
            },
        }

    except HTTPError as e:
        return {"ok": False, "error": f"HTTP error {e.code}", "input": ip}
    except URLError as e:
        return {"ok": False, "error": f"Network error: {e.reason}", "input": ip}
    except Exception as e:
        return {"ok": False, "error": str(e), "input": ip}


def merge_provider_data(primary_result: dict, secondary_result: dict) -> dict:
    merged = dict(primary_result)

    primary_location = dict(primary_result.get("location", {}))
    primary_network = dict(primary_result.get("network", {}))
    primary_flags = dict(primary_result.get("flags", {}))

    secondary_location = dict(secondary_result.get("location", {}))
    secondary_network = dict(secondary_result.get("network", {}))
    secondary_country_details = dict(secondary_result.get("country_details", {}))

    merged["location"] = {
        "continent": first_non_empty(primary_location.get("continent")),
        "continent_code": first_non_empty(primary_location.get("continent_code"), secondary_location.get("continent_code")),
        "country": first_non_empty(primary_location.get("country"), secondary_location.get("country")),
        "country_code": first_non_empty(primary_location.get("country_code"), secondary_location.get("country_code")),
        "region": first_non_empty(primary_location.get("region"), secondary_location.get("region_code")),
        "region_name": first_non_empty(primary_location.get("region_name"), secondary_location.get("region_name")),
        "city": first_non_empty(primary_location.get("city"), secondary_location.get("city")),
        "district": first_non_empty(primary_location.get("district")),
        "zip": first_non_empty(primary_location.get("zip"), secondary_location.get("postal")),
        "lat": first_non_empty(primary_location.get("lat"), secondary_location.get("lat")),
        "lon": first_non_empty(primary_location.get("lon"), secondary_location.get("lon")),
        "timezone": first_non_empty(primary_location.get("timezone"), secondary_location.get("timezone")),
        "utc_offset_seconds": first_non_empty(primary_location.get("utc_offset_seconds")),
        "utc_offset": first_non_empty(secondary_location.get("utc_offset")),
        "currency": first_non_empty(primary_location.get("currency"), secondary_location.get("currency")),
        "currency_name": first_non_empty(secondary_location.get("currency_name")),
    }

    merged["network"] = {
        "isp": first_non_empty(primary_network.get("isp")),
        "org": first_non_empty(primary_network.get("org"), secondary_network.get("org")),
        "asn_full": first_non_empty(primary_network.get("asn_full")),
        "asn_name": first_non_empty(primary_network.get("asn_name")),
        "reverse_dns": first_non_empty(primary_network.get("reverse_dns")),
        "network": first_non_empty(secondary_network.get("network")),
        "version": first_non_empty(secondary_network.get("version")),
        "asn": first_non_empty(secondary_network.get("asn")),
    }

    merged["flags"] = primary_flags
    merged["country_details"] = secondary_country_details
    merged["providers"] = {
        "primary": {"name": "ip-api.com", "ok": primary_result.get("ok", False), "raw": primary_result.get("raw")},
        "secondary": {
            "name": "ipapi.co",
            "ok": secondary_result.get("ok", False),
            "raw": secondary_result.get("raw"),
            "error": secondary_result.get("error"),
        },
    }

    return merged


def fallback_from_secondary(ip: str, primary_result: dict, secondary_result: dict) -> dict:
    return {
        "ok": True,
        "input": ip,
        "ip": ip,
        "location": {
            "continent": None,
            "continent_code": secondary_result.get("location", {}).get("continent_code"),
            "country": secondary_result.get("location", {}).get("country"),
            "country_code": secondary_result.get("location", {}).get("country_code"),
            "region": secondary_result.get("location", {}).get("region_code"),
            "region_name": secondary_result.get("location", {}).get("region_name"),
            "city": secondary_result.get("location", {}).get("city"),
            "district": None,
            "zip": secondary_result.get("location", {}).get("postal"),
            "lat": secondary_result.get("location", {}).get("lat"),
            "lon": secondary_result.get("location", {}).get("lon"),
            "timezone": secondary_result.get("location", {}).get("timezone"),
            "utc_offset_seconds": None,
            "utc_offset": secondary_result.get("location", {}).get("utc_offset"),
            "currency": secondary_result.get("location", {}).get("currency"),
            "currency_name": secondary_result.get("location", {}).get("currency_name"),
        },
        "network": {
            "isp": None,
            "org": secondary_result.get("network", {}).get("org"),
            "asn_full": secondary_result.get("network", {}).get("asn"),
            "asn_name": None,
            "reverse_dns": None,
            "network": secondary_result.get("network", {}).get("network"),
            "version": secondary_result.get("network", {}).get("version"),
            "asn": secondary_result.get("network", {}).get("asn"),
        },
        "flags": {
            "is_mobile": False,
            "is_proxy_or_vpn_or_tor": False,
            "is_hosting_or_datacenter": False,
        },
        "country_details": secondary_result.get("country_details", {}),
        "raw": None,
        "providers": {
            "primary": {
                "name": "ip-api.com",
                "ok": False,
                "error": primary_result.get("error"),
                "raw": primary_result.get("raw"),
            },
            "secondary": {"name": "ipapi.co", "ok": True, "raw": secondary_result.get("raw")},
        },
    }


def combined_lookup_result(ip: str, primary_result: dict, include_secondary: bool = True) -> dict:
    if include_secondary:
        secondary_result = lookup_ip_ipapi(ip)
    else:
        secondary_result = {"ok": False}

    if primary_result.get("ok") and secondary_result.get("ok"):
        return merge_provider_data(primary_result, secondary_result)
    if primary_result.get("ok"):
        primary_result["providers"] = {
            "primary": {"name": "ip-api.com", "ok": True, "raw": primary_result.get("raw")},
            "secondary": {"name": "ipapi.co", "ok": False, "error": secondary_result.get("error")},
        }
        return primary_result
    if secondary_result.get("ok"):
        return fallback_from_secondary(ip, primary_result, secondary_result)

    return {
        "ok": False,
        "error": primary_result.get("error") or secondary_result.get("error") or "Erreur inconnue",
        "input": ip,
        "providers": {
            "primary": {
                "name": "ip-api.com",
                "ok": primary_result.get("ok", False),
                "error": primary_result.get("error"),
                "raw": primary_result.get("raw"),
            },
            "secondary": {
                "name": "ipapi.co",
                "ok": secondary_result.get("ok", False),
                "error": secondary_result.get("error"),
                "raw": secondary_result.get("raw"),
            },
        },
    }


def lookup_ip(ip: str) -> dict:
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        return {"ok": False, "error": "IP invalide", "input": ip}

    url = (
        f"http://ip-api.com/json/{urllib.parse.quote(ip)}"
        f"?fields={','.join(IP_API_FIELDS)}&lang=fr"
    )

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 IP-Lookup-Script/1.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read().decode("utf-8")
            data = json.loads(raw)
            raise_if_ip_api_rate_limited(response.headers)

        primary_result = map_primary_ip_api_data(data, ip)
    except HTTPError as e:
        primary_result = {"ok": False, "error": f"HTTP error {e.code}", "input": ip}
    except URLError as e:
        primary_result = {"ok": False, "error": f"Network error: {e.reason}", "input": ip}
    except Exception as e:
        primary_result = {"ok": False, "error": str(e), "input": ip}

    return combined_lookup_result(ip, primary_result, include_secondary=True)


def raise_if_ip_api_rate_limited(headers: Any) -> None:
    remaining = headers.get("X-Rl") if headers else None
    ttl = headers.get("X-Ttl") if headers else None
    if remaining == "0":
        try:
            ttl_value = int(ttl) if ttl is not None else None
        except ValueError:
            ttl_value = None
        raise UpstreamRateLimitError(ttl_value)


def lookup_ip_batch(ips: list[str]) -> list[dict]:
    enforce_unique_ip_limit(ips)
    unique_ips = unique_preserve_order(ips)
    if not unique_ips:
        return []

    url = f"http://ip-api.com/batch?fields={','.join(IP_API_FIELDS)}&lang=fr"
    body = json.dumps(unique_ips).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 IP-Lookup-Script/1.0",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read().decode("utf-8")
            data = json.loads(raw)
            raise_if_ip_api_rate_limited(response.headers)
    except HTTPError as e:
        if e.code == 429:
            raise UpstreamRateLimitError()
        raise

    if not isinstance(data, list):
        raise RuntimeError("Unexpected response format from ip-api.com batch endpoint.")

    results = []
    for ip, item in zip(unique_ips, data):
        if isinstance(item, dict):
            primary_result = map_primary_ip_api_data(item, ip)
        else:
            primary_result = {"ok": False, "error": "Unexpected batch item format", "input": ip}
        results.append(combined_lookup_result(ip, primary_result, include_secondary=False))

    return results


def analyze_single_ip(ip: str, occurrences: int = 1) -> dict:
    result = lookup_ip(ip)
    if result.get("ok"):
        result["occurrences"] = max(1, occurrences)
    return enrich_analysis(result)


def analyze_ip_list(ips: list[str], use_batch: bool = True) -> dict:
    normalized_ips = normalize_ip_list(ips)
    enforce_unique_ip_limit(normalized_ips)
    ip_occurrences = count_ip_occurrences(normalized_ips)
    unique_ips = unique_preserve_order(normalized_ips)

    if use_batch:
        results = lookup_ip_batch(normalized_ips)
        for result in results:
            ip = result.get("ip") or result.get("input")
            if result.get("ok"):
                result["occurrences"] = max(1, ip_occurrences.get(ip, 1))
        results = [enrich_analysis(result) for result in results]
    else:
        results = [analyze_single_ip(ip, ip_occurrences.get(ip, 1)) for ip in unique_ips]

    return {
        "ok": True,
        "input_count": len(normalized_ips),
        "unique_count": len(unique_ips),
        "results": results,
        "summary": build_global_summary(results),
    }


def build_api_response_for_single_ip(ip: str) -> dict:
    result = analyze_single_ip(ip)
    return {"ok": result.get("ok", False), "result": result}


def build_api_response_for_multiple_ips(ips: list[str], csv_text: str | None = None) -> dict:
    all_ips = []
    all_ips.extend(normalize_ip_list(ips))
    if csv_text is not None:
        all_ips.extend(parse_csv_ips(csv_text))

    if not all_ips:
        return {
            "ok": False,
            "error": "Provide 'ips' as a list and/or 'csv' as text with at least one valid IP.",
        }

    return analyze_ip_list(all_ips, use_batch=True)

import ipaddress
import json
import sys
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.error import HTTPError, URLError


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
        reasons.append("L'API signale une IP d'hébergement ou de datacenter.")

    if flags.get("is_mobile"):
        reasons.append("L'API signale une connexion mobile.")

    if "icloud private relay" in org:
        anonymization_score += 80
        reasons.append("Organisation détectée : iCloud Private Relay.")
        origin_ip_visible = False

    if "private relay" in org:
        anonymization_score += 30
        reasons.append("Le nom d'organisation évoque un relais d'anonymisation.")
        origin_ip_visible = False

    if "warp" in org:
        anonymization_score += 40
        reasons.append("L'organisation mentionne WARP, qui correspond à un service de tunnel/relais Cloudflare.")
        origin_ip_visible = False

    if "akamai" in isp or "akamai" in asn_full or "akamai" in asn_name:
        anonymization_score += 20
        reasons.append("Le réseau passe par Akamai, souvent utilisé comme infrastructure de sortie ou CDN.")

    if "cloudflare" in isp or "cloudflare" in org or "cloudflare" in asn_full or "cloudflare" in asn_name:
        anonymization_score += 20
        reasons.append("Le réseau passe par Cloudflare, souvent utilisé comme infrastructure de sortie, proxy ou tunnel.")

    if "akamai" in reverse_dns or "akamaitechnologies" in reverse_dns:
        anonymization_score += 20
        reasons.append("Le reverse DNS pointe vers Akamai.")

    if "cloudflare" in reverse_dns:
        anonymization_score += 20
        reasons.append("Le reverse DNS pointe vers Cloudflare.")

    if ".mobile." in reverse_dns:
        reasons.append("Le reverse DNS contient 'mobile', indice supplémentaire d'un accès mobile.")

    if any(keyword in isp or keyword in org or keyword in asn_full for keyword in KNOWN_HOSTING_KEYWORDS):
        anonymization_score += 20
        reasons.append("Le fournisseur ressemble à un hébergeur, CDN ou infrastructure technique.")

    if any(keyword in isp or keyword in org for keyword in KNOWN_MOBILE_KEYWORDS):
        reasons.append("Le fournisseur ressemble à un opérateur grand public ou mobile.")

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
        reasons.append("Aucun indicateur fort d'anonymisation ou d'hébergement n'a été détecté par cette source.")

    reasons = unique_preserve_order(reasons)

    return {
        "category": category,
        "score": score,
        "anonymization_score": anonymization_score,
        "reasons": reasons,
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
        "L'identité civile de l'utilisateur n'est pas déductible à partir de cette IP seule.",
        "Pour identifier une personne, il faut en général obtenir les journaux de connexion du fournisseur réseau concerné avec la date, l'heure, le fuseau horaire et l'IP exacts.",
        "Il faut aussi idéalement le port source, surtout en IPv4 avec CGNAT, car plusieurs abonnés peuvent partager la même IP publique.",
    ]

    if flags.get("is_mobile") or category == "mobile_probable":
        requirements.append("Si l'accès est mobile, il faut les journaux de l'opérateur mobile à l'instant précis pour remonter à la ligne ou à l'abonnement utilisé.")

    if category in {"anonymisation_probable", "infrastructure_ou_relais_probable"}:
        requirements.append("Cette IP semble passer par une infrastructure intermédiaire ou un relais. Il faut alors d'abord les journaux de ce service intermédiaire pour espérer remonter vers l'IP d'origine.")

    if "icloud private relay" in lower_text(network.get("org")):
        requirements.append("Dans le cas d'iCloud Private Relay, l'IP visible est une IP de sortie Apple/Akamai. L'IP d'origine n'est pas récupérable depuis cette IP seule ; il faudrait des journaux du service de relais et du fournisseur d'accès initial, dans un cadre légal approprié.")

    if "warp" in lower_text(network.get("org")):
        requirements.append("Dans le cas de Cloudflare WARP, l'IP visible correspond à un nœud de sortie du service. L'IP d'origine n'est pas visible directement ; il faudrait les journaux du service intermédiaire puis ceux du fournisseur d'accès initial, dans un cadre légal approprié.")

    if origin_ip_visible is True:
        requirements.append("Cette IP semble plus proche d'une IP d'accès que d'une simple IP de sortie, mais elle ne suffit toujours pas seule à nommer un utilisateur sans journaux opérateur.")
    else:
        requirements.append("L'IP d'origine ne semble pas visible directement depuis cette seule adresse IP.")

    requirements.append("La localisation affichée par l'API est approximative et ne permet pas d'identifier un domicile ou une personne avec fiabilité.")
    return unique_preserve_order(requirements)


def enrich_analysis(result: dict) -> dict:
    if not result.get("ok"):
        return result

    analysis = classify_ip(result)
    result["analysis"] = analysis
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
        return isp or "Opérateur mobile"
    if isp:
        return isp
    return "Fournisseur réseau à déterminer"


def normalize_ip_list(raw_ips: list[Any]) -> list[str]:
    normalized = []
    for item in raw_ips:
        if item is None:
            continue
        value = str(item).strip()
        if value:
            normalized.append(value)
    return normalized


def parse_csv_ips(csv_text: str) -> list[str]:
    ips = []
    separators = [",", ";", "\t"]

    for raw_line in csv_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        lowered = lower_text(line)
        if lowered in {"ip", "ips", "adresse_ip", "ip_address", "address"}:
            continue

        current_parts = [line]
        for separator in separators:
            expanded_parts = []
            for part in current_parts:
                expanded_parts.extend(part.split(separator))
            current_parts = expanded_parts

        for part in current_parts:
            candidate = part.strip().strip('"').strip("'")
            if candidate:
                ips.append(candidate)

    return ips


def parse_ips_from_args() -> list[str]:
    if len(sys.argv) <= 1:
        return []
    filtered = [arg for arg in sys.argv[1:] if arg != "--serve"]
    if filtered and (filtered[0].isdigit() or ":" in filtered[0]):
        filtered = filtered[1:]
    return [arg.strip() for arg in filtered if arg.strip()]


def build_global_summary(results: list[dict]) -> dict:
    summary = {
        "total": len(results),
        "ok": 0,
        "errors": 0,
        "categories": {},
        "investigative_values": {},
        "origin_ip_visible": {
            "true": 0,
            "false": 0,
        },
        "priority_ips": [],
    }

    valid_results = []

    for result in results:
        if result.get("ok"):
            summary["ok"] += 1
            analysis = result.get("analysis", {})
            category = analysis.get("category", "inconnue")
            investigative_value = analysis.get("investigative_value", "inconnue")
            origin_ip_visible = analysis.get("origin_ip_visible")

            summary["categories"][category] = summary["categories"].get(category, 0) + 1
            summary["investigative_values"][investigative_value] = summary["investigative_values"].get(investigative_value, 0) + 1

            if origin_ip_visible is True:
                summary["origin_ip_visible"]["true"] += 1
            else:
                summary["origin_ip_visible"]["false"] += 1

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


def analyze_single_ip(ip: str, occurrences: int = 1) -> dict:
    result = lookup_ip(ip)
    if result.get("ok"):
        result["occurrences"] = max(1, occurrences)
    return enrich_analysis(result)


def analyze_ip_list(ips: list[str]) -> dict:
    normalized_ips = normalize_ip_list(ips)
    ip_occurrences = count_ip_occurrences(normalized_ips)
    unique_ips = unique_preserve_order(normalized_ips)

    results = []
    for ip in unique_ips:
        results.append(analyze_single_ip(ip, ip_occurrences.get(ip, 1)))

    return {
        "ok": True,
        "input_count": len(normalized_ips),
        "unique_count": len(unique_ips),
        "results": results,
        "summary": build_global_summary(results),
    }


def build_api_response_for_single_ip(ip: str) -> dict:
    result = analyze_single_ip(ip)
    return {
        "ok": result.get("ok", False),
        "result": result,
    }


def build_api_response_for_multiple_ips(ips: list[str]) -> dict:
    return analyze_ip_list(ips)


def print_human_summary(result: dict) -> None:
    if not result.get("ok"):
        return

    analysis = result["analysis"]
    print("\nRésumé humain :")
    print(f"- Catégorie : {analysis['category']}")
    print(f"- Score : {analysis['score']}")
    print(f"- Score d'anonymisation : {analysis['anonymization_score']}")
    print(f"- Confiance : {analysis['confidence']}")
    print(f"- Valeur investigative : {analysis['investigative_value']}")
    print(f"- IP d'origine visible directement : {'oui' if analysis['origin_ip_visible'] else 'non'}")
    network = result.get("network", {})
    providers = result.get("providers", {})
    if network.get("network"):
        print(f"- Réseau CIDR enrichi : {network['network']}")
    if network.get("version"):
        print(f"- Version IP : {network['version']}")
    if network.get("asn"):
        print(f"- ASN enrichi : {network['asn']}")
    if result.get("country_details", {}).get("languages"):
        print(f"- Langues pays : {result['country_details']['languages']}")
    if providers:
        print(
            f"- Providers : primaire={providers.get('primary', {}).get('name')} (ok={providers.get('primary', {}).get('ok')}) | secondaire={providers.get('secondary', {}).get('name')} (ok={providers.get('secondary', {}).get('ok')})"
        )
    print("- Raisons :")
    for reason in analysis["reasons"]:
        print(f"  • {reason}")
    print("- Ce qu'il faudrait pour tenter d'identifier l'utilisateur ou retrouver l'IP d'origine :")
    for item in result["identity_requirements"]:
        print(f"  • {item}")
    


def print_global_summary(results: list[dict]) -> None:
    summary = build_global_summary(results)
    print("\n" + "#" * 80)
    print("RÉSUMÉ GLOBAL DU LOT")
    print("#" * 80)
    print(f"- Total analysé : {summary['total']}")
    print(f"- Analyses réussies : {summary['ok']}")
    print(f"- Erreurs : {summary['errors']}")
    print("- Répartition par catégorie :")
    for category, count in summary["categories"].items():
        print(f"  • {category}: {count}")
    print("- Répartition par valeur investigative :")
    for value, count in summary["investigative_values"].items():
        print(f"  • {value}: {count}")
    print("- IP d'origine visible directement :")
    print(f"  • oui: {summary['origin_ip_visible']['true']}")
    print(f"  • non: {summary['origin_ip_visible']['false']}")
    if summary["priority_ips"]:
        print("- IP à prioriser pour les investigations :")
        for item in summary["priority_ips"]:
            print(
                f"  • {item['ip']} | catégorie={item['category']} | score={item['score']} | valeur_investigative={item['investigative_value']} | occurrences={item['occurrences']} | Requisition a : {item['requisition_target']}"
            )
    else:
        print("- IP à prioriser pour les investigations : aucune IP avec valeur investigative moyenne ou élevée.")


def read_json_body(handler: BaseHTTPRequestHandler) -> dict:
    content_length = int(handler.headers.get("Content-Length", "0"))
    if content_length <= 0:
        return {}

    raw_body = handler.rfile.read(content_length).decode("utf-8")
    if not raw_body.strip():
        return {}

    data = json.loads(raw_body)
    if not isinstance(data, dict):
        raise ValueError("JSON body must be an object.")
    return data


def send_json(handler: BaseHTTPRequestHandler, status_code: int, payload: dict) -> None:
    body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    handler.send_response(status_code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.end_headers()
    handler.wfile.write(body)


def handle_analyze_ip_request(payload: dict) -> tuple[int, dict]:
    ip = str(payload.get("ip", "")).strip()
    if not ip:
        return 400, {
            "ok": False,
            "error": "Field 'ip' is required.",
        }

    return 200, build_api_response_for_single_ip(ip)


def handle_analyze_ips_request(payload: dict) -> tuple[int, dict]:
    ips = []

    if isinstance(payload.get("ips"), list):
        ips.extend(normalize_ip_list(payload.get("ips", [])))

    if payload.get("csv") is not None:
        ips.extend(parse_csv_ips(str(payload.get("csv", ""))))

    if not ips:
        return 400, {
            "ok": False,
            "error": "Provide 'ips' as a list and/or 'csv' as text.",
        }

    return 200, build_api_response_for_multiple_ips(ips)


class IpAnalysisApiHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self) -> None:
        send_json(self, 200, {"ok": True})

    def do_GET(self) -> None:
        if self.path == "/health":
            send_json(
                self,
                200,
                {
                    "ok": True,
                    "service": "ip-analysis-api",
                    "endpoints": ["POST /analyze-ip", "POST /analyze-ips", "GET /health"],
                },
            )
            return

        send_json(
            self,
            404,
            {
                "ok": False,
                "error": "Route not found.",
            },
        )

    def do_POST(self) -> None:
        try:
            payload = read_json_body(self)
        except json.JSONDecodeError:
            send_json(
                self,
                400,
                {
                    "ok": False,
                    "error": "Invalid JSON body.",
                },
            )
            return
        except ValueError as e:
            send_json(
                self,
                400,
                {
                    "ok": False,
                    "error": str(e),
                },
            )
            return

        if self.path == "/analyze-ip":
            status_code, response_payload = handle_analyze_ip_request(payload)
            send_json(self, status_code, response_payload)
            return

        if self.path == "/analyze-ips":
            status_code, response_payload = handle_analyze_ips_request(payload)
            send_json(self, status_code, response_payload)
            return

        send_json(
            self,
            404,
            {
                "ok": False,
                "error": "Route not found.",
            },
        )

    def log_message(self, format: str, *args: Any) -> None:
        return


def run_api_server(host: str = "0.0.0.0", port: int = 8000) -> None:
    server = ThreadingHTTPServer((host, port), IpAnalysisApiHandler)
    print(f"API IP analysis disponible sur http://{host}:{port}")
    print("Routes disponibles : POST /analyze-ip | POST /analyze-ips | GET /health")
    server.serve_forever()

def lookup_ip_ipapi(ip: str) -> dict:
    url = f"https://ipapi.co/{urllib.parse.quote(ip)}/json/"

    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 IP-Lookup-Script/1.0"
            },
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
        return {
            "ok": False,
            "error": f"HTTP error {e.code}",
            "input": ip,
        }
    except URLError as e:
        return {
            "ok": False,
            "error": f"Network error: {e.reason}",
            "input": ip,
        }
    except Exception as e:
        return {
            "ok": False,
            "error": str(e),
            "input": ip,
        }


def first_non_empty(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


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
        "primary": {
            "name": "ip-api.com",
            "ok": primary_result.get("ok", False),
            "raw": primary_result.get("raw"),
        },
        "secondary": {
            "name": "ipapi.co",
            "ok": secondary_result.get("ok", False),
            "raw": secondary_result.get("raw"),
            "error": secondary_result.get("error"),
        },
    }

    return merged


def lookup_ip(ip: str) -> dict:
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        return {
            "ok": False,
            "error": "IP invalide",
            "input": ip,
        }

    fields = [
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

    url = (
        f"http://ip-api.com/json/"
        f"{urllib.parse.quote(ip)}"
        f"?fields={','.join(fields)}&lang=fr"
    )

    primary_result = None

    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 IP-Lookup-Script/1.0"
            },
        )

        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read().decode("utf-8")
            data = json.loads(raw)

        if data.get("status") != "success":
            primary_result = {
                "ok": False,
                "error": data.get("message", "Erreur inconnue"),
                "input": ip,
                "raw": data,
            }
        else:
            primary_result = {
                "ok": True,
                "input": ip,
                "ip": data.get("query"),
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
                "raw": data,
            }

    except HTTPError as e:
        primary_result = {
            "ok": False,
            "error": f"HTTP error {e.code}",
            "input": ip,
        }
    except URLError as e:
        primary_result = {
            "ok": False,
            "error": f"Network error: {e.reason}",
            "input": ip,
        }
    except Exception as e:
        primary_result = {
            "ok": False,
            "error": str(e),
            "input": ip,
        }

    secondary_result = lookup_ip_ipapi(ip)

    if primary_result.get("ok"):
        return merge_provider_data(primary_result, secondary_result)

    if secondary_result.get("ok"):
        fallback_result = {
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
                "secondary": {
                    "name": "ipapi.co",
                    "ok": True,
                    "raw": secondary_result.get("raw"),
                },
            },
        }
        return fallback_result

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


if __name__ == "__main__":
    if "--serve" in sys.argv:
        port = 8000
        host = "0.0.0.0"

        filtered_args = [arg for arg in sys.argv[1:] if arg != "--serve"]
        if filtered_args:
            first_arg = filtered_args[0]
            if ":" in first_arg:
                host_part, port_part = first_arg.split(":", 1)
                if host_part.strip():
                    host = host_part.strip()
                if port_part.strip():
                    port = int(port_part.strip())
            else:
                port = int(first_arg)

        run_api_server(host=host, port=port)
    else:
        default_tests = [
            "2a02:26f7:c9c4:654c::9",
            "172.225.158.176",
            "104.28.34.40",
            "92.184.110.227",
            "2a01:cb1a:78:26b6:ac7d:b33e:7fc:4ce2",
        ]

        tests = parse_ips_from_args() or default_tests
        ip_occurrences = count_ip_occurrences(tests)
        unique_tests = unique_preserve_order(tests)
        all_results = []

        for ip in unique_tests:
            result = lookup_ip(ip)
            if result.get("ok"):
                result["occurrences"] = ip_occurrences.get(ip, 1)
            result = enrich_analysis(result)
            all_results.append(result)
            print("=" * 80)
            print(json.dumps(result, indent=2, ensure_ascii=False))
            print_human_summary(result)
            if result.get("ok"):
                print(f"- Nombre d'occurrences dans la liste fournie : {result['occurrences']}")

        print_global_summary(all_results)
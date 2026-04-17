from __future__ import annotations

import csv
import datetime as dt
import ipaddress
import io
import json
import re
import socket
import ssl
import urllib.parse
import urllib.request
from collections import Counter
from typing import Any
from urllib.error import HTTPError, URLError

from ip_analysis import (
    MAX_CSV_BYTES,
    PayloadTooLargeError,
    analyze_ip_list,
    detect_csv_dialect,
    first_non_empty,
    lower_text,
    unique_preserve_order,
)


MAX_UNIQUE_DOMAINS = 50
MAX_CT_SUBDOMAINS = 100
DNS_RECORD_TYPES = ["A", "AAAA", "CNAME", "NS", "MX", "TXT", "SOA", "CAA", "DS", "DNSKEY"]
DOMAIN_HEADER_NAMES = {
    "domain",
    "domains",
    "domaine",
    "domaines",
    "nom_de_domaine",
    "nomdedomaine",
    "host",
    "hostname",
    "fqdn",
    "url",
}
RDAP_BOOTSTRAP_URL = "https://data.iana.org/rdap/dns.json"
COMMON_COMPOUND_SUFFIXES = {
    "ac.uk",
    "co.uk",
    "gov.uk",
    "org.uk",
    "com.au",
    "net.au",
    "org.au",
    "com.br",
    "com.cn",
    "com.mx",
    "co.jp",
    "co.kr",
    "co.nz",
    "co.za",
}
COMMON_GTLD_HINTS = {
    "com",
    "net",
    "org",
    "info",
    "biz",
    "name",
    "pro",
    "app",
    "dev",
    "io",
    "ai",
    "xyz",
    "online",
    "site",
    "shop",
    "store",
    "tech",
    "cloud",
}
CDN_PROXY_KEYWORDS = {
    "akamai": "Akamai",
    "cloudflare": "Cloudflare",
    "fastly": "Fastly",
    "cloudfront": "Amazon CloudFront",
    "incapsula": "Imperva Incapsula",
    "imperva": "Imperva",
    "sucuri": "Sucuri",
    "edgecast": "Edgecast",
    "cdn77": "CDN77",
}
HOSTING_PROVIDER_KEYWORDS = {
    "amazon": "Amazon AWS",
    "aws": "Amazon AWS",
    "google cloud": "Google Cloud",
    "google llc": "Google",
    "microsoft": "Microsoft Azure",
    "azure": "Microsoft Azure",
    "ovh": "OVHcloud",
    "hetzner": "Hetzner",
    "scaleway": "Scaleway",
    "online sas": "Scaleway",
    "digitalocean": "DigitalOcean",
    "linode": "Akamai Linode",
    "akamai": "Akamai",
    "cloudflare": "Cloudflare",
    "fastly": "Fastly",
    "gandi": "Gandi",
    "ionos": "IONOS",
    "godaddy": "GoDaddy",
}
REDACTION_KEYWORDS = {
    "redacted",
    "privacy",
    "private",
    "withheld",
    "masked",
    "not disclosed",
    "gdpr",
    "data protected",
    "whoisguard",
    "proxy",
}
_RDAP_BOOTSTRAP_CACHE: dict[str, Any] | None = None


class TooManyDomainsError(ValueError):
    pass


def normalize_header(value: str) -> str:
    return lower_text(value).replace(" ", "_").replace("-", "_").replace(".", "_")


def idna_encode(value: str) -> str:
    try:
        import idna

        return idna.encode(value, uts46=True).decode("ascii")
    except Exception:
        return value.encode("idna").decode("ascii")


def idna_decode(value: str) -> str:
    try:
        import idna

        return idna.decode(value)
    except Exception:
        return value.encode("ascii").decode("idna")


def normalize_domain_input(raw_value: Any) -> dict:
    raw = str(raw_value or "").strip()
    if not raw:
        raise ValueError("Nom de domaine requis.")

    if any(char.isspace() for char in raw):
        raise ValueError("Nom de domaine invalide.")

    parsed = urllib.parse.urlparse(raw if "://" in raw else f"//{raw}")
    host = parsed.hostname
    if not host:
        raise ValueError("Nom de domaine invalide.")

    host = host.strip().strip(".").lower()
    if not host:
        raise ValueError("Nom de domaine invalide.")

    try:
        ipaddress.ip_address(host)
        raise ValueError("Une adresse IP seule n'est pas un nom de domaine.")
    except ValueError as error:
        if "nom de domaine" in str(error):
            raise

    host_ascii = idna_encode(host)
    validate_hostname(host_ascii)
    domain = extract_apex_domain(host_ascii)
    unicode_domain = idna_decode(domain)

    return {
        "input": raw,
        "host": host_ascii,
        "domain": domain,
        "unicode_domain": unicode_domain,
        "tld": domain.rsplit(".", 1)[-1],
    }


def validate_hostname(hostname: str) -> None:
    if len(hostname) > 253:
        raise ValueError("Nom de domaine trop long.")
    labels = hostname.split(".")
    if len(labels) < 2:
        raise ValueError("Le nom de domaine doit contenir une extension.")
    label_re = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
    for label in labels:
        if not label_re.match(label):
            raise ValueError("Nom de domaine invalide.")


def extract_apex_domain(hostname: str) -> str:
    labels = hostname.split(".")
    if labels and labels[0] == "www":
        labels = labels[1:]
    if len(labels) <= 2:
        return ".".join(labels)
    suffix = ".".join(labels[-2:])
    if suffix in COMMON_COMPOUND_SUFFIXES and len(labels) >= 3:
        return ".".join(labels[-3:])
    return ".".join(labels[-2:])


def normalize_domain_list(raw_domains: list[Any]) -> list[str]:
    normalized = []
    for item in raw_domains:
        if item is None:
            continue
        value = str(item).strip()
        if value:
            normalized.append(value)
    return normalized


def parse_csv_domains(csv_text: str) -> list[str]:
    if len(csv_text.encode("utf-8")) > MAX_CSV_BYTES:
        raise PayloadTooLargeError("Le fichier CSV depasse la limite de 1 MB.")

    reader = csv.reader(io.StringIO(csv_text), dialect=detect_csv_dialect(csv_text))
    rows = [[cell.strip().strip('"').strip("'") for cell in row] for row in reader]
    rows = [row for row in rows if any(cell for cell in row)]
    if not rows:
        return []

    header_index = None
    headers = [normalize_header(cell) for cell in rows[0]]
    for index, header in enumerate(headers):
        if header in DOMAIN_HEADER_NAMES:
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

    domains = []
    for candidate in candidates:
        if not candidate:
            continue
        try:
            domains.append(normalize_domain_input(candidate)["domain"])
        except ValueError:
            continue
    return domains


def enforce_unique_domain_limit(domains: list[str]) -> None:
    if len(unique_preserve_order(domains)) > MAX_UNIQUE_DOMAINS:
        raise TooManyDomainsError(
            f"Maximum {MAX_UNIQUE_DOMAINS} domaines uniques par analyse CSV pour cette version."
        )


def fetch_json(url: str, timeout: int = 10) -> Any:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 Domain-Lookup-Script/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw)


def resolve_records(domain: str, record_type: str) -> dict:
    try:
        import dns.resolver

        resolver = dns.resolver.Resolver()
        resolver.timeout = 2
        resolver.lifetime = 4
        answer = resolver.resolve(domain, record_type, raise_on_no_answer=False)
        records = [str(item).strip() for item in answer]
        return {"ok": True, "records": unique_preserve_order(records)}
    except Exception as error:
        return {"ok": False, "records": [], "error": str(error)}


def lookup_dns(domain: str) -> dict:
    records = {record_type: resolve_records(domain, record_type) for record_type in DNS_RECORD_TYPES}
    www_domain = f"www.{domain}"
    www_records = {
        record_type: resolve_records(www_domain, record_type)
        for record_type in ["A", "AAAA", "CNAME"]
    }
    dmarc = resolve_records(f"_dmarc.{domain}", "TXT")
    txt_records = records.get("TXT", {}).get("records", [])
    dmarc_records = dmarc.get("records", [])

    return {
        "records": records,
        "www": www_records,
        "spf": first_matching_record(txt_records, "v=spf1"),
        "dmarc": first_matching_record(dmarc_records, "v=dmarc1"),
        "dnssec": bool(records.get("DS", {}).get("records") or records.get("DNSKEY", {}).get("records")),
    }


def first_matching_record(records: list[str], prefix: str) -> str | None:
    normalized_prefix = prefix.lower()
    for record in records:
        cleaned = record.strip('"')
        if cleaned.lower().startswith(normalized_prefix):
            return cleaned
    return None


def collect_dns_ips(dns_data: dict) -> list[str]:
    ips = []
    for section in [dns_data.get("records", {}), dns_data.get("www", {})]:
        for record_type in ["A", "AAAA"]:
            ips.extend(section.get(record_type, {}).get("records", []))
    valid_ips = []
    for ip in ips:
        try:
            ipaddress.ip_address(ip)
            valid_ips.append(ip)
        except ValueError:
            continue
    return unique_preserve_order(valid_ips)


def lookup_ips(ips: list[str]) -> dict:
    if not ips:
        return {"ok": True, "input_count": 0, "unique_count": 0, "results": [], "summary": {}}
    try:
        return analyze_ip_list(ips, use_batch=True)
    except Exception as error:
        return {"ok": False, "error": str(error), "results": []}


def get_rdap_bootstrap() -> dict:
    global _RDAP_BOOTSTRAP_CACHE
    if _RDAP_BOOTSTRAP_CACHE is None:
        data = fetch_json(RDAP_BOOTSTRAP_URL, timeout=10)
        _RDAP_BOOTSTRAP_CACHE = data if isinstance(data, dict) else {}
    return _RDAP_BOOTSTRAP_CACHE


def rdap_base_url_for_tld(tld: str) -> str | None:
    bootstrap = get_rdap_bootstrap()
    services = bootstrap.get("services", [])
    if not isinstance(services, list):
        return None
    wanted = tld.lower()
    for service in services:
        if not isinstance(service, list) or len(service) < 2:
            continue
        tlds, urls = service[0], service[1]
        if wanted in [str(item).lower() for item in tlds] and urls:
            return str(urls[0])
    return None


def lookup_rdap(domain: str, tld: str) -> dict:
    try:
        base_url = rdap_base_url_for_tld(tld)
        if not base_url:
            return {"ok": False, "error": "Aucun serveur RDAP trouve pour ce TLD."}
        url = f"{base_url.rstrip('/')}/domain/{urllib.parse.quote(domain)}"
        raw = fetch_json(url, timeout=12)
        if not isinstance(raw, dict):
            return {"ok": False, "error": "Reponse RDAP inattendue."}
        return parse_rdap(raw, url)
    except HTTPError as error:
        return {"ok": False, "error": f"HTTP error {error.code}"}
    except URLError as error:
        return {"ok": False, "error": f"Network error: {error.reason}"}
    except Exception as error:
        return {"ok": False, "error": str(error)}


def parse_rdap(raw: dict, query_url: str | None = None) -> dict:
    entities = [parse_rdap_entity(entity) for entity in raw.get("entities", []) if isinstance(entity, dict)]
    registrar_entity = first_entity_with_role(entities, "registrar")
    registrant_entity = first_entity_with_role(entities, "registrant")
    event_dates = parse_rdap_events(raw.get("events", []))
    notices = parse_rdap_notices(raw.get("notices", [])) + parse_rdap_notices(raw.get("remarks", []))
    nameservers = [
        first_non_empty(item.get("ldhName"), item.get("unicodeName"))
        for item in raw.get("nameservers", [])
        if isinstance(item, dict)
    ]
    nameservers = [item for item in nameservers if item]
    redacted = has_redaction(raw) or any(entity.get("redacted") for entity in entities)
    owner_visibility = determine_owner_visibility(registrant_entity, redacted)

    return {
        "ok": True,
        "query_url": query_url,
        "handle": raw.get("handle"),
        "ldh_name": raw.get("ldhName"),
        "unicode_name": raw.get("unicodeName"),
        "status": raw.get("status", []),
        "events": event_dates,
        "created_at": event_dates.get("registration") or event_dates.get("created"),
        "updated_at": event_dates.get("last changed") or event_dates.get("last update of rdap database"),
        "expires_at": event_dates.get("expiration"),
        "registrar": entity_display_name(registrar_entity),
        "nameservers": nameservers,
        "entities": entities,
        "notices": notices,
        "links": [link.get("href") for link in raw.get("links", []) if isinstance(link, dict) and link.get("href")],
        "owner_visibility": owner_visibility,
        "redacted": redacted,
        "raw_rdap": raw,
    }


def parse_rdap_events(events: list[Any]) -> dict:
    parsed = {}
    for event in events:
        if not isinstance(event, dict):
            continue
        action = lower_text(event.get("eventAction"))
        date = event.get("eventDate")
        if action and date:
            parsed[action] = date
    return parsed


def parse_rdap_notices(notices: list[Any]) -> list[str]:
    result = []
    for notice in notices:
        if not isinstance(notice, dict):
            continue
        title = notice.get("title")
        descriptions = notice.get("description", [])
        if title:
            result.append(str(title))
        if isinstance(descriptions, list):
            result.extend(str(item) for item in descriptions if item)
    return unique_preserve_order(result)


def parse_rdap_entity(entity: dict) -> dict:
    vcard = parse_vcard(entity.get("vcardArray"))
    roles = entity.get("roles", [])
    parsed = {
        "handle": entity.get("handle"),
        "roles": roles if isinstance(roles, list) else [],
        "public_ids": entity.get("publicIds", []),
        "name": first_non_empty(vcard.get("fn"), vcard.get("org"), entity.get("handle")),
        "organization": vcard.get("org"),
        "email": vcard.get("email"),
        "phone": vcard.get("tel"),
        "address": vcard.get("adr"),
        "links": [link.get("href") for link in entity.get("links", []) if isinstance(link, dict) and link.get("href")],
    }
    parsed["redacted"] = has_redaction(parsed)
    return parsed


def parse_vcard(vcard_array: Any) -> dict:
    if not isinstance(vcard_array, list) or len(vcard_array) < 2 or not isinstance(vcard_array[1], list):
        return {}
    fields: dict[str, Any] = {}
    for item in vcard_array[1]:
        if not isinstance(item, list) or len(item) < 4:
            continue
        name = str(item[0]).lower()
        value = item[3]
        if name == "fn":
            fields["fn"] = flatten_vcard_value(value)
        elif name == "org":
            fields["org"] = flatten_vcard_value(value)
        elif name == "email":
            fields["email"] = flatten_vcard_value(value)
        elif name == "tel":
            fields["tel"] = flatten_vcard_value(value)
        elif name == "adr":
            fields["adr"] = flatten_vcard_value(value)
    return fields


def flatten_vcard_value(value: Any) -> str | None:
    if isinstance(value, list):
        parts = []
        for item in value:
            flattened = flatten_vcard_value(item)
            if flattened:
                parts.append(flattened)
        return ", ".join(parts) if parts else None
    text = str(value).strip()
    return text or None


def first_entity_with_role(entities: list[dict], role: str) -> dict | None:
    for entity in entities:
        if role in [lower_text(item) for item in entity.get("roles", [])]:
            return entity
    return None


def entity_display_name(entity: dict | None) -> str | None:
    if not entity:
        return None
    return first_non_empty(entity.get("name"), entity.get("organization"), entity.get("handle"))


def has_redaction(value: Any) -> bool:
    text = lower_text(json.dumps(value, ensure_ascii=True) if isinstance(value, (dict, list)) else value)
    return any(keyword in text for keyword in REDACTION_KEYWORDS)


def determine_owner_visibility(registrant: dict | None, redacted: bool) -> str:
    if registrant and (registrant.get("email") or registrant.get("phone")) and not redacted:
        return "public"
    if registrant and (registrant.get("name") or registrant.get("organization")):
        return "partial" if redacted else "public"
    if redacted:
        return "redacted"
    return "unknown"


def lookup_http(domain: str) -> dict:
    attempts = []
    for scheme in ["https", "http"]:
        url = f"{scheme}://{domain}/"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Domain-Lookup-Script/1.0"})
            with urllib.request.urlopen(req, timeout=8) as response:
                headers = dict(response.headers.items())
                return {
                    "ok": True,
                    "scheme": scheme,
                    "status": response.status,
                    "final_url": response.geturl(),
                    "server": headers.get("Server"),
                    "content_type": headers.get("Content-Type"),
                    "hsts": headers.get("Strict-Transport-Security"),
                }
        except Exception as error:
            attempts.append({"url": url, "error": str(error)})
    return {"ok": False, "attempts": attempts, "error": attempts[-1]["error"] if attempts else "HTTP indisponible"}


def lookup_tls(domain: str) -> dict:
    try:
        context = ssl.create_default_context()
        with socket.create_connection((domain, 443), timeout=6) as sock:
            with context.wrap_socket(sock, server_hostname=domain) as tls_sock:
                cert = tls_sock.getpeercert()
        not_after = cert.get("notAfter")
        expires_at = parse_tls_date(not_after)
        days_remaining = None
        if expires_at:
            days_remaining = (expires_at - dt.datetime.utcnow()).days
        return {
            "ok": True,
            "subject": parse_cert_name(cert.get("subject", [])),
            "issuer": parse_cert_name(cert.get("issuer", [])),
            "not_before": cert.get("notBefore"),
            "not_after": not_after,
            "expires_in_days": days_remaining,
            "san": [value for key, value in cert.get("subjectAltName", []) if key.lower() == "dns"],
            "matches_domain": tls_cert_matches_domain(cert, domain),
        }
    except Exception as error:
        return {"ok": False, "error": str(error)}


def parse_cert_name(items: Any) -> dict:
    result = {}
    for group in items or []:
        for key, value in group:
            result[str(key)] = value
    return result


def parse_tls_date(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.strptime(value, "%b %d %H:%M:%S %Y %Z")
    except ValueError:
        return None


def tls_cert_matches_domain(cert: dict, domain: str) -> bool:
    try:
        ssl.match_hostname(cert, domain)
        return True
    except Exception:
        return False


def lookup_certificate_transparency(domain: str) -> dict:
    url = f"https://crt.sh/?q=%25.{urllib.parse.quote(domain)}&output=json"
    try:
        data = fetch_json(url, timeout=12)
        if not isinstance(data, list):
            return {"ok": False, "error": "Reponse CT inattendue.", "source": "crt.sh"}
        subdomains = []
        certificates = []
        for item in data:
            if not isinstance(item, dict):
                continue
            certificates.append(
                {
                    "issuer_name": item.get("issuer_name"),
                    "common_name": item.get("common_name"),
                    "not_before": item.get("not_before"),
                    "not_after": item.get("not_after"),
                }
            )
            for name in str(item.get("name_value", "")).splitlines():
                cleaned = name.strip().lower().strip(".")
                if cleaned and "*" not in cleaned and cleaned.endswith(domain):
                    subdomains.append(cleaned)
        unique_subdomains = unique_preserve_order(sorted(set(subdomains)))
        return {
            "ok": True,
            "source": "crt.sh",
            "subdomains": unique_subdomains[:MAX_CT_SUBDOMAINS],
            "subdomain_count": len(unique_subdomains),
            "certificates": certificates[:MAX_CT_SUBDOMAINS],
            "truncated": len(unique_subdomains) > MAX_CT_SUBDOMAINS,
        }
    except Exception as error:
        return {"ok": False, "source": "crt.sh", "error": str(error), "best_effort": True}


def infer_provider_from_text(text: str, keywords: dict[str, str]) -> str | None:
    normalized = lower_text(text)
    for keyword, provider in keywords.items():
        if keyword in normalized:
            return provider
    return None


def infer_hosting(domain: str, dns_data: dict, ip_results: list[dict]) -> dict:
    evidence = []
    providers = []
    cdn_providers = []

    dns_text_parts = [domain]
    for section in [dns_data.get("records", {}), dns_data.get("www", {})]:
        for value in section.values():
            dns_text_parts.extend(value.get("records", []))
    dns_text = " ".join(dns_text_parts)

    for keyword, provider in CDN_PROXY_KEYWORDS.items():
        if keyword in lower_text(dns_text):
            cdn_providers.append(provider)
            evidence.append(f"DNS mentionne {provider}.")

    for result in ip_results:
        network = result.get("network", {})
        text = " ".join(str(network.get(key) or "") for key in ["isp", "org", "asn_full", "asn_name", "reverse_dns"])
        provider = infer_provider_from_text(text, HOSTING_PROVIDER_KEYWORDS)
        if provider:
            providers.append(provider)
            evidence.append(f"IP {result.get('ip') or result.get('input')} associee a {provider}.")
        cdn_provider = infer_provider_from_text(text, CDN_PROXY_KEYWORDS)
        if cdn_provider:
            cdn_providers.append(cdn_provider)
            evidence.append(f"IP {result.get('ip') or result.get('input')} indique un CDN/proxy {cdn_provider}.")

    provider_counts = Counter(providers)
    cdn_counts = Counter(cdn_providers)
    probable_provider = provider_counts.most_common(1)[0][0] if provider_counts else None
    probable_cdn = cdn_counts.most_common(1)[0][0] if cdn_counts else None
    is_proxy = bool(probable_cdn)

    return {
        "probable_provider": probable_provider or probable_cdn,
        "probable_hosting_provider": probable_provider,
        "probable_cdn_proxy": probable_cdn,
        "is_cdn_or_proxy_probable": is_proxy,
        "evidence": unique_preserve_order(evidence),
        "origin_note": (
            "Le domaine semble passer par un CDN/proxy. Les IP observees peuvent etre des points de sortie et non le serveur d'origine."
            if is_proxy
            else "Aucun CDN/proxy evident dans les donnees publiques collectees."
        ),
    }


def extract_public_contacts(rdap_data: dict) -> list[dict]:
    contacts = []
    for entity in rdap_data.get("entities", []):
        contact = {
            "roles": entity.get("roles", []),
            "name": entity.get("name"),
            "organization": entity.get("organization"),
            "email": entity.get("email"),
            "phone": entity.get("phone"),
            "links": entity.get("links", []),
        }
        if any(contact.get(key) for key in ["name", "organization", "email", "phone"]) or contact["links"]:
            contacts.append(contact)
    return contacts


def build_contact_workflow(domain: str, rdap_data: dict, hosting: dict) -> dict:
    visibility = rdap_data.get("owner_visibility", "unknown") if rdap_data.get("ok") else "unknown"
    registrar = rdap_data.get("registrar") if rdap_data.get("ok") else None
    contacts = extract_public_contacts(rdap_data) if rdap_data.get("ok") else []
    request_needed = visibility != "public"
    tld = domain.rsplit(".", 1)[-1]
    rdrs_recommended = request_needed and (len(tld) > 2 or tld in COMMON_GTLD_HINTS)
    request_template = build_disclosure_request_template(domain, registrar, visibility, hosting, rdrs_recommended)

    return {
        "owner_visibility": visibility,
        "public_contacts": contacts,
        "registrar": registrar,
        "request_needed": request_needed,
        "rdrs_recommended": rdrs_recommended,
        "rdrs_url": "https://rdrs.icann.org/" if rdrs_recommended else None,
        "request_template": request_template,
        "limitations": [
            "Les donnees RDAP publiques peuvent etre masquees pour des raisons de confidentialite.",
            "L'outil ne contourne pas les protections WHOIS/RDAP et n'identifie pas une personne sans base legale.",
            "En cas de CDN/proxy, les IP visibles peuvent ne pas etre celles de l'hebergement d'origine.",
        ],
    }


def build_disclosure_request_template(
    domain: str,
    registrar: str | None,
    visibility: str,
    hosting: dict,
    rdrs_recommended: bool,
) -> str:
    channel = "RDRS ICANN ou procedure du registrar" if rdrs_recommended else "procedure du registrar"
    provider = hosting.get("probable_provider") or "hebergeur non determine"
    today = dt.datetime.utcnow().strftime("%Y-%m-%d")
    return "\n".join(
        [
            f"Domaine concerne: {domain}",
            f"Registrar public: {registrar or 'non determine'}",
            f"Visibilite proprietaire RDAP: {visibility}",
            f"Hebergeur/CDN probable: {provider}",
            f"Date de constat UTC: {today}",
            f"Canal recommande: {channel}",
            "",
            "Objet: demande de divulgation ou de contact du titulaire du nom de domaine",
            "",
            "Bonjour,",
            "Je sollicite les informations non publiques ou la transmission d'une demande au titulaire du nom de domaine ci-dessus.",
            "Motif a completer: investigation securite, abus, fraude, litige ou autre interet legitime.",
            "Donnees demandees: titulaire, organisation, email de contact, telephone, adresse postale, contact technique et historique utile si disponible.",
            "Elements a joindre: captures, journaux horodates, URLs concernees, contexte legal, mandat ou reference de dossier si applicable.",
            "Merci d'indiquer la procedure applicable si ces donnees sont protegees ou traitees via un service de confidentialite.",
        ]
    )


def build_domain_summary(result: dict) -> dict:
    dns_data = result.get("dns", {})
    rdap_data = result.get("rdap", {})
    http_data = result.get("http", {})
    tls_data = result.get("tls", {})
    ct_data = result.get("certificate_transparency", {})
    hosting = result.get("hosting", {})
    return {
        "domain": result.get("domain"),
        "registrar": rdap_data.get("registrar"),
        "created_at": rdap_data.get("created_at"),
        "expires_at": rdap_data.get("expires_at"),
        "owner_visibility": result.get("contact_workflow", {}).get("owner_visibility"),
        "ip_count": len(result.get("ips", [])),
        "hosting_provider": hosting.get("probable_provider"),
        "cdn_or_proxy": hosting.get("is_cdn_or_proxy_probable"),
        "nameserver_count": len(rdap_data.get("nameservers", [])),
        "has_spf": bool(dns_data.get("spf")),
        "has_dmarc": bool(dns_data.get("dmarc")),
        "dnssec": dns_data.get("dnssec"),
        "http_status": http_data.get("status"),
        "tls_ok": tls_data.get("ok"),
        "tls_expires_in_days": tls_data.get("expires_in_days"),
        "ct_subdomain_count": ct_data.get("subdomain_count"),
    }


def analyze_domain(raw_domain: Any) -> dict:
    try:
        normalized = normalize_domain_input(raw_domain)
    except ValueError as error:
        return {"ok": False, "input": str(raw_domain or ""), "error": str(error)}

    domain = normalized["domain"]
    dns_data = lookup_dns(domain)
    ips = collect_dns_ips(dns_data)
    ip_lookup = lookup_ips(ips)
    ip_results = ip_lookup.get("results", []) if ip_lookup.get("ok") else []
    rdap_data = lookup_rdap(domain, normalized["tld"])
    http_data = lookup_http(domain)
    tls_data = lookup_tls(domain)
    ct_data = lookup_certificate_transparency(domain)
    hosting = infer_hosting(domain, dns_data, ip_results)
    contact_workflow = build_contact_workflow(domain, rdap_data, hosting)

    result = {
        "ok": True,
        **normalized,
        "dns": dns_data,
        "rdap": rdap_data,
        "ips": ip_results,
        "ip_lookup": ip_lookup,
        "hosting": hosting,
        "http": http_data,
        "tls": tls_data,
        "certificate_transparency": ct_data,
        "contact_workflow": contact_workflow,
    }
    result["summary"] = build_domain_summary(result)
    return result


def build_global_domain_summary(results: list[dict]) -> dict:
    summary = {
        "total": len(results),
        "ok": 0,
        "errors": 0,
        "registrars": {},
        "hosting_providers": {},
        "owner_visibility": {},
        "priority_domains": [],
    }
    for result in results:
        if result.get("ok"):
            summary["ok"] += 1
            result_summary = result.get("summary", {})
            registrar = result_summary.get("registrar") or "inconnu"
            provider = result_summary.get("hosting_provider") or "inconnu"
            visibility = result_summary.get("owner_visibility") or "unknown"
            summary["registrars"][registrar] = summary["registrars"].get(registrar, 0) + 1
            summary["hosting_providers"][provider] = summary["hosting_providers"].get(provider, 0) + 1
            summary["owner_visibility"][visibility] = summary["owner_visibility"].get(visibility, 0) + 1
            if result.get("contact_workflow", {}).get("request_needed"):
                summary["priority_domains"].append(
                    {
                        "domain": result.get("domain"),
                        "registrar": registrar,
                        "owner_visibility": visibility,
                        "hosting_provider": provider,
                    }
                )
        else:
            summary["errors"] += 1
    return summary


def analyze_domain_list(domains: list[str]) -> dict:
    normalized_inputs = normalize_domain_list(domains)
    normalized_keys = []
    prepared = []
    for item in normalized_inputs:
        try:
            normalized = normalize_domain_input(item)
            key = normalized["domain"]
        except ValueError:
            key = item
        normalized_keys.append(key)
        prepared.append((item, key))

    enforce_unique_domain_limit(normalized_keys)
    occurrence_counts = Counter(normalized_keys)
    unique_items = []
    seen = set()
    for item, key in prepared:
        if key in seen:
            continue
        seen.add(key)
        unique_items.append((item, key))

    results = []
    for item, key in unique_items:
        result = analyze_domain(item)
        result["occurrences"] = max(1, occurrence_counts.get(key, 1))
        results.append(result)

    return {
        "ok": True,
        "input_count": len(normalized_inputs),
        "unique_count": len(unique_items),
        "results": results,
        "summary": build_global_domain_summary(results),
    }


def build_api_response_for_single_domain(domain: str) -> dict:
    result = analyze_domain(domain)
    return {"ok": result.get("ok", False), "result": result}


def build_api_response_for_multiple_domains(domains: list[str], csv_text: str | None = None) -> dict:
    all_domains = []
    all_domains.extend(normalize_domain_list(domains))
    if csv_text is not None:
        all_domains.extend(parse_csv_domains(csv_text))

    if not all_domains:
        return {
            "ok": False,
            "error": "Provide 'domains' as a list and/or 'csv' as text with at least one valid domain.",
        }

    return analyze_domain_list(all_domains)

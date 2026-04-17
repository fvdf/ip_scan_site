import unittest
from unittest.mock import patch

import domain_analysis


class DomainAnalysisTests(unittest.TestCase):
    def test_normalize_domain_accepts_url_www_and_extracts_apex(self) -> None:
        normalized = domain_analysis.normalize_domain_input("https://www.Example.com/path?q=1")

        self.assertEqual(normalized["domain"], "example.com")
        self.assertEqual(normalized["unicode_domain"], "example.com")
        self.assertEqual(normalized["tld"], "com")
        self.assertEqual(normalized["host"], "www.example.com")

    def test_normalize_domain_handles_common_compound_suffix(self) -> None:
        normalized = domain_analysis.normalize_domain_input("shop.example.co.uk")

        self.assertEqual(normalized["domain"], "example.co.uk")
        self.assertEqual(normalized["tld"], "uk")

    def test_normalize_domain_rejects_ip_only(self) -> None:
        with self.assertRaises(ValueError):
            domain_analysis.normalize_domain_input("8.8.8.8")

    def test_parse_csv_domains_uses_domain_header(self) -> None:
        csv_text = (
            "nom_de_domaine;date\n"
            "https://www.example.com/path;2026-01-01\n"
            "api.example.org;2026-01-02\n"
        )

        self.assertEqual(
            domain_analysis.parse_csv_domains(csv_text),
            ["example.com", "example.org"],
        )

    def test_parse_csv_domains_scans_cells_when_no_header_exists(self) -> None:
        csv_text = (
            "label,value\n"
            "alpha,not-a-domain\n"
            "beta,https://www.example.net/path\n"
        )

        self.assertEqual(domain_analysis.parse_csv_domains(csv_text), ["example.net"])

    def test_limit_rejects_more_than_50_unique_domains(self) -> None:
        domains = [f"example{index}.com" for index in range(51)]

        with self.assertRaises(domain_analysis.TooManyDomainsError):
            domain_analysis.enforce_unique_domain_limit(domains)

    def test_parse_rdap_extracts_registrar_dates_contacts_and_redaction(self) -> None:
        raw = {
            "handle": "EXAMPLE",
            "ldhName": "example.com",
            "status": ["active"],
            "events": [
                {"eventAction": "registration", "eventDate": "2020-01-01T00:00:00Z"},
                {"eventAction": "expiration", "eventDate": "2030-01-01T00:00:00Z"},
            ],
            "nameservers": [{"ldhName": "ns1.example.net"}],
            "notices": [{"title": "Terms", "description": ["Registrant data redacted for privacy."]}],
            "entities": [
                {
                    "roles": ["registrar"],
                    "vcardArray": [
                        "vcard",
                        [["fn", {}, "text", "Example Registrar"], ["email", {}, "text", "abuse@example.test"]],
                    ],
                },
                {
                    "roles": ["registrant"],
                    "vcardArray": ["vcard", [["fn", {}, "text", "REDACTED FOR PRIVACY"]]],
                },
            ],
        }

        parsed = domain_analysis.parse_rdap(raw, "https://rdap.example/domain/example.com")

        self.assertTrue(parsed["ok"])
        self.assertEqual(parsed["registrar"], "Example Registrar")
        self.assertEqual(parsed["created_at"], "2020-01-01T00:00:00Z")
        self.assertEqual(parsed["expires_at"], "2030-01-01T00:00:00Z")
        self.assertEqual(parsed["nameservers"], ["ns1.example.net"])
        self.assertEqual(parsed["owner_visibility"], "partial")
        self.assertTrue(parsed["redacted"])

    def test_contact_workflow_generates_rdrs_template_when_owner_is_masked(self) -> None:
        rdap = {
            "ok": True,
            "registrar": "Example Registrar",
            "owner_visibility": "redacted",
            "entities": [
                {
                    "roles": ["abuse"],
                    "name": "Abuse Desk",
                    "email": "abuse@example.test",
                    "links": [],
                }
            ],
        }
        hosting = {"probable_provider": "Cloudflare"}

        workflow = domain_analysis.build_contact_workflow("example.com", rdap, hosting)

        self.assertTrue(workflow["request_needed"])
        self.assertTrue(workflow["rdrs_recommended"])
        self.assertIn("Example Registrar", workflow["request_template"])
        self.assertIn("example.com", workflow["request_template"])
        self.assertEqual(workflow["public_contacts"][0]["email"], "abuse@example.test")

    def test_analyze_domain_list_deduplicates_and_aggregates(self) -> None:
        def fake_analyze_domain(value: str) -> dict:
            normalized = domain_analysis.normalize_domain_input(value)
            domain = normalized["domain"]
            return {
                "ok": True,
                "domain": domain,
                "summary": {
                    "registrar": "Registrar A" if domain == "example.com" else "Registrar B",
                    "hosting_provider": "Host A",
                    "owner_visibility": "redacted",
                },
                "contact_workflow": {"request_needed": True},
            }

        with patch.object(domain_analysis, "analyze_domain", side_effect=fake_analyze_domain):
            response = domain_analysis.analyze_domain_list(
                ["example.com", "https://www.example.com/path", "example.net"]
            )

        self.assertTrue(response["ok"])
        self.assertEqual(response["input_count"], 3)
        self.assertEqual(response["unique_count"], 2)
        self.assertEqual(response["summary"]["ok"], 2)
        self.assertEqual(response["results"][0]["occurrences"], 2)
        self.assertEqual(response["summary"]["owner_visibility"]["redacted"], 2)


if __name__ == "__main__":
    unittest.main()

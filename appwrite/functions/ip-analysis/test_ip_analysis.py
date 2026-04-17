import unittest
from unittest.mock import patch

import ip_analysis


class IpAnalysisTests(unittest.TestCase):
    def test_parse_csv_uses_ip_address_column_and_ignores_dates(self) -> None:
        csv_text = (
            "IPAddress;DateTimeUtc\n"
            "130.25.88.216;09/26/2025 16:16:42\n"
            "37.169.3.60;08/19/2025 13:36:59\n"
            "37.169.3.60;08/19/2025 13:36:40\n"
        )

        self.assertEqual(
            ip_analysis.parse_csv_ips(csv_text),
            ["130.25.88.216", "37.169.3.60", "37.169.3.60"],
        )

    def test_parse_csv_scans_cells_when_no_ip_header_exists(self) -> None:
        csv_text = (
            "user,date,value\n"
            "alpha,2025-08-19,8.8.8.8\n"
            "beta,not-an-ip,2001:4860:4860::8888\n"
        )

        self.assertEqual(
            ip_analysis.parse_csv_ips(csv_text),
            ["8.8.8.8", "2001:4860:4860::8888"],
        )

    def test_limit_rejects_more_than_100_unique_ips(self) -> None:
        ips = [f"192.0.2.{index}" for index in range(101)]

        with self.assertRaises(ip_analysis.TooManyIpsError):
            ip_analysis.enforce_unique_ip_limit(ips)

    def test_analyze_ip_list_keeps_occurrences_and_summary(self) -> None:
        def fake_lookup_batch(ips: list[str]) -> list[dict]:
            return [
                {
                    "ok": True,
                    "input": ip,
                    "ip": ip,
                    "location": {"country": "France", "city": "Paris"},
                    "network": {"isp": "Example ISP", "org": "Example ISP"},
                    "flags": {
                        "is_mobile": False,
                        "is_proxy_or_vpn_or_tor": False,
                        "is_hosting_or_datacenter": False,
                    },
                }
                for ip in ip_analysis.unique_preserve_order(ips)
            ]

        with patch.object(ip_analysis, "lookup_ip_batch", side_effect=fake_lookup_batch):
            response = ip_analysis.analyze_ip_list(["8.8.8.8", "8.8.8.8", "1.1.1.1"])

        self.assertTrue(response["ok"])
        self.assertEqual(response["input_count"], 3)
        self.assertEqual(response["unique_count"], 2)
        self.assertEqual(response["summary"]["ok"], 2)
        self.assertEqual(response["results"][0]["occurrences"], 2)
        self.assertEqual(
            response["results"][0]["analysis"]["category"],
            "residential_or_isp_probable",
        )


if __name__ == "__main__":
    unittest.main()

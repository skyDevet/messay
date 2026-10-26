#!/usr/bin/env python3
"""
etrade.gov.et business license checker — Selenium scraper
Usage: python etrade_check.py 0068699863
"""

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
import sys
import json
import time

URL  = "https://etrade.gov.et/business-license-checker"
INPUT = (By.CSS_SELECTOR, "input#default-search")
BUTTON = (By.CSS_SELECTOR, "button[type='submit']")


def check(license_no):
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--window-size=1920,1080")
    options.set_preference("dom.webdriver.enabled", False)
    options.set_preference("useAutomationExtension", False)
    options.set_preference(
        "general.useragent.override",
        "Mozilla/5.0 (Linux; Android 11; ZTE Blade A5 2020) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
    )
    options.binary_location = "/data/data/com.termux/files/usr/bin/firefox"
    service = Service(executable_path="/data/data/com.termux/files/usr/bin/geckodriver")

    driver = webdriver.Firefox(service=service, options=options)
    try:
        print(f"[*] Loading {URL}")
        driver.get(URL)
        time.sleep(5)  # Angular bootstrap

        print("[*] Waiting for input...")
        field = WebDriverWait(driver, 30).until(
            EC.presence_of_element_located(INPUT)
        )
        field.clear()
        field.send_keys(license_no)
        print(f"[+] Typed: {license_no}")

        driver.find_element(*BUTTON).click()
        print("[*] Clicked ፈልግ — waiting for results...")

        # Wait until either result cards or an error appear
        WebDriverWait(driver, 30).until(
            lambda d: "AA/" in d.page_source
                   or "አልተገኘም" in d.page_source
                   or "not found" in d.page_source.lower()
                   or "no data" in d.page_source.lower()
        )
        time.sleep(2)

        # Scrape the rendered result cards
        result = {}
        # The data lives inside cards with <p> labels + <span> values
        try:
            cards = driver.find_elements(
                "css selector", "app-business-license-checker .bg-white.shadow.rounded-lg"
            )
            for card in cards:
                for row in card.find_elements("css selector", "div"):
                    try:
                        label = row.find_element(
                            "css selector", "p.text-teal-800"
                        ).text.strip()
                        value_el = row.find_elements("css selector", "span")
                        if label and value_el:
                            result[label] = value_el[0].text.strip()
                    except Exception:
                        pass
        except Exception as e:
            print(f"[!] scrape error: {e}")

        # Fallback: dump all teal labels + following span
        if not result:
            labels = driver.find_elements("css selector", "p.text-teal-800")
            for lbl in labels:
                try:
                    val = lbl.find_element(
                        "xpath", "following-sibling::*[1]"
                    ).text.strip()
                    if val:
                        result[lbl.text.strip()] = val
                except Exception:
                    pass

        return result

    finally:
        driver.quit()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python etrade_check.py <license_number>")
        sys.exit(1)

    lic = sys.argv[1].strip()
    data = check(lic)
    print("\n" + "=" * 60)
    print("RESULT")
    print("=" * 60)
    print(json.dumps(data, ensure_ascii=False, indent=2))

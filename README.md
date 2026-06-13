# wp-site-finder

Small Windows tooling to **inventory WordPress sites on a server IP**.

## Files

| File | What it does |
|------|--------------|
| `wp-finder.bat` | Reverse-IP lookup (HackerTarget API) → checks each domain for WordPress → writes the WP sites to a txt file. |
| `wp-dorks.txt` | Google fingerprinting dorks that identify sites running WordPress (manual / SERP-API use). |

## wp-finder.bat

Requires `curl` (built into Windows 10 1803+ / Windows 11).

```bat
wp-finder.bat <IP> [output.txt]
wp-finder.bat 72.60.89.132 wp-sites.txt
```

1. Reverse-IP lookup returns every domain on the IP.
2. Each domain's homepage + `/wp-login.php` is scanned for WordPress markers
   (`wp-content`, `/wp-json`, login form, etc.).
3. Matches are written one-per-line to the output file (default `wordpress-sites.txt`).

**Limits:** the free HackerTarget API is rate-limited (~50 lookups/day per source
IP) and its reverse-IP index is partial — best on large shared-hosting IPs.

## wp-dorks.txt

WordPress **fingerprinting** dorks only (identify that a site runs WordPress).
Paste one line into Google; combine with `site:` to scope to a domain or TLD.
Not for automated scraping — Google will CAPTCHA scripted queries; use a SERP
API (Google Custom Search JSON API, SerpApi) if you need it programmatic.

## Scope

For inventorying sites on infrastructure you own or are authorized to assess.

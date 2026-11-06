# teamsinigang.com: AdSense pre-review patch

## 1. Upload the HTML (30 files)
Upload everything in this folder to the Bunny storage zone, keeping the paths as they are.
These are the live pages with only head tags added. Body content is unchanged.

- /anime/ (6 pages): added the google-adsense-account meta tag, a meta description, and a canonical
- Every other page except the homepage and Fingularity (which already had them): added a canonical

## 2. Add the bare-domain to www redirect (Bunny Edge Rule)
CDN, then your pull zone, then Edge Rules, then Add Edge Rule

- Action: Redirect To URL
- Redirect URL: https://www.teamsinigang.com{{path}}
- Status code: 301
- Condition: Request URL, Match Any
    *://teamsinigang.com/*
    *://teamsinigang.com
- Description: "apex to www"

Keep the condition limited to the bare domain. If you use a wildcard that also matches www, the redirect will loop.

Optional second rule: send the *.b-cdn.net hostname to www the same way, so that copy doesn't get indexed either.

## 3. Purge and verify
Purge the pull zone cache, then run:

  curl -sI https://teamsinigang.com/anime/akira.html | grep -iE '^(HTTP|location)'
  # expect: 301  location: https://www.teamsinigang.com/anime/akira.html
  curl -sI http://teamsinigang.com/ | grep -iE '^(HTTP|location)'
  # expect: 301 to https://www... (one hop is ideal, two is fine)
  curl -s https://www.teamsinigang.com/anime/akira.html | grep -E 'canonical|adsense-account|description'

## 4. Before requesting review
In Search Console, use URL Inspection on a few /anime/ pages and request indexing.
Wait until the Pages report shows most of the 32 sitemap URLs as indexed.

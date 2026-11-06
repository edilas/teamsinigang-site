WRENCH & ROAM - standalone web build for teamsinigang.com
==========================================================

Everything the game needs is in this folder. It has no API keys, no
AI calls and no third-party CDNs: the 3D engine (three.js), the fonts
and the icon are all served from the same place as index.html.

FILES
  index.html          the whole game
  js/three.min.js     3D engine (three.js r128, MIT license)
  fonts/              Bowlby One SC, Barlow, Barlow Condensed (OFL) + fonts.css
  favicon.svg         browser tab icon
  licenses/           license texts for three.js and the fonts

UPLOAD TO BUNNY
  1. In your Bunny Storage Zone, make a folder, for example:  /wrench-and-roam/
  2. Upload the CONTENTS of this folder into it, keeping the js/, fonts/
     and licenses/ subfolders exactly as they are (paths are relative).
  3. Open  https://teamsinigang.com/wrench-and-roam/  (with the trailing
     slash) and check that the car, fonts and the 3D drive all load.
     If the bare folder URL 404s, either link to .../wrench-and-roam/index.html
     or turn on the Pull Zone option that serves index.html for folders.
  4. After re-uploading a new version, purge the Pull Zone cache so
     players get the update.

WHAT'S DIFFERENT FROM THE CLAUDE VERSION
  - "Build a city" with AI is replaced by 12 ready-made cities
    (Monrovia, San Francisco, Manila, Tokyo, New York City, Chicago,
    Paris, London, Honolulu, Las Vegas, Denver, Portland).
  - Typing any other name makes up a brand-new town on the spot.
  - "Download save file" uses a normal browser download.
  - Saves live in each player's own browser (localStorage).

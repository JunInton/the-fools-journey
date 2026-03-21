# python add_coi.py

ANALYTICS_ID = "G-8EVWSF3YH8"

ANALYTICS_TAG = f"""  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id={ANALYTICS_ID}"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){{dataLayer.push(arguments);}}
    gtag('js', new Date());
    gtag('config', '{ANALYTICS_ID}');
    gtag('set', 'anonymize_ip', true);
    gtag('set', {{'ads_data_redaction': true}});
  </script>"""

COI_TAG = '  <script src="coi-serviceworker.js"></script>'

# Only injects the width/height override — Godot's default export already
# handles background color, overflow, margin and padding
CANVAS_CSS = """  <style>
    canvas {
      width: 100% !important;
      height: 100% !important;
    }
  </style>"""

with open("docs/index.html", "r") as f:
    content = f.read()

if "googletagmanager" not in content:
    content = content.replace("<head>", "<head>\n" + ANALYTICS_TAG)
    print("Analytics tag added.")
else:
    print("Analytics tag already present.")

if COI_TAG not in content:
    content = content.replace("</head>", COI_TAG + "\n</head>")
    print("COI serviceworker tag added.")
else:
    print("COI tag already present.")

if "width: 100% !important" not in content:
    content = content.replace("</head>", CANVAS_CSS + "\n</head>")
    print("Canvas CSS added.")
else:
    print("Canvas CSS already present.")

with open("docs/index.html", "w") as f:
    f.write(content)
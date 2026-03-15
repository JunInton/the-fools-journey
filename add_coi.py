# python add_coi.py

ANALYTICS_ID = "G-8EVWSF3YH8"

ANALYTICS_TAG = f"""  <!-- Google Analytics (cookieless) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id={ANALYTICS_ID}"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){{dataLayer.push(arguments);}}
    gtag('js', new Date());
    gtag('config', '{ANALYTICS_ID}', {{
      'anonymize_ip': true,
      'storage': 'none',
      'storeGac': false
    }});
  </script>
  <!-- End Google Analytics -->"""

COI_TAG = '  <script src="coi-serviceworker.js"></script>'

with open("docs/index.html", "r") as f:
    content = f.read()

if "googletagmanager" not in content:
    content = content.replace("</head>", ANALYTICS_TAG + "\n</head>")
    print("Analytics tag added.")
else:
    print("Analytics tag already present.")

if COI_TAG not in content:
    content = content.replace("</head>", COI_TAG + "\n</head>")
    print("COI serviceworker tag added.")
else:
    print("COI tag already present.")

with open("docs/index.html", "w") as f:
    f.write(content)
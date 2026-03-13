# python add_coi.py
with open("docs/index.html", "r") as f:
    content = f.read()

tag = '<script src="coi-serviceworker.js"></script>'
if tag not in content:
    content = content.replace("</head>", f"  {tag}\n</head>")
    with open("docs/index.html", "w") as f:
        f.write(content)
    print("coi-serviceworker tag added.")
else:
    print("Tag already present, no changes made.")
import urllib.request
import json
import ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
for host in ["api.piped.projectsegfau.lt", "pipedapi.tokhmi.xyz", "pipedapi.smnz.de"]:
    url = f"https://{host}/streams/dQw4w9WgXcQ"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=5) as r:
            data = json.loads(r.read().decode())
            audios = data.get("audioStreams", [])
            if audios:
                print(host, audios[0]["url"][:30])
    except Exception as e:
        print(host, e)

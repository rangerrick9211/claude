#!/usr/bin/env python3
"""App Store Connect helper for the TestFlight workflow.

  asc.py write-key PATH            Write the API key from ASC_KEY_P8 to a .p8 file for xcodebuild.
  asc.py preflight                 Register BUNDLE_ID with Apple if needed and check the app exists.
  asc.py dev-certs F               Save the IDs of the team's development certificates to file F.
  asc.py revoke-new-dev-certs F    Revoke development certificates that aren't listed in file F.

Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 and BUNDLE_ID from the environment.
Everything but write-key needs PyJWT with its crypto extra.
"""
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
DONE = "# complete"


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(text + "\n")


def fail(message, details=""):
    print(f"::error::{message}")
    if details:
        print(details)
    summary(f"### {message}\n\n{details}")
    sys.exit(1)


def key_pem():
    raw = os.environ.get("ASC_KEY_P8", "")
    # Pasted on a phone, the line breaks often get lost or turned into spaces. Rebuild the file.
    body = re.sub(r"\s+", "", re.sub(r"-----(BEGIN|END) PRIVATE KEY-----", "", raw))
    try:
        if not body:
            raise ValueError
        base64.b64decode(body, validate=True)
    except ValueError:
        fail("ASC_KEY_P8 doesn't look like the contents of the .p8 key file.",
             "Paste the whole file, including the BEGIN and END lines.")
    lines = [body[i:i + 64] for i in range(0, len(body), 64)]
    return "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n"


def token():
    import jwt

    now = int(time.time())
    claims = {"iss": os.environ["ASC_ISSUER_ID"].strip(), "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    headers = {"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"}
    return jwt.encode(claims, key_pem(), algorithm="ES256", headers=headers)


def call(method, path, body=None):
    request = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        details = error.read().decode(errors="replace")
        if error.code in (401, 403):
            fail(f"App Store Connect turned down the API key (HTTP {error.code}).",
                 "Check ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8, and that the key has Admin access.\n\n" + details)
        fail(f"App Store Connect error {error.code} on {method} {path}.", details)


def query(params):
    return "?" + urllib.parse.urlencode(params)


def preflight():
    bundle_id = os.environ["BUNDLE_ID"]
    found = call("GET", "/bundleIds" + query({"filter[identifier]": bundle_id, "limit": 200}))["data"]
    if not any(b["attributes"]["identifier"] == bundle_id for b in found):
        call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": bundle_id, "name": os.environ.get("APP_NAME", "Heilman"), "platform": "IOS"}}})
        print(f"Registered the bundle ID {bundle_id} with Apple.")
        summary(f"Registered the bundle ID `{bundle_id}` with Apple.")

    apps = call("GET", "/apps" + query({"filter[bundleId]": bundle_id}))["data"]
    if not apps:
        fail("One step left: create the app in App Store Connect, then run this again.", "\n".join([
            "1. Open appstoreconnect.apple.com, then **Apps**, then **+** and **New App**.",
            "2. Platform **iOS**. Name: anything not already on the App Store, like *Heilman Basecamp*.",
            f"3. Bundle ID: pick **{bundle_id}**. SKU: anything, like *heilman*. Then **Create**.",
            "4. Come back here and run the workflow again.",
        ]))
    print(f"Found the App Store Connect app: {apps[0]['attributes']['name']}.")


def dev_cert_ids():
    params = {"filter[certificateType]": "DEVELOPMENT,IOS_DEVELOPMENT", "limit": 200}
    return {c["id"] for c in call("GET", "/certificates" + query(params))["data"]}


def revoke_new_dev_certs(before_path):
    try:
        lines = open(before_path).read().split("\n")
    except OSError:
        lines = []
    # Without a complete list from before the run, revoke nothing: the team's own certificates are at stake.
    if DONE not in lines:
        print("No complete certificate list from before the run, so nothing was revoked.")
        return
    before = {line for line in lines if line and line != DONE}
    for cert_id in sorted(dev_cert_ids() - before):
        call("DELETE", f"/certificates/{cert_id}")
        print(f"Revoked development certificate {cert_id}, created by this run.")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "write-key" and len(sys.argv) == 3:
        with open(sys.argv[2], "w") as f:
            f.write(key_pem())
        os.chmod(sys.argv[2], 0o600)
    elif command == "preflight":
        preflight()
    elif command == "dev-certs" and len(sys.argv) == 3:
        with open(sys.argv[2], "w") as f:
            f.write("\n".join(sorted(dev_cert_ids()) + [DONE]) + "\n")
    elif command == "revoke-new-dev-certs" and len(sys.argv) == 3:
        revoke_new_dev_certs(sys.argv[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

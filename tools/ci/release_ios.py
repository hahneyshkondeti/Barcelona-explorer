#!/usr/bin/env python3
"""Manual release workflow only. Credentials live in temporary files, never artifacts."""
import base64
import datetime
import os
from pathlib import Path
import plistlib
import secrets
import shlex
import shutil
import subprocess
import tempfile
import sys

TEAM = "SZ65B2964T"
BUNDLE = "com.hahneyshkondeti.brisa"


def run(*args, quiet=False):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE if quiet else None).stdout


def secret_file(name, path):
    value = os.environ.get(name, "")
    if not value:
        raise ValueError(f"Missing GitHub secret: {name}")
    path.write_bytes(base64.b64decode(value, validate=True))
    path.chmod(0o600)


def main():
    mode = os.environ.get("RELEASE_MODE")
    if mode not in ("archive", "upload"):
        raise ValueError("Choose archive or upload explicitly")
    if not os.environ.get("P12_PASSWORD"):
        raise ValueError("Missing GitHub secret: P12_PASSWORD")
    old_keychains = shlex.split(run("security", "list-keychains", "-d", "user", quiet=True).decode())
    installed_profile = None
    api_key = None
    with tempfile.TemporaryDirectory(prefix="brisa-signing-") as temp:
        tmp = Path(temp)
        keychain = tmp / "signing.keychain-db"
        password = secrets.token_urlsafe(32)
        try:
            certificate = tmp / "distribution.p12"
            profile = tmp / "app.mobileprovision"
            secret_file("BUILD_CERTIFICATE_BASE64", certificate)
            secret_file("BUILD_PROVISION_PROFILE_BASE64", profile)
            parsed = plistlib.loads(run("security", "cms", "-D", "-i", str(profile), quiet=True))
            entitlements = parsed["Entitlements"]
            if parsed["TeamIdentifier"] != [TEAM] or entitlements["application-identifier"] != f"{TEAM}.{BUNDLE}":
                raise ValueError("Provisioning profile must match the configured team and bundle ID")
            if parsed["ExpirationDate"] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
                raise ValueError("Provisioning profile has expired")
            if parsed.get("ProvisionedDevices") or parsed.get("ProvisionsAllDevices") or entitlements.get("get-task-allow"):
                raise ValueError("Use an App Store distribution profile")
            uuid = parsed["UUID"]
            folder = Path.home() / "Library/MobileDevice/Provisioning Profiles"
            folder.mkdir(parents=True, exist_ok=True)
            profile_target = folder / f"{uuid}.mobileprovision"
            if profile_target.exists():
                raise ValueError("Expected a clean ephemeral runner")
            shutil.copyfile(profile, profile_target)
            installed_profile = profile_target
            run("security", "create-keychain", "-p", password, str(keychain), quiet=True)
            run("security", "set-keychain-settings", "-lut", "21600", str(keychain), quiet=True)
            run("security", "unlock-keychain", "-p", password, str(keychain), quiet=True)
            run("security", "import", str(certificate), "-P", os.environ["P12_PASSWORD"], "-A", "-t", "cert", "-f", "pkcs12", "-k", str(keychain), quiet=True)
            run("security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-k", password, str(keychain), quiet=True)
            run("security", "list-keychains", "-d", "user", "-s", str(keychain), *old_keychains, quiet=True)
            run("xcodebuild", "-project", "build/ios/Brisa.xcodeproj", "-scheme", "Brisa", "-configuration", "Release", "-destination", "generic/platform=iOS", "-archivePath", "build/Brisa.xcarchive", f"DEVELOPMENT_TEAM={TEAM}", "CODE_SIGN_STYLE=Manual", "CODE_SIGN_IDENTITY=Apple Distribution", f"PROVISIONING_PROFILE_SPECIFIER={uuid}", "archive")
            options = tmp / "ExportOptions.plist"
            options.write_bytes(plistlib.dumps({"method": "app-store-connect", "destination": "export", "teamID": TEAM, "signingStyle": "manual", "signingCertificate": "Apple Distribution", "provisioningProfiles": {BUNDLE: uuid}, "manageAppVersionAndBuildNumber": False, "uploadSymbols": True}))
            run("xcodebuild", "-exportArchive", "-archivePath", "build/Brisa.xcarchive", "-exportOptionsPlist", str(options), "-exportPath", "build/ipa")
            if mode == "upload":
                key_id = os.environ.get("ASC_KEY_ID", "")
                issuer = os.environ.get("ASC_ISSUER_ID", "")
                if not key_id.isalnum() or not issuer:
                    raise ValueError("Missing or invalid ASC_KEY_ID / ASC_ISSUER_ID")
                keys = Path.home() / ".appstoreconnect/private_keys"
                keys.mkdir(parents=True, exist_ok=True)
                key_target = keys / f"AuthKey_{key_id}.p8"
                if key_target.exists():
                    raise ValueError("Expected a clean ephemeral runner")
                api_key = key_target
                secret_file("ASC_KEY_BASE64", api_key)
                ipas = list(Path("build/ipa").glob("*.ipa"))
                if len(ipas) != 1:
                    raise ValueError("Expected exactly one exported IPA")
                run("xcrun", "altool", "--upload-app", "--type", "ios", "--file", str(ipas[0]), "--apiKey", key_id, "--apiIssuer", issuer)
        finally:
            # GitHub-hosted runners are discarded as a second cleanup boundary.
            if api_key and api_key.exists():
                api_key.unlink()
            if installed_profile and installed_profile.exists():
                installed_profile.unlink()
            subprocess.run(["security", "list-keychains", "-d", "user", "-s", *old_keychains], check=False, stdout=subprocess.DEVNULL)
            if keychain.exists():
                subprocess.run(["security", "delete-keychain", str(keychain)], check=False, stdout=subprocess.DEVNULL)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        # Never include subprocess arguments: keychain commands contain passwords.
        print(f"Release command failed (exit {error.returncode}); see tool output above.", file=sys.stderr)
        sys.exit(1)

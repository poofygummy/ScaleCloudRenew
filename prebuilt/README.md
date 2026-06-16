# ScaleCloudWrap Prebuilt

Top (optional) distribution / embedding wrapper layer. It can take a fully-built App (ScaleCloudApp) artifact as its input.

## CI independent usage

Workflow: **Build ScaleCloudWrap** (testbuildSCWrap.yml)

Before you dispatch:
- Download the `ScaleCloudApp-prebuilt` artifact (or the xcarchive) from the App run you want to use.
- Manually unpack it into your clone so the payload the Wrap target needs is present under `ScaleCloudApp/prebuilt/`.
- With that tree already in place the Wrap dispatch will only run the Wrap generation + archive step. It will not run Go, Kit, or the full App layer.

## Expected handoff layout

After you (the human) manually download the App artifact from the prior run and unpack it (or copy a committed tree), the directory should contain whatever the Wrap target embeds — typically an .app bundle or xcarchive Products tree from the App layer.

**There is no supported local build for this layer.**

Wrap exists to take a fully-built App artifact (produced by the App workflow) as its input. The only place the Wrap target is generated and archived is inside the official **Build ScaleCloudWrap** GitHub Actions workflow (`testbuildSCWrap.yml`).

You (the human) materialize an App prebuilt by downloading the artifact from the prior App run's "Artifacts" section in the GitHub UI and manually unpacking its contents under `ScaleCloudApp/prebuilt/`, then you dispatch Wrap. The workflow only verifies the payload is present; it does not fetch artifacts from other runs itself.

The small `ScaleCloudWrap/project.yml` is only ever interpreted inside that GitHub job.

## When to rebuild

- After any change in Wrap sources, or
- When shipping a new App (or any lower layer that affects the embedded payload).

Nothing upstream of this layer exists in the Nextcloud ecosystem; this is a pure ScaleCloud packaging detail.

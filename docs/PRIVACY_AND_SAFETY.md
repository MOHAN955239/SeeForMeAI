# Privacy & Safety Summary

**Data flow**
- Photos: processed in memory. Never saved to disk by the app. Resized (≤1024 px for analysis) and re-encoded, which drops EXIF/location. Sent to Anthropic over HTTPS only after the user enables "Allow sending photos for analysis" and only when they request a description or ask a question about a photo.
- OCR: fully on device. Extracted text is sent remotely only if the user asks a follow-up question about it (consent required).
- Voice: Apple Speech, on-device when supported. Audio is never stored or uploaded by the app by us; transcripts are not logged.
- ElevenLabs (optional): the text to be spoken is sent over HTTPS; off by default.
- History: opt-in, off by default; summaries only; file protection enabled; delete one / clear all / "delete everything" in Settings.
- Keys: Keychain (this-device-only). The app contains no hardcoded keys. Production should use a backend proxy.
- Logging: the app writes no logs of images, transcripts, or keys.

**No compliance claims** (GDPR, HIPAA etc.) are made; none have been assessed. The third-party providers' own terms apply to data sent to them.

**Safety**
- Not certified for navigation or emergencies; no safe-route, distance, or hazard claims.
- Model instructed to describe only what is visible, flag uncertainty, and never give medical/medication assurances.
- Errors are explicit; the app does not substitute invented results.

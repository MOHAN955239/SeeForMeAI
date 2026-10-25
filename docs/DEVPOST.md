# SeeForMe AI — Devpost description
**Problem.** Blind and low-vision people constantly meet unlabeled objects, printed menus, mail and signs that screen readers can't reach.
**Solution.** A VoiceOver-first iOS app: photograph something, hear it described or read, then ask follow-ups by voice about the same image.
**How it works.** On-device Apple Vision OCR with sensible reading order and chunked playback; remote vision-language model for scene description with explicit consent; Apple Speech for push-to-talk commands; AVSpeechSynthesizer with optional ElevenLabs voice and automatic fallback; opt-in local history.
**Responsible design.** Consent before any upload, no saved images, uncertainty reported separately, no safety/navigation claims, explicit error recovery for every failure.
**Impact.** Faster independent access to everyday visual information, with privacy and honesty as defaults.
**Status.** Source complete; first Xcode build and device testing pending (see README).

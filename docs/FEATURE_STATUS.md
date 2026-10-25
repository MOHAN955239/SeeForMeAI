# Feature status for the 100-feature list

**Nothing here has been compiled or run** (no Swift toolchain in the build sandbox). "Code written" means the source exists and has unit tests written for the pure logic, not that it works on a device.

Legend: ✅ code written · 🟡 partial · ❌ not done

## 1 Vision (1-10)
1 🟡 Live scene description: photo-based only, no live video stream · 2 ✅ Find an object · 3 ✅ Where things are · 4 ✅ Color · 5 ✅ Clothing · 6 ✅ Room layout · 7 ✅ Doors/windows · 8 🟡 Personal items: lists visible items; cannot know which are yours (see My items list) · 9 ✅ Plants (caution) · 10 ✅ Animals

## 2 Reading (11-20)
11 ✅ Book · 12 ✅ Document · 13 ✅ Signs · 14 ✅ Menu · 15 ✅ Medicine label (reads text only, caution) · 16 ✅ Expiry date (local parsing) · 17 ✅ Bill · 18 ✅ Receipt · 19 ✅ Handwriting (model-based, marks [unclear]) · 20 ✅ Summarizer (OCR on device, only text sent)

## 3 Navigation (21-30)
21 🟡 Route overview with step-by-step reading, **not live turn-by-turn** · 22 ✅ Where am I · 23 ✅ Nearby mapped places · 24 ✅ Bus stop · 25 ✅ Bus number · 26 ✅ Platform sign · 27 ✅ Crossing signal (experimental, never says safe) · 28 ✅ Entrance finder (experimental) · 29 ❌ Indoor guidance (needs venue maps or beacons) · 30 ❌ Accessible route finder (MapKit walking routes expose no accessibility filter)

## 4 Safety (31-40)
31 ✅ · 32 ✅ · 33 ✅ · 34 ✅ · 35 ✅ · 36 ✅ (all experimental with spoken caution) · 37 ✅ Emergency call (asks to confirm; number configurable, default 112) · 38 🟡 Trusted contact: pre-filled SMS, you press send; no automatic alerts · 39 ✅ Location message, user-sent · 40 ✅ Uncertainty is a separate field plus cautions

## 5 Shopping (41-50)
41 ✅ · 42 ✅ Barcode (on-device scan, Open Food Facts lookup, community data) · 43 ✅ · 44 ✅ Shopping list by voice/text · 45 ❌ Product comparison (needs two-photo flow) · 46 ✅ · 47 ✅ Currency (caution) · 48 ✅ · 49 ✅ · 50 ✅ Budget list with total

## 6 Kitchen (51-60)
51 ✅ · 52 ✅ · 53 ✅ · 54 ✅ Recipe · 55 ✅ Next/previous/repeat step by voice · 56 ✅ Timers · 57 ✅ · 58 ✅ · 59 ✅ Pantry is a manual list · 60 🟡 Read lists aloud; no automatic "missing ingredients" logic

## 7 Communication (61-70)
61 🟡 Voice control in Ask a Question and the commands it knows, not the whole app · 62 🟡 Speech-to-text only inside Ask · 63 ✅ · 64 🟡 Photo text translation only · 65 🟡 Depends on iPhone voices · 66 🟡 Kannada selectable, recognition/voice support not verified · 67 ❌ iOS does not let apps read other apps' notifications · 68 ❌ · 69 ✅ Contact lookup, reads the number digit by digit (Contacts permission) · 70 ✅ Share button on scene and tool results

## 8 Education (71-80)
71 ✅ · 72 🟡 PDF reader: text layer only; scanned PDFs are not OCR'd · 73 ✅ · 74 ✅ · 75 ✅ · 76 ✅ · 77 ✅ · 78 ✅ · 79 ✅ · 80 ✅ (choose a screenshot from Photos)

## 9 Organization (81-90)
81 🟡 Relative reminders only ("in 20 minutes") · 82 ✅ Reads next 24 hours of events · 83 ✅ · 84 ✅ · 85 ❌ · 86 🟡 Via "what's on my calendar" · 87 ❌ Weather (needs a weather service) · 88 🟡 In-app timers, no system alarms · 89 🟡 Daily briefing: events, timers, shopping list; no weather · 90 ✅ Favorites on Home

## 10 Accessibility (91-100)
91 ✅ written, **VoiceOver never tested** · 92 ✅ · 93 🟡 Dark high-contrast theme, no separate toggle · 94 ✅ built-in voice speed · 95 🟡 Language and ElevenLabs voice ID; no system voice picker · 96 ✅ · 97 ✅ · 98 ✅ · 99 ✅ · 100 🟡 Settings persist; no named profiles

## Extras suggested earlier
✅ Photo-quality coach (after capture; thresholds are untuned guesses) · ✅ Detail level · ✅ Favorites · ✅ Vibration feedback · 🟡 Indian languages · ❌ Auto-capture guidance · ❌ Siri/App Intents · ❌ Lock-screen widget · ❌ Braille output · ❌ Earcons · ❌ Share extension · ❌ Privacy dashboard · ❌ Report-wrong-answer · ❌ Saved places · ❌ Sighted-helper call

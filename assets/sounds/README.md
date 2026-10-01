# Sound Assets for Attendance Scanner

This directory contains sound effects for different scan states.

## Required Sound Files

You need to add the following sound files to this directory:

1. **success.mp3** - Played when a valid student code is scanned successfully
   - Suggested: Pleasant "ding" or "success" sound (250-500ms)
   - Example: High-pitched beep, chime, or positive tone

2. **error.mp3** - Played when an unknown/invalid code is scanned
   - Suggested: Error buzzer or negative sound (250-500ms)
   - Example: Low-pitched buzz, error tone, or "invalid" sound

3. **duplicate.mp3** - Played when a student is scanned twice (already attended)
   - Suggested: Warning beep or neutral alert (250-500ms)
   - Example: Double beep, warning tone, or "already scanned" sound

## Where to Get Sound Files

### Free Sound Resources:
1. **Freesound.org** - https://freesound.org
   - Search for: "beep", "success", "error", "alert"
   - Filter by: Short duration (< 1 second), MP3 format

2. **Zapsplat.com** - https://www.zapsplat.com
   - UI sound effects section
   - Notification sounds

3. **Mixkit.co** - https://mixkit.co/free-sound-effects/
   - Free sound effects library

4. **Generate Your Own** using online tools:
   - Bfxr.net - Simple retro sound generator
   - Sfxr.me - Browser-based sound effect generator

### Recommended Specifications:
- **Format:** MP3 (best compatibility)
- **Duration:** 250-500ms (short and snappy)
- **File Size:** < 50KB each
- **Sample Rate:** 44.1kHz or 48kHz
- **Bit Rate:** 128kbps or higher

## Example Sounds You Can Use:

### Success Sound:
- Search: "success notification", "positive beep", "chime"
- Tone: High, pleasant, uplifting

### Error Sound:
- Search: "error buzz", "negative beep", "wrong sound"
- Tone: Low, harsh, attention-grabbing

### Duplicate Sound:
- Search: "warning beep", "alert notification", "already scanned"
- Tone: Medium, neutral, informative

## Testing

After adding the sound files, the app will automatically play them when:
- ✅ **Success**: Valid student scanned
- ❌ **Error**: Unknown code detected
- ⚠️ **Duplicate**: Student already marked present

## Current Status

🔴 **Sound files not yet added** - App will run without sounds until you add them.

Once you add the sound files, rebuild the app and they'll work automatically!

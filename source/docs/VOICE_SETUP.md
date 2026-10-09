# Voice chat setup (client side ready, server not configured)

v3 ships only the **client half** of proximity voice chat. There is no voice server yet, so in game:

* **V** (D-pad down on a gamepad) is push-to-talk. Holding it asks for the microphone on the first use
  (web: browser permission prompt via `getUserMedia`; desktop: `AudioStreamMicrophone` + `AudioEffectCapture`
  when audio input is enabled in the project) and shows the mic indicator with a live level meter.
* With no server configured the indicator says **"Voice server not configured"** (or "mic unavailable"/"mic denied")
  instead of erroring. Nothing is sent anywhere.
* **L** opens the voice panel: connection status and a per-player mute list (stored in Settings; demo entries
  "Neighbor 1-3" until real peers exist).
* `VoiceClient.peer_volume(name, speaker_pos, listener_pos)` already implements proximity attenuation
  (full volume within `full_volume_distance`, silent beyond `silent_distance`, quadratic fall-off) and mutes.

Code: `scripts/autoload/voice_client.gd` (autoload `VoiceClient`), UI in `scripts/ui/voice_hud.gd`.

## Config: `data/voice_config.json`

```json
{
  "livekit_url": "",            // e.g. "wss://voice.example.com"
  "token_endpoint": "",         // HTTPS endpoint of YOUR backend that returns a short-lived room token
  "room": "farm-town",
  "turn": { "urls": "turns:YOUR-TURN-HOST:443?transport=tcp", "username": "", "credential": "" },
  "proximity": { "full_volume_distance": 3.0, "silent_distance": 25.0 }
}
```

`VoiceClient.is_configured()` is true only when both `livekit_url` and `token_endpoint` are set.

**Never put API keys or secrets in this file**: it is shipped inside the game (and the web `.pck` is public).
Room tokens must be minted server-side.

## Wiring a real server (planned, see docs/MULTIPLAYER_PLAN.md)

1. Run an SFU: **LiveKit** (self-hosted `livekit-server` or LiveKit Cloud). An SFU scales better than a WebRTC mesh
   once more than ~4 players are near each other.
2. Run a TURN server reachable on **443/TCP+TLS** (coturn, or LiveKit's embedded TURN) so players behind strict
   NAT / corporate firewalls can connect.
3. Add a tiny token service (`POST /voice-token {player, room}` -> LiveKit JWT, 10 min TTL) behind the game's login.
4. Client transport:
   * **Web:** load `livekit-client` JS in the export's HTML shell and bridge it through `JavaScriptBridge`
     (join room, publish mic track while PTT is held, set per-participant volume from `peer_volume()`).
   * **Desktop:** use a GDExtension WebRTC build (`webrtc-native`) or a LiveKit native SDK bridge.
5. Each frame, for every remote participant: volume = `VoiceClient.peer_volume(name, their_avatar_pos, my_pos)`.
6. Fill in `livekit_url` / `token_endpoint` in `data/voice_config.json`; the HUD switches from
   "not configured" to connection states automatically.

Privacy: push-to-talk only (no open mic), the mic is requested lazily on first PTT, and mutes are local.

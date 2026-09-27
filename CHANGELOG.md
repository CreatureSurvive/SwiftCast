# Changelog

## 1.0.1

- `CastClient.disconnect()` no longer sends `CLOSE` to application connections. Web receivers
  treat an explicit `CLOSE` from their last sender as a shutdown request, so disconnecting used
  to stop playback on the TV.
- Fixed a race where `MediaController` could re-apply a stale reply to its own `GET_STATUS`
  after a newer `LOAD`, clearing the media session.
- Fixed a race where `CastSession` could attach two media controllers to one application when a
  load overlapped a receiver status update.
- `castctl play` now follows status for a few seconds and prints idle reasons.

## 1.0.0

- Initial release: Cast V2 protocol client, Bonjour discovery, receiver and media controllers,
  queue and track support, custom namespaces, observable `CastSession` with automatic
  reconnection, SwiftUI `CastButton`/`CastDevicePicker`, and the `castctl` CLI.

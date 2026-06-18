// lib/enums/media_preload_mode.dart
//
// Controls whether the chat image preloader proactively downloads media around
// the open viewport so it's ready before the user scrolls to it.
//   • off      — never warm; media downloads on demand when its widget builds.
//   • wifiOnly — warm only on Wi-Fi / ethernet (default); mobile data stays on
//                demand to save the user's data plan.
//   • always   — warm on any connection.
enum MediaPreloadMode { off, wifiOnly, always }

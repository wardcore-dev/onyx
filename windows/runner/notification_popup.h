#ifndef NOTIFICATION_POPUP_H
#define NOTIFICATION_POPUP_H

#include <string>
#include <functional>
#include <vector>
#include <cstdint>
#include <windows.h>

// Initialize notification system (GDI+, window class)
void InitializeNotificationPopup();

// Show a Material Design 3 desktop notification popup.
//
//  surfaceColor          – card background hex, e.g. "1c1b1f"
//  onSurfaceColor        – primary text color hex, e.g. "e6e1e5"
//  onSurfaceVariantColor – secondary (message) text color hex, e.g. "cac4d0"
//  avatarColor           – avatar circle background hex (= colorScheme.primaryContainer)
//  avatarLetterColor     – avatar letter color hex (= colorScheme.onPrimaryContainer)
//  primaryColor          – MD3 primary color (reserved)
//  messageColor          – text color for message body: primary for media, onSurfaceVariant for text
void ShowNotificationPopup(
    const std::string& username,
    const std::string& displayName,
    const std::string& message,
    DWORD              displayDurationMs,
    const std::string& surfaceColor          = "1c1b1f",
    const std::string& onSurfaceColor        = "e6e1e5",
    const std::string& onSurfaceVariantColor = "cac4d0",
    const std::string& avatarColor           = "4a6741",
    const std::string& avatarLetterColor     = "ffffff",
    const std::string& primaryColor          = "d39aff",
    const std::string& messageColor          = "cac4d0",
    const std::string& position             = "bottom_right");

// Update the current popup with the real avatar image bytes (PNG/JPEG).
// Safe to call from the platform (main) thread at any time while popup is visible.
void UpdateNotificationAvatar(const std::vector<uint8_t>& bytes);

// Fade out and close the current popup
void CloseNotificationPopup();

// Register a callback invoked when the user taps the popup
void SetOnNotificationTapped(std::function<void(const std::string&)> callback);

#endif // NOTIFICATION_POPUP_H

#include "notification_popup.h"
#include <windows.h>
#include <gdiplus.h>
#include <objidl.h>       // IStream / CreateStreamOnHGlobal
#include <sstream>
#include <iomanip>
#include <cwctype>
#include <cstring>
#include <algorithm>
#include <mutex>
#include <vector>

#pragma comment(lib, "gdiplus.lib")
using namespace Gdiplus;

// ── Window class ─────────────────────────────────────────────────────────────
static const wchar_t NOTIFICATION_CLASS[] = L"OnyxNotificationWindowMD3";

// ── Logical dimensions (DPI-scaled at runtime) ────────────────────────────────
static const int   NOTIFICATION_WIDTH  = 380;
static const int   NOTIFICATION_HEIGHT = 104;
static const float CORNER_RADIUS       = 12.0f;

static const int AVATAR_SIZE = 48;
static const int AVATAR_X    = 14;
static const int AVATAR_Y    = (NOTIFICATION_HEIGHT - AVATAR_SIZE) / 2; // = 28
static const int TEXT_X      = AVATAR_X + AVATAR_SIZE + 12;             // = 74

// ── Close button (top-right corner) ──────────────────────────────────────────
static const int CLOSE_BTN_SIZE   = 20;  // hit-area side
static const int CLOSE_BTN_MARGIN = 6;   // from card edges
static const int CLOSE_BTN_X     = NOTIFICATION_WIDTH  - CLOSE_BTN_SIZE - CLOSE_BTN_MARGIN; // 354
static const int CLOSE_BTN_Y     = CLOSE_BTN_MARGIN;                                        //   6

// Text area must not overlap the close button
static const int TEXT_RIGHT = CLOSE_BTN_X - 4;                          // = 350

// ── Animation timers ─────────────────────────────────────────────────────────
static const UINT TIMER_FADEIN  = 1;
static const UINT TIMER_DISPLAY = 2;
static const UINT TIMER_FADEOUT = 3;
static const int  FADE_STEP     = 22;   // opacity per tick
static const int  FADE_TICK_MS  = 16;   // ~60 fps

// ── DPI scale ────────────────────────────────────────────────────────────────
static float g_scale = 1.0f;

static inline int   S(int v)   { return (int)(v * g_scale + 0.5f); }
static inline float SF(float v){ return v * g_scale; }

// ── Theme / data structs ──────────────────────────────────────────────────────
struct ThemeColors {
    COLORREF surface;
    COLORREF onSurface;
    COLORREF onSurfaceVariant;
    COLORREF avatarBg;
    COLORREF avatarLetter;
    COLORREF messageText;   // primary for media, onSurfaceVariant for plain text
};

struct NotificationData {
    std::string username;
    std::string displayName;
    std::string message;
    DWORD       displayDurationMs;
    ThemeColors colors;
};

// ── Avatar image (set by UpdateNotificationAvatar on main thread) ─────────────
static std::mutex        g_avatarMutex;
static Gdiplus::Bitmap*  g_avatarBitmap = nullptr;

// ── Global state ──────────────────────────────────────────────────────────────
static HWND         g_notificationWindow = nullptr;
static ULONG_PTR    g_gdiplusToken       = 0;
static int          g_currentOpacity     = 0;
static bool         g_fadingOut          = false;
static NotificationData g_currentData;

static std::function<void(const std::string&)> g_onTapped = nullptr;
static bool g_closeHover = false;  // true while mouse is over the close button

// ── Forward declarations ──────────────────────────────────────────────────────
LRESULT CALLBACK NotificationWndProc(HWND, UINT, WPARAM, LPARAM);
std::wstring     AnsiToWide(const std::string&);

static inline bool IsInCloseButton(int mx, int my) {
    return mx >= S(CLOSE_BTN_X) && mx <= S(CLOSE_BTN_X + CLOSE_BTN_SIZE) &&
           my >= S(CLOSE_BTN_Y) && my <= S(CLOSE_BTN_Y + CLOSE_BTN_SIZE);
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

COLORREF HexToColorref(const std::string& hex) {
    std::string h = hex;
    if (!h.empty() && h[0] == '#') h = h.substr(1);
    if (h.length() == 8)           h = h.substr(2); // strip alpha
    if (h.length() < 6)            return RGB(28, 27, 31);
    int r = std::stoi(h.substr(0, 2), nullptr, 16);
    int g = std::stoi(h.substr(2, 2), nullptr, 16);
    int b = std::stoi(h.substr(4, 2), nullptr, 16);
    return RGB(r, g, b);
}

static inline Color GC(COLORREF c, BYTE a = 255) {
    return Color(a, GetRValue(c), GetGValue(c), GetBValue(c));
}

static void MakeRoundRect(GraphicsPath& path,
                           float x, float y, float w, float h, float r) {
    float d = r * 2.0f;
    path.AddArc(x,         y,         d, d, 180.0f, 90.0f);
    path.AddArc(x + w - d, y,         d, d, 270.0f, 90.0f);
    path.AddArc(x + w - d, y + h - d, d, d,   0.0f, 90.0f);
    path.AddArc(x,         y + h - d, d, d,  90.0f, 90.0f);
    path.CloseFigure();
}

// Decode a GDI+ Bitmap from raw bytes (PNG/JPEG/etc.)
static Gdiplus::Bitmap* DecodeBitmapFromBytes(const std::vector<uint8_t>& bytes) {
    if (bytes.empty()) return nullptr;

    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes.size());
    if (!hMem) return nullptr;

    void* ptr = GlobalLock(hMem);
    if (!ptr) { GlobalFree(hMem); return nullptr; }
    memcpy(ptr, bytes.data(), bytes.size());
    GlobalUnlock(hMem);

    IStream* pStream = nullptr;
    if (FAILED(CreateStreamOnHGlobal(hMem, TRUE, &pStream))) {
        GlobalFree(hMem);
        return nullptr;
    }

    Gdiplus::Bitmap* bmp = Gdiplus::Bitmap::FromStream(pStream);
    pStream->Release(); // also frees hMem (fDeleteOnRelease = TRUE)

    if (!bmp || bmp->GetLastStatus() != Gdiplus::Ok) {
        delete bmp;
        return nullptr;
    }
    return bmp;
}

// ────────────────────────────────────────────────────────────────────────────
// Core renderer
// ────────────────────────────────────────────────────────────────────────────
static void UpdateLayeredContent(HWND hwnd, BYTE opacity) {
    const int W  = S(NOTIFICATION_WIDTH);
    const int H  = S(NOTIFICATION_HEIGHT);
    const int RW = W * 2;   // 2× supersampling — renders at double resolution
    const int RH = H * 2;   // then scales down → no pixelation on text/edges

    // Render into oversized bitmap at 2× resolution
    Bitmap hiBmp(RW, RH, PixelFormat32bppARGB);
    {
        Graphics g(&hiBmp);
        g.SetSmoothingMode(SmoothingModeAntiAlias);
        g.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
        g.Clear(Color(0, 0, 0, 0));
        // Every SF()/S() coordinate is already in DPI-logical pixels;
        // ScaleTransform doubles them into the 2× bitmap space automatically.
        g.ScaleTransform(2.0f, 2.0f);

        float cr  = SF(CORNER_RADIUS);

        // ── Card background ───────────────────────────────────────────────
        {
            GraphicsPath path;
            MakeRoundRect(path, 0.0f, 0.0f, (float)W, (float)H, cr);
            SolidBrush bg(GC(g_currentData.colors.surface));
            g.FillPath(&bg, &path);
        }

        // ── Avatar (circle) ───────────────────────────────────────────────
        {
            float ax  = SF((float)AVATAR_X);
            float ay  = SF((float)AVATAR_Y);
            float as_ = SF((float)AVATAR_SIZE);
            float ar  = as_ / 2.0f; // full circle

            std::lock_guard<std::mutex> lock(g_avatarMutex);

            if (g_avatarBitmap != nullptr) {
                // Real avatar image — clipped to circle
                GraphicsPath clip;
                MakeRoundRect(clip, ax, ay, as_, as_, ar);
                Region clipRgn(&clip);
                g.SetClip(&clipRgn);
                g.DrawImage(g_avatarBitmap, ax, ay, as_, as_);
                g.ResetClip();
            } else {
                // Default: colored circle + letter
                GraphicsPath avatarPath;
                MakeRoundRect(avatarPath, ax, ay, as_, as_, ar);
                SolidBrush avatarBg(GC(g_currentData.colors.avatarBg));
                g.FillPath(&avatarBg, &avatarPath);

                std::wstring letter = L"?";
                if (!g_currentData.displayName.empty()) {
                    std::wstring wide = AnsiToWide(g_currentData.displayName);
                    letter = std::wstring(1, (wchar_t)towupper(wide[0]));
                }
                Font       lf(L"Segoe UI", SF(20.0f), FontStyleBold, UnitPixel);
                SolidBrush lc(GC(g_currentData.colors.avatarLetter));
                RectF      lr(ax, ay, as_, as_);
                StringFormat sf;
                sf.SetAlignment(StringAlignmentCenter);
                sf.SetLineAlignment(StringAlignmentCenter);
                g.DrawString(letter.c_str(), -1, &lf, lr, &sf, &lc);
            }
        }

        // ── Display name (bold 16 px) ─────────────────────────────────────
        {
            float tx = SF((float)TEXT_X);
            float tw = SF((float)(TEXT_RIGHT - TEXT_X));

            Font       nf(L"Segoe UI", SF(16.0f), FontStyleBold, UnitPixel);
            SolidBrush nc(GC(g_currentData.colors.onSurface));
            RectF      nr(tx, SF(20.0f), tw, SF(26.0f));
            StringFormat sf;
            sf.SetAlignment(StringAlignmentNear);
            sf.SetLineAlignment(StringAlignmentCenter);
            sf.SetTrimming(StringTrimmingEllipsisCharacter);
            sf.SetFormatFlags(StringFormatFlagsNoWrap);
            g.DrawString(AnsiToWide(g_currentData.displayName).c_str(), -1,
                         &nf, nr, &sf, &nc);
        }

        // ── Message (regular 14 px, messageText color) ────────────────────
        {
            float tx = SF((float)TEXT_X);
            float tw = SF((float)(TEXT_RIGHT - TEXT_X));

            Font       mf(L"Segoe UI", SF(14.0f), FontStyleRegular, UnitPixel);
            SolidBrush mc(GC(g_currentData.colors.messageText));
            RectF      mr(tx, SF(50.0f), tw, SF((float)(NOTIFICATION_HEIGHT - 10 - 50)));
            StringFormat sf;
            sf.SetAlignment(StringAlignmentNear);
            sf.SetLineAlignment(StringAlignmentNear);
            sf.SetTrimming(StringTrimmingEllipsisCharacter);
            g.DrawString(AnsiToWide(g_currentData.message).c_str(), -1,
                         &mf, mr, &sf, &mc);
        }

        // ── Close button (×) top-right ────────────────────────────────────
        {
            float bx  = SF((float)CLOSE_BTN_X);
            float by  = SF((float)CLOSE_BTN_Y);
            float bs  = SF((float)CLOSE_BTN_SIZE);
            float pad = SF(5.5f);  // inset from button edges to × endpoints

            // Hover: semi-transparent fill circle
            if (g_closeHover) {
                SolidBrush hoverBg(GC(g_currentData.colors.onSurfaceVariant, 35));
                g.FillEllipse(&hoverBg, bx, by, bs, bs);
            }

            // × drawn as two diagonal lines
            Pen xPen(GC(g_currentData.colors.onSurfaceVariant, 180), SF(1.6f));
            xPen.SetStartCap(LineCapRound);
            xPen.SetEndCap(LineCapRound);
            g.DrawLine(&xPen, bx + pad, by + pad, bx + bs - pad, by + bs - pad);
            g.DrawLine(&xPen, bx + bs - pad, by + pad, bx + pad, by + bs - pad);
        }
    }

    // Scale 2×→1× with high-quality bicubic — this is what gives sharp edges
    // and smooth anti-aliased text in the final layered window.
    Bitmap bmp(W, H, PixelFormat32bppARGB);
    {
        Graphics g2(&bmp);
        g2.SetInterpolationMode(InterpolationModeHighQualityBilinear);
        g2.SetSmoothingMode(SmoothingModeHighQuality);
        g2.Clear(Color(0, 0, 0, 0));
        g2.DrawImage(&hiBmp, 0, 0, W, H);
    }

    // ── Premultiply alpha → UpdateLayeredWindow ───────────────────────────
    BitmapData bmpData;
    Rect lockRect(0, 0, W, H);
    if (bmp.LockBits(&lockRect,
                     ImageLockModeRead | ImageLockModeWrite,
                     PixelFormat32bppARGB, &bmpData) != Ok) return;

    BYTE* row0 = static_cast<BYTE*>(bmpData.Scan0);
    for (int y = 0; y < H; y++) {
        BYTE* p = row0 + y * bmpData.Stride;
        for (int x = 0; x < W; x++, p += 4) {
            BYTE a = p[3];
            p[0] = (BYTE)((DWORD)p[0] * a / 255u); // B
            p[1] = (BYTE)((DWORD)p[1] * a / 255u); // G
            p[2] = (BYTE)((DWORD)p[2] * a / 255u); // R
        }
    }

    BITMAPINFO bi = {};
    bi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth       =  W;
    bi.bmiHeader.biHeight      = -H;
    bi.bmiHeader.biPlanes      = 1;
    bi.bmiHeader.biBitCount    = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    HDC     hdcScreen = GetDC(nullptr);
    HDC     hdcMem    = CreateCompatibleDC(hdcScreen);
    BYTE*   pvDIB     = nullptr;
    HBITMAP hDIB      = CreateDIBSection(hdcScreen, &bi, DIB_RGB_COLORS,
                                          (void**)&pvDIB, nullptr, 0);
    HBITMAP hOld      = (HBITMAP)SelectObject(hdcMem, hDIB);

    for (int y = 0; y < H; y++) {
        memcpy(pvDIB + y * W * 4,
               row0  + y * bmpData.Stride,
               (size_t)W * 4);
    }

    bmp.UnlockBits(&bmpData);

    RECT  wr;
    GetWindowRect(hwnd, &wr);
    POINT ptSrc = {0, 0};
    SIZE  szWnd = {W, H};
    POINT ptDst = {wr.left, wr.top};
    BLENDFUNCTION blend = {AC_SRC_OVER, 0, opacity, AC_SRC_ALPHA};
    UpdateLayeredWindow(hwnd, hdcScreen, &ptDst, &szWnd,
                        hdcMem, &ptSrc, 0, &blend, ULW_ALPHA);

    SelectObject(hdcMem, hOld);
    DeleteObject(hDIB);
    DeleteDC(hdcMem);
    ReleaseDC(nullptr, hdcScreen);
}

// ────────────────────────────────────────────────────────────────────────────
// Window procedure
// ────────────────────────────────────────────────────────────────────────────
LRESULT CALLBACK NotificationWndProc(HWND hwnd, UINT msg,
                                      WPARAM wParam, LPARAM lParam) {
    switch (msg) {

        case WM_TIMER: {
            if (wParam == TIMER_FADEIN) {
                g_currentOpacity = (std::min)(g_currentOpacity + FADE_STEP, 255);
                UpdateLayeredContent(hwnd, (BYTE)g_currentOpacity);
                if (g_currentOpacity >= 255) {
                    KillTimer(hwnd, TIMER_FADEIN);
                    SetTimer(hwnd, TIMER_DISPLAY,
                             g_currentData.displayDurationMs, nullptr);
                }
            } else if (wParam == TIMER_DISPLAY) {
                KillTimer(hwnd, TIMER_DISPLAY);
                g_fadingOut = true;
                SetTimer(hwnd, TIMER_FADEOUT, FADE_TICK_MS, nullptr);
            } else if (wParam == TIMER_FADEOUT) {
                g_currentOpacity = (std::max)(g_currentOpacity - FADE_STEP, 0);
                UpdateLayeredContent(hwnd, (BYTE)g_currentOpacity);
                if (g_currentOpacity <= 0) {
                    KillTimer(hwnd, TIMER_FADEOUT);
                    ShowWindow(hwnd, SW_HIDE);
                    DestroyWindow(hwnd);
                }
            }
            return 0;
        }

        case WM_LBUTTONUP: {
            int mx = (int)(short)LOWORD(lParam);
            int my = (int)(short)HIWORD(lParam);
            if (IsInCloseButton(mx, my)) {
                // Close without firing the tap callback
            } else {
                if (g_onTapped) g_onTapped(g_currentData.username);
            }
            KillTimer(hwnd, TIMER_FADEIN);
            KillTimer(hwnd, TIMER_DISPLAY);
            KillTimer(hwnd, TIMER_FADEOUT);
            ShowWindow(hwnd, SW_HIDE);
            DestroyWindow(hwnd);
            return 0;
        }

        case WM_MOUSEMOVE: {
            int mx = (int)(short)LOWORD(lParam);
            int my = (int)(short)HIWORD(lParam);
            bool hover = IsInCloseButton(mx, my);
            if (hover != g_closeHover) {
                g_closeHover = hover;
                if (g_currentOpacity > 0)
                    UpdateLayeredContent(hwnd, (BYTE)g_currentOpacity);
                if (hover) {
                    TRACKMOUSEEVENT tme = {};
                    tme.cbSize    = sizeof(tme);
                    tme.dwFlags   = TME_LEAVE;
                    tme.hwndTrack = hwnd;
                    TrackMouseEvent(&tme);
                }
            }
            return 0;
        }

        case WM_MOUSELEAVE: {
            if (g_closeHover) {
                g_closeHover = false;
                if (g_currentOpacity > 0)
                    UpdateLayeredContent(hwnd, (BYTE)g_currentOpacity);
            }
            return 0;
        }

        case WM_SETCURSOR: {
            POINT pt;
            GetCursorPos(&pt);
            ScreenToClient(hwnd, &pt);
            SetCursor(LoadCursor(nullptr,
                IsInCloseButton(pt.x, pt.y) ? IDC_ARROW : IDC_HAND));
            return 1;
        }

        case WM_DESTROY: {
            std::lock_guard<std::mutex> lock(g_avatarMutex);
            delete g_avatarBitmap;
            g_avatarBitmap       = nullptr;
            g_notificationWindow = nullptr;
            g_currentOpacity     = 0;
            g_fadingOut          = false;
            g_closeHover         = false;
            return 0;
        }

        case WM_NCHITTEST:  return HTCLIENT;
        case WM_ERASEBKGND: return 1;

        default:
            return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
}

// ────────────────────────────────────────────────────────────────────────────
// Public API
// ────────────────────────────────────────────────────────────────────────────

void InitializeNotificationPopup() {
    if (g_gdiplusToken == 0) {
        GdiplusStartupInput gsi;
        GdiplusStartup(&g_gdiplusToken, &gsi, nullptr);
    }

    WNDCLASSW wc_check = {};
    if (!GetClassInfoW(GetModuleHandleW(nullptr), NOTIFICATION_CLASS, &wc_check)) {
        WNDCLASSW wc     = {};
        wc.lpfnWndProc   = NotificationWndProc;
        wc.lpszClassName = NOTIFICATION_CLASS;
        wc.hbrBackground = nullptr;
        wc.hCursor       = LoadCursor(nullptr, IDC_HAND);
        wc.hInstance     = GetModuleHandleW(nullptr);
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        if (!RegisterClassW(&wc))
            OutputDebugStringW(L"[Notification] Failed to register class\n");
    }
}

void ShowNotificationPopup(
    const std::string& username,
    const std::string& displayName,
    const std::string& message,
    DWORD              displayDurationMs,
    const std::string& surfaceColor,
    const std::string& onSurfaceColor,
    const std::string& onSurfaceVariantColor,
    const std::string& avatarColor,
    const std::string& avatarLetterColor,
    const std::string& primaryColor,
    const std::string& messageColor,
    const std::string& position)
{
    InitializeNotificationPopup();

    // ── DPI scale ─────────────────────────────────────────────────────────
    {
        HDC hdcTmp = GetDC(nullptr);
        int dpiX   = GetDeviceCaps(hdcTmp, LOGPIXELSX);
        ReleaseDC(nullptr, hdcTmp);
        g_scale = (dpiX > 0) ? (dpiX / 96.0f) : 1.0f;
    }

    // ── Theme colors ──────────────────────────────────────────────────────
    g_currentData.colors.surface   = HexToColorref(surfaceColor);
    g_currentData.colors.onSurface = HexToColorref(onSurfaceColor);
    g_currentData.colors.avatarBg  = HexToColorref(avatarColor);
    g_currentData.colors.avatarLetter = HexToColorref(avatarLetterColor);

    if (!onSurfaceVariantColor.empty() && onSurfaceVariantColor != "none") {
        g_currentData.colors.onSurfaceVariant = HexToColorref(onSurfaceVariantColor);
    } else {
        COLORREF os = g_currentData.colors.onSurface;
        g_currentData.colors.onSurfaceVariant = RGB(
            (BYTE)(GetRValue(os) * 85u / 100u),
            (BYTE)(GetGValue(os) * 85u / 100u),
            (BYTE)(GetBValue(os) * 85u / 100u));
    }

    // Message body color: explicit override from Dart, or fall back to onSurfaceVariant
    if (!messageColor.empty() && messageColor != "none") {
        g_currentData.colors.messageText = HexToColorref(messageColor);
    } else {
        g_currentData.colors.messageText = g_currentData.colors.onSurfaceVariant;
    }

    // ── Data ──────────────────────────────────────────────────────────────
    g_currentData.username          = username;
    g_currentData.displayName       = displayName;
    g_currentData.message           = message;
    g_currentData.displayDurationMs = displayDurationMs;

    // ── Clear old avatar ──────────────────────────────────────────────────
    {
        std::lock_guard<std::mutex> lock(g_avatarMutex);
        delete g_avatarBitmap;
        g_avatarBitmap = nullptr;
    }

    // ── Compute position (always, so reuse gets updated coords too) ──────
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int W = S(NOTIFICATION_WIDTH);
    int H = S(NOTIFICATION_HEIGHT);
    // Позиция popup по настройке: top_left / top_right / bottom_left / bottom_right
    bool isRight  = (position != "top_left"  && position != "bottom_left");
    bool isBottom = (position != "top_left"  && position != "top_right");
    int x = isRight  ? (screenW - W - S(16)) : S(16);
    int y = isBottom ? (screenH - H - S(72)) : S(16);

    // ── Create or reuse window ────────────────────────────────────────────
    if (g_notificationWindow == nullptr) {
        g_notificationWindow = CreateWindowExW(
            WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
            WS_EX_NOACTIVATE | WS_EX_LAYERED,
            NOTIFICATION_CLASS, L"",
            WS_POPUP,
            x, y, W, H,
            nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);

        if (g_notificationWindow == nullptr) {
            OutputDebugStringW(L"[Notification] Failed to create window\n");
            return;
        }
    } else {
        KillTimer(g_notificationWindow, TIMER_FADEIN);
        KillTimer(g_notificationWindow, TIMER_DISPLAY);
        KillTimer(g_notificationWindow, TIMER_FADEOUT);
        // Обновляем позицию при повторном показе
        SetWindowPos(g_notificationWindow, HWND_TOPMOST,
                     x, y, W, H,
                     SWP_NOACTIVATE | SWP_NOSIZE);
    }

    // ── Fade in ───────────────────────────────────────────────────────────
    g_currentOpacity = 0;
    g_fadingOut      = false;
    UpdateLayeredContent(g_notificationWindow, 0);
    ShowWindow(g_notificationWindow, SW_SHOWNOACTIVATE);
    SetTimer(g_notificationWindow, TIMER_FADEIN, FADE_TICK_MS, nullptr);
}

// Called from Dart after downloading the avatar image.
// Decodes the bytes and re-renders the current notification with the image.
void UpdateNotificationAvatar(const std::vector<uint8_t>& bytes) {
    if (bytes.empty() || g_notificationWindow == nullptr) return;

    Gdiplus::Bitmap* bmp = DecodeBitmapFromBytes(bytes);
    if (!bmp) return;

    {
        std::lock_guard<std::mutex> lock(g_avatarMutex);
        delete g_avatarBitmap;
        g_avatarBitmap = bmp;
    }

    // Re-render at current opacity (window is still visible)
    if (g_currentOpacity > 0) {
        UpdateLayeredContent(g_notificationWindow, (BYTE)g_currentOpacity);
    }
}

void CloseNotificationPopup() {
    if (g_notificationWindow == nullptr) return;
    if (g_fadingOut)               return;

    KillTimer(g_notificationWindow, TIMER_FADEIN);
    KillTimer(g_notificationWindow, TIMER_DISPLAY);
    g_fadingOut = true;
    SetTimer(g_notificationWindow, TIMER_FADEOUT, FADE_TICK_MS, nullptr);
}

void SetOnNotificationTapped(std::function<void(const std::string&)> callback) {
    g_onTapped = callback;
}

// UTF-8 → wide string
std::wstring AnsiToWide(const std::string& str) {
    if (str.empty()) return L"";
    int count = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                                    (int)str.length(), nullptr, 0);
    std::wstring wstr(count, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                        (int)str.length(), &wstr[0], count);
    return wstr;
}

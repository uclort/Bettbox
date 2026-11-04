#pragma once

#include <windows.h>

#include <uxtheme.h>
#include <vsstyle.h>
#include <vssym32.h>

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "uxtheme.lib")

namespace tray_manager {

// BETTBOX-CUSTOM: 策略组与节点行使用自绘菜单项：左侧名称为正文色，右侧选中项与
// 延迟为灰色并右对齐；子菜单行自绘箭头，说明紧贴箭头。原生菜单的 Tab 列无法单独
// 设置颜色，且会与快捷键列对齐留下大段空白。
struct TrayOwnerDrawItem;

// 同一个弹出菜单内的全部自绘项。测量时按两列计算：左列 = 最长名称，右列 =
// 最长说明，中间固定间隔，保证任何一行的说明都不会伸进其他行的名称区域。
struct TrayOwnerDrawColumn {
  std::vector<TrayOwnerDrawItem*> items;
};

struct TrayOwnerDrawItem {
  std::wstring label;
  std::wstring detail;
  bool submenu = false;
  // BETTBOX-CUSTOM: URLTest / Fallback 被固定时绘制锁：策略组行（submenu）画在
  // 名称前的勾选列；节点行同样画在勾选列，代替对号。
  bool locked = false;
  std::shared_ptr<TrayOwnerDrawColumn> column;
};

class TrayMenuOwnerDraw {
 public:
  ~TrayMenuOwnerDraw() { ReleaseFonts(); }

  void Measure(HWND host, MEASUREITEMSTRUCT* measure) {
    auto* item = reinterpret_cast<TrayOwnerDrawItem*>(measure->itemData);
    if (item == nullptr) return;
    const UINT dpi = DpiOf(host);
    EnsureFonts(dpi);
    const Layout layout = LayoutFor(host, dpi);

    HDC dc = GetDC(host);
    HGDIOBJ old_font = SelectObject(dc, text_font_);
    // 锁画在名称前的勾选列，不占名称宽度。
    auto item_label_width = [&](const TrayOwnerDrawItem* target) {
      return MarkedTextWidth(dc, target->label, dpi);
    };
    int label_width = item_label_width(item);
    int detail_width = MarkedTextWidth(dc, item->detail, dpi);
    bool has_submenu = item->submenu;
    if (item->column != nullptr) {
      for (const TrayOwnerDrawItem* sibling : item->column->items) {
        label_width = (std::max)(label_width, item_label_width(sibling));
        detail_width =
            (std::max)(detail_width, MarkedTextWidth(dc, sibling->detail, dpi));
        has_submenu = has_submenu || sibling->submenu;
      }
    }
    TEXTMETRICW metrics{};
    GetTextMetricsW(dc, &metrics);
    SelectObject(dc, old_font);
    ReleaseDC(host, dc);

    int width = layout.text_left + label_width + layout.trailing;
    if (detail_width > 0) width += layout.column_gap + detail_width;
    if (has_submenu) width += layout.chevron_gap + layout.chevron_width;
    // 系统会在 itemWidth 基础上再追加勾选列宽度，这里提前扣除。
    width -= GetSystemMetricsForDpi(SM_CXMENUCHECK, dpi) - 1;
    measure->itemWidth = static_cast<UINT>((std::max)(width, 0));
    measure->itemHeight = static_cast<UINT>(
        (std::max)(layout.item_height,
                   static_cast<int>(metrics.tmHeight) + Scale(8, dpi)));
  }

  void Draw(HWND host, const DRAWITEMSTRUCT* draw, bool dark) {
    auto* item = reinterpret_cast<TrayOwnerDrawItem*>(draw->itemData);
    if (item == nullptr) return;
    HDC dc = draw->hDC;
    RECT rect = draw->rcItem;
    const UINT dpi = DpiOf(host);
    EnsureFonts(dpi);
    const Layout layout = LayoutFor(host, dpi);
    const bool selected = (draw->itemState & ODS_SELECTED) != 0;
    const bool disabled =
        (draw->itemState & (ODS_DISABLED | ODS_GRAYED)) != 0;
    const bool checked = (draw->itemState & ODS_CHECKED) != 0;

    // 首次以未选中状态绘制时，取行最左侧像素作为菜单底色并按明暗缓存；
    // 选中后再取会拿到高亮色，因此只在未选中时采样。
    COLORREF& cached = dark ? dark_background_ : light_background_;
    if (!selected && cached == CLR_INVALID) {
      cached = GetPixel(dc, rect.left, (rect.top + rect.bottom) / 2);
    }
    const COLORREF background =
        cached != CLR_INVALID ? cached
                              : (dark ? RGB(43, 43, 43) : GetSysColor(COLOR_MENU));
    HBRUSH background_brush = CreateSolidBrush(background);
    FillRect(dc, &rect, background_brush);
    DeleteObject(background_brush);

    if (selected && !disabled) {
      HTHEME theme = dark ? nullptr : OpenThemeData(host, L"MENU");
      if (theme != nullptr) {
        DrawThemeBackground(theme, dc, MENU_POPUPITEM, MPI_HOT, &rect, nullptr);
        CloseThemeData(theme);
      } else {
        const int inset = Scale(4, dpi);
        const int radius = Scale(8, dpi);
        HBRUSH hot = CreateSolidBrush(dark ? Lighten(background, 22)
                                           : RGB(229, 229, 229));
        HGDIOBJ old_brush = SelectObject(dc, hot);
        HGDIOBJ old_pen = SelectObject(dc, GetStockObject(NULL_PEN));
        RoundRect(dc, rect.left + inset, rect.top + Scale(1, dpi),
                  rect.right - inset + 1, rect.bottom - Scale(1, dpi) + 1,
                  radius, radius);
        SelectObject(dc, old_pen);
        SelectObject(dc, old_brush);
        DeleteObject(hot);
      }
    }

    COLORREF text_color;
    COLORREF detail_color;
    if (disabled) {
      // BETTBOX-CUSTOM: 不可手动选择的节点名称与右侧延迟使用同一灰色。
      text_color = dark ? RGB(160, 160, 160) : RGB(112, 112, 112);
      detail_color = text_color;
    } else if (dark) {
      text_color = RGB(255, 255, 255);
      detail_color = RGB(160, 160, 160);
    } else {
      text_color = GetSysColor(COLOR_MENUTEXT);
      detail_color = RGB(112, 112, 112);
    }

    const int previous_mode = SetBkMode(dc, TRANSPARENT);
    const COLORREF previous_color = GetTextColor(dc);

    RECT check_rect{rect.left, rect.top, rect.left + layout.text_left,
                    rect.bottom};
    if (item->locked && item->submenu) {
      // BETTBOX-CUSTOM: 锁统一放在名称前：策略组行画在勾选列，组名仍与其他行对齐；
      // 与右侧说明同色（不可点击文字的灰色），不抢视觉。
      DrawGlyph(dc, lock_font_, L"\xE72E", check_rect, detail_color);
    } else if (item->locked) {
      // BETTBOX-CUSTOM: 自动组固定的节点在勾选列画锁代替对号，与窗口卡片一致。
      DrawGlyph(dc, icon_font_, L"\xE72E", check_rect, text_color);
    } else if (checked) {
      DrawGlyph(dc, icon_font_, L"\xE73E", check_rect, text_color);
    }

    int right = rect.right - layout.trailing;
    if (item->submenu) {
      RECT chevron_rect{right - layout.chevron_width, rect.top, right,
                        rect.bottom};
      DrawGlyph(dc, chevron_font_, L"\xE76C", chevron_rect, text_color);
      right = chevron_rect.left - layout.chevron_gap;
    }

    HGDIOBJ old_font = SelectObject(dc, text_font_);
    const int label_left = rect.left + layout.text_left;
    const int available = (std::max)(0, right - label_left);
    int detail_width = MarkedTextWidth(dc, item->detail, dpi);
    if (detail_width > 0) {
      const int label_width = MarkedTextWidth(dc, item->label, dpi);
      const int room = (std::max)(available * 6 / 10,
                                  available - layout.column_gap - label_width);
      detail_width = (std::min)(detail_width, room);
      RECT detail_rect{right - detail_width, rect.top, right, rect.bottom};
      DrawMarkedText(dc, item->detail, detail_rect, detail_color, dpi);
      right = detail_rect.left - layout.column_gap;
    }
    RECT label_rect{label_left, rect.top, (std::max)(label_left, right),
                    rect.bottom};
    // BETTBOX-CUSTOM: 子菜单中作为节点出现的策略组被固定时，名称里带锁标记。
    DrawMarkedText(dc, item->label, label_rect, text_color, dpi,
                   /*align_right=*/false);

    SelectObject(dc, old_font);
    SetTextColor(dc, previous_color);
    SetBkMode(dc, previous_mode);

    // 系统会在 WM_DRAWITEM 之后为子菜单项画经典黑色箭头，排除本行避免覆盖自绘箭头。
    ExcludeClipRect(dc, rect.left, rect.top, rect.right, rect.bottom);
  }

 private:
  struct Layout {
    int text_left;
    int trailing;
    int column_gap;
    int chevron_width;
    int chevron_gap;
    int item_height;
    // BETTBOX-CUSTOM: 说明文字中锁标记占位（含两侧留白，96 DPI 基准）。
    static constexpr int inline_lock_width = 14;
  };

  static int Scale(int value, UINT dpi) {
    return MulDiv(value, static_cast<int>(dpi), 96);
  }

  static UINT DpiOf(HWND window) {
    const UINT dpi = window != nullptr ? GetDpiForWindow(window) : 0;
    return dpi == 0 ? 96 : dpi;
  }

  static COLORREF Lighten(COLORREF color, int amount) {
    auto channel = [amount](int value) {
      return static_cast<BYTE>((std::min)(255, value + amount));
    };
    return RGB(channel(GetRValue(color)), channel(GetGValue(color)),
               channel(GetBValue(color)));
  }

  static int TextWidth(HDC dc, const std::wstring& text) {
    if (text.empty()) return 0;
    RECT rect{0, 0, 0, 0};
    DrawTextW(dc, text.c_str(), static_cast<int>(text.size()), &rect,
              DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    return rect.right - rect.left;
  }

  static void DrawGlyph(HDC dc, HFONT font, const wchar_t* glyph, RECT rect,
                        COLORREF color) {
    if (font == nullptr) return;
    HGDIOBJ old_font = SelectObject(dc, font);
    SetTextColor(dc, color);
    DrawTextW(dc, glyph, 1, &rect,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    SelectObject(dc, old_font);
  }

  // BETTBOX-CUSTOM: Dart 侧在说明文字里用 🔒（trayLockMark，UTF-16 代理对）标记
  // 被固定的策略组 / 节点，绘制时替换为与策略组行相同的 MDL2 锁字形。
  static constexpr wchar_t kLockMark[] = L"\xD83D\xDD12";
  static constexpr size_t kLockMarkLength = 2;

  static std::vector<std::wstring> SplitLockMark(const std::wstring& text) {
    std::vector<std::wstring> parts;
    size_t start = 0;
    while (true) {
      const size_t found = text.find(kLockMark, start);
      if (found == std::wstring::npos) {
        parts.push_back(text.substr(start));
        break;
      }
      parts.push_back(text.substr(start, found - start));
      start = found + kLockMarkLength;
    }
    return parts;
  }

  // 调用前 dc 已选入正文字体。
  static int MarkedTextWidth(HDC dc, const std::wstring& text, UINT dpi) {
    const std::vector<std::wstring> parts = SplitLockMark(text);
    int width = 0;
    for (const std::wstring& part : parts) width += TextWidth(dc, part);
    width += static_cast<int>(parts.size() - 1) *
             Scale(Layout::inline_lock_width, dpi);
    return width;
  }

  // 绘制含锁标记的文字（默认右对齐，用于说明；名称传 align_right = false）；
  // 放不下时从左侧开始，末段以省略号截断。
  void DrawMarkedText(HDC dc, const std::wstring& text, RECT rect,
                      COLORREF color, UINT dpi,
                      bool align_right = true) const {
    SetTextColor(dc, color);
    const UINT flags =
        DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS;
    if (text.find(kLockMark) == std::wstring::npos) {
      DrawTextW(dc, text.c_str(), static_cast<int>(text.size()), &rect,
                (align_right ? DT_RIGHT : DT_LEFT) | flags);
      return;
    }
    const std::vector<std::wstring> parts = SplitLockMark(text);
    const int lock_width = Scale(Layout::inline_lock_width, dpi);
    const int right = static_cast<int>(rect.right);
    const int room = right - static_cast<int>(rect.left);
    int x = align_right
                ? right - (std::min)(MarkedTextWidth(dc, text, dpi), room)
                : static_cast<int>(rect.left);
    for (size_t i = 0; i < parts.size(); ++i) {
      if (i > 0) {
        if (x + lock_width > right) break;
        RECT lock_rect{x, rect.top, x + lock_width, rect.bottom};
        DrawGlyph(dc, lock_font_, L"\xE72E", lock_rect, color);
        SetTextColor(dc, color);
        x += lock_width;
      }
      const std::wstring& part = parts[i];
      if (part.empty()) continue;
      const int remaining = right - x;
      if (remaining <= 0) break;
      RECT part_rect{x, rect.top, rect.right, rect.bottom};
      DrawTextW(dc, part.c_str(), static_cast<int>(part.size()), &part_rect,
                DT_LEFT | flags);
      x += (std::min)(TextWidth(dc, part), remaining);
    }
  }

  // 与原生菜单项对齐：文字起点 = 项边距 + 勾选背景（含边距）+ 文字边距。
  Layout LayoutFor(HWND host, UINT dpi) const {
    Layout layout{Scale(32, dpi), Scale(12, dpi), Scale(28, dpi),
                  Scale(12, dpi), Scale(4, dpi), Scale(24, dpi)};
    HTHEME theme = OpenThemeData(host, L"MENU");
    if (theme == nullptr) return layout;
    HDC dc = GetDC(host);
    SIZE check{};
    MARGINS check_margins{};
    MARGINS check_background_margins{};
    MARGINS item_margins{};
    const bool ok =
        SUCCEEDED(GetThemePartSize(theme, dc, MENU_POPUPCHECK, 0, nullptr,
                                   TS_TRUE, &check)) &&
        SUCCEEDED(GetThemeMargins(theme, dc, MENU_POPUPCHECK, 0,
                                  TMT_CONTENTMARGINS, nullptr,
                                  &check_margins)) &&
        SUCCEEDED(GetThemeMargins(theme, dc, MENU_POPUPCHECKBACKGROUND, 0,
                                  TMT_CONTENTMARGINS, nullptr,
                                  &check_background_margins)) &&
        SUCCEEDED(GetThemeMargins(theme, dc, MENU_POPUPITEM, 0,
                                  TMT_CONTENTMARGINS, nullptr, &item_margins));
    ReleaseDC(host, dc);
    CloseThemeData(theme);
    if (!ok || check.cx <= 0) return layout;
    // 主题尺寸按系统 DPI 返回，换算到当前 DPI。
    const UINT system_dpi = GetDpiForSystem();
    auto to_dpi = [dpi, system_dpi](int value) {
      return MulDiv(value, static_cast<int>(dpi),
                    static_cast<int>(system_dpi == 0 ? 96 : system_dpi));
    };
    const int check_column = check_background_margins.cxLeftWidth +
                             check_margins.cxLeftWidth + check.cx +
                             check_margins.cxRightWidth +
                             check_background_margins.cxRightWidth;
    layout.text_left = to_dpi(check_column + item_margins.cxLeftWidth);
    const int themed_height = to_dpi(
        check.cy + check_margins.cyTopHeight + check_margins.cyBottomHeight +
        check_background_margins.cyTopHeight +
        check_background_margins.cyBottomHeight);
    if (themed_height > 0) layout.item_height = themed_height;
    return layout;
  }

  void EnsureFonts(UINT dpi) {
    if (fonts_dpi_ == dpi && text_font_ != nullptr) return;
    ReleaseFonts();
    fonts_dpi_ = dpi;
    NONCLIENTMETRICSW metrics{};
    metrics.cbSize = sizeof(metrics);
    if (!SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(metrics),
                                    &metrics, 0, dpi)) {
      SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics,
                            0);
    }
    text_font_ = CreateFontIndirectW(&metrics.lfMenuFont);

    LOGFONTW icon = metrics.lfMenuFont;
    icon.lfWeight = FW_NORMAL;
    icon.lfItalic = FALSE;
    icon.lfUnderline = FALSE;
    wcscpy_s(icon.lfFaceName, L"Segoe MDL2 Assets");
    icon_font_ = CreateFontIndirectW(&icon);
    icon.lfHeight = MulDiv(metrics.lfMenuFont.lfHeight, 2, 3);
    chevron_font_ = CreateFontIndirectW(&icon);
    // BETTBOX-CUSTOM: 锁定标记与箭头同尺寸，略小于菜单文字。
    icon.lfHeight = MulDiv(metrics.lfMenuFont.lfHeight, 2, 3);
    lock_font_ = CreateFontIndirectW(&icon);
  }

  void ReleaseFonts() {
    for (HFONT* font : {&text_font_, &icon_font_, &chevron_font_, &lock_font_}) {
      if (*font != nullptr) {
        DeleteObject(*font);
        *font = nullptr;
      }
    }
    fonts_dpi_ = 0;
  }

  COLORREF light_background_ = CLR_INVALID;
  COLORREF dark_background_ = CLR_INVALID;
  HFONT text_font_ = nullptr;
  HFONT icon_font_ = nullptr;
  HFONT chevron_font_ = nullptr;
  HFONT lock_font_ = nullptr;
  UINT fonts_dpi_ = 0;
};

}  // namespace tray_manager

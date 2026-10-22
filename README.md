# Personal Arch Linux Repository (x86-64-v3 & x86-64-v4)

Kho lưu trữ gói nhị phân tự động xây dựng hoàn toàn bằng GitHub Actions và phân phối tốc độ cao qua VPS riêng (`tinhiem.duckdns.org`), hỗ trợ tối ưu hóa đồng thời cho cả kiến trúc **x86-64-v3** và **x86-64-v4**.

---

## 🚀 Cách cấu hình `pacman.conf`

Thêm cấu hình sau vào đầu danh sách repository trong `/etc/pacman.conf`:

```ini
[tinhiem]
SigLevel = Optional TrustAll
Server = https://tinhiem.duckdns.org/
Server = https://github.com/tinnguyen0706/my-arch-repo/releases/download/repository
```

Cập nhật database và cài đặt:

```bash
sudo pacman -Sy

# Cài đặt trọn bộ văn phòng Office Craft:
sudo pacman -S office-craft

# Cài đặt bộ gõ tiếng Việt Lotus tối ưu v3:
sudo pacman -S fcitx5-lotus

# Cài đặt Zalo chính chủ (Original):
sudo pacman -S zalo

# Cài đặt auto-cpufreq mới nhất (v3.2.0):
sudo pacman -S auto-cpufreq

# Cài đặt công cụ format LaTeX nhanh bằng Rust:
sudo pacman -S tex-fmt

# Cài đặt Wayland compositor Umbriel:
sudo pacman -S umbriel-git
```

# Cài đặt Waywallen và bộ tích hợp Wallpaper Engine:
sudo pacman -S waywallen waywallen-display open-wallpaper-engine

---

## 🛠️ Danh sách các gói được duy trì

| Gói | Nguồn | Mô tả |
| :--- | :--- | :--- |
| `umbriel-git` | AUR / GitHub | Wayland compositor hiện đại đa layout (dwindle, master, scrolling) |
| `xdg-desktop-portal-umbriel-git` | AUR / GitHub | XDG Desktop Portal backend cho Umbriel |
| `fcitx5-lotus` | AUR / GitHub | Bộ gõ tiếng Việt Lotus cho Fcitx5 (compile v3/v4 native) |
| `tex-fmt` | AUR / GitHub | Trình format LaTeX siêu tốc bằng Rust (compile v3/v4 native) |
| `office-craft` | Local Meta-package | Gói liên kết gom trọn bộ 4 ứng dụng văn phòng của Storytold |
| `wordcraft` | GitHub `storytold/wordcraft` | Ứng dụng soạn thảo văn bản thuần Rust (Word-style) |
| `gridcraft` | GitHub `storytold/gridcraft` | Ứng dụng bảng tính thuần Rust (Excel-style) |
| `deckcraft` | GitHub `storytold/deckcraft` | Ứng dụng trình chiếu slide thuần Rust (PowerPoint-style) |
| `pdfcraft` | GitHub `storytold/pdfcraft` | Ứng dụng đọc và chỉnh sửa PDF thuần Rust (Acrobat-style) |
| `auto-cpufreq` | GitHub `AdnanHodzic` | Tối ưu hóa xung nhịp CPU và pin laptop tự động (bản mới nhất v3.2.0) |
| `zalo` | GitHub `VN-Linux-Family` | Zalo cho Linux bản gốc chính thức (Original, không ZaDark) |
| `waywallen` | GitHub `waywallen/waywallen` | Wallpaper Manager for Linux (compile v3/v4 native) |
| `waywallen-display` | AUR / GitHub | Desktop integration for waywallen (layer-shell client cho Niri/Wayland) |
| `open-wallpaper-engine` | AUR / GitHub | Open source scene renderer, mostly for linux. (Plugin cho Waywallen) |

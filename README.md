# Personal Arch Linux Repository (x86-64-v3 & x86-64-v4)

Kho lưu trữ gói nhị phân tự động xây dựng hoàn toàn bằng GitHub Actions và phát hành qua GitHub Releases, hỗ trợ tối ưu hóa đồng thời cho cả kiến trúc **x86-64-v3** và **x86-64-v4**.

---

## 🚀 Cách cấu hình `pacman.conf`

Thêm cấu hình sau vào cuối file `/etc/pacman.conf`:

```ini
# Nếu máy hỗ trợ x86-64-v4 (AVX-512), pacman sẽ ưu tiên tải bản v4:
[tinhiem-v4]
SigLevel = Optional TrustAll
Server = https://github.com/tinnguyen0706/my-arch-repo/releases/download/repository

# Nếu máy chỉ hỗ trợ x86-64-v3, pacman sẽ tự động dùng bản v3:
[tinhiem]
SigLevel = Optional TrustAll
Server = https://github.com/tinnguyen0706/my-arch-repo/releases/download/repository
```

Cập nhật database và cài đặt:

```bash
sudo pacman -Sy

# Cài đặt trọn bộ văn phòng Storytold Craft (Word, Grid, Deck, PDF):
sudo pacman -S story-office

# Hoặc cài đặt lẻ từng ứng dụng:
sudo pacman -S wordcraft
sudo pacman -S gridcraft
sudo pacman -S deckcraft
sudo pacman -S pdfcraft

# Cài đặt Wayland compositor Umbriel:
sudo pacman -S umbriel-git
```

---

## 🛠️ Danh sách các gói được duy trì

| Gói | Nguồn | Mô tả |
| :--- | :--- | :--- |
| `umbriel-git` | AUR / GitHub | Wayland compositor hiện đại đa layout (dwindle, master, scrolling) |
| `xdg-desktop-portal-umbriel-git` | AUR / GitHub | XDG Desktop Portal backend cho Umbriel |
| `wordcraft` | GitHub `storytold/wordcraft` | Ứng dụng soạn thảo văn bản thuần Rust (Word-style) |
| `gridcraft` | GitHub `storytold/gridcraft` | Ứng dụng bảng tính thuần Rust (Excel-style) |
| `deckcraft` | GitHub `storytold/deckcraft` | Ứng dụng trình chiếu slide thuần Rust (PowerPoint-style) |
| `pdfcraft` | GitHub `storytold/pdfcraft` | Ứng dụng đọc và chỉnh sửa PDF thuần Rust (Acrobat-style) |
| `story-office` | Local Meta-package | Gói liên kết gom trọn bộ 4 ứng dụng văn phòng của Storytold |

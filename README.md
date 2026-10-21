# My Arch Linux Repository (x86-64-v3)

Kho lưu trữ gói Arch Linux nhị phân tự động xây dựng bằng GitHub Actions cho `umbriel-git` và `xdg-desktop-portal-umbriel-git`, được tối ưu hóa cho kiến trúc CPU `x86-64-v3`.

## Cách sử dụng

Thêm đoạn sau vào cuối file `/etc/pacman.conf`:

```ini
[tinhiem]
SigLevel = Optional TrustAll
Server = https://github.com/tinnguyen0706/my-arch-repo/releases/download/repository
```

Cập nhật database và cài đặt:

```bash
sudo pacman -Sy
sudo pacman -S umbriel-git
```

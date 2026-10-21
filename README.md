# My Arch Linux Repository

Kho lưu trữ gói Arch Linux nhị phân tự động xây dựng bằng GitHub Actions cho `umbriel-git` và `xdg-desktop-portal-umbriel-git`.

## Cách sử dụng

Thêm đoạn sau vào cuối file `/etc/pacman.conf`:

```ini
[myrepo]
SigLevel = Optional TrustAll
Server = https://github.com/tinnguyen0706/my-arch-repo/releases/download/repository
```

Cập nhật database và cài đặt:

```bash
sudo pacman -Sy
sudo pacman -S umbriel-git
```

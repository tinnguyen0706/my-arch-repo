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

Cập nhật và cài đặt:

```bash
sudo pacman -Sy
sudo pacman -S umbriel-git
```

---

## 🛠️ Quản lý các gói

Tất cả các gói được quản lý tập trung thông qua file `packages.txt`:

1. **Gói AUR**: Điền tên package AUR vào file `packages.txt`. Workflow `sync-aur.yml` sẽ định kỳ kiểm tra và kéo PKGBUILD mới nhất về thông qua Pull Request.
2. **Gói tự maintain (Local)**: Thêm tiền tố `local:<tên-gói>` vào `packages.txt` và tự quản lý thư mục cùng tên trong repository.

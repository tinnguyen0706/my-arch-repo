# Personal Arch Linux Repository (x86-64-v3 & x86-64-v4)

Kho lưu trữ gói nhị phân tự động xây dựng bằng GitHub Actions và phân phối qua VPS riêng (`arch.tinhiem.id.vn`), hỗ trợ tối ưu hóa cho kiến trúc x86-64-v3 và x86-64-v4.

---

## Cấu hình pacman.conf

Thêm cấu hình sau vào `/etc/pacman.conf`:

### x86-64-v3 (AVX2)
```ini
[tinhiem]
SigLevel = Optional TrustAll
Server = https://arch.tinhiem.id.vn/
```

### x86-64-v4 (AVX-512)
```ini
[tinhiem-v4]
SigLevel = Optional TrustAll
Server = https://arch.tinhiem.id.vn/
```

Cập nhật database:
```bash
sudo pacman -Sy
```

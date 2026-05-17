#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认IP
echo "[diy] 修改默认IP为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除要替换的包（来自官方 feeds）
echo "[diy] 移除 feeds 中的旧版 mosdns / msd_lite / smartdns"
for d in feeds/packages/net/mosdns feeds/packages/net/msd_lite feeds/packages/net/smartdns; do
  [ -d "$d" ] && rm -rf "$d" && echo "  已清除: $d"
done

# 克隆第三方插件源（如果目录已存在则跳过，避免重复执行报错）
clone_if_missing() {
  local repo="$1" branch="$2" dest="$3"
  if [ -d "$dest" ]; then
    echo "[diy] 跳过已存在的仓库: $dest"
  else
    echo "[diy] 克隆: $repo -> $dest"
    git clone --depth=1 ${branch:+-b "$branch"} "$repo" "$dest"
  fi
}

clone_if_missing https://github.com/sbwml/luci-app-mosdns              ""     package/luci-app-mosdns
clone_if_missing https://github.com/ximiTech/luci-app-msd_lite         ""     package/luci-app-msd_lite
clone_if_missing https://github.com/ximiTech/msd_lite                  ""     package/msd_lite
clone_if_missing https://github.com/pymumu/luci-app-smartdns           ""     package/luci-app-smartdns
clone_if_missing https://github.com/pymumu/openwrt-smartdns            ""     package/smartdns

WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

# 同步仓库内维护的 patches 目录到 OpenWrt 源码树
if [ -d "$WORKSPACE_ROOT/patches" ]; then
  echo "[diy] 同步自定义 patches 目录到源码树"
  cp -rf "$WORKSPACE_ROOT/patches/." ./
else
  echo "[diy] patches 目录不存在，跳过"
fi

# 修改版本为编译日期
DATE_VERSION="$(date +%Y.%m.%d)"
VERSION_FILE="include/version.mk"
echo "[diy] 修改版本为编译日期: $DATE_VERSION"
sed -i "s/^VERSION_NUMBER:=.*/VERSION_NUMBER:=-$DATE_VERSION by WoChen5770/" "$VERSION_FILE"

echo "=== diy-script: 完成 ==="

#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认IP
echo "[diy] 修改默认IP为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除要替换的包（来自官方 feeds）
echo "[diy] 移除 feeds 中的旧版app"
rm -rf feeds/packages/net/mosdns feeds/packages/net/msd_lite feeds/packages/net/smartdns feeds/packages/net/dae feeds/packages/net/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,haproxy}
rm -rf feeds/luci/applications/luci-app-passwall

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
clone_if_missing https://github.com/QiuSimons/luci-app-daed            ""     package/dae
clone_if_missing https://github.com/Openwrt-Passwall/openwrt-passwall-packages "" package/passwall-packages
clone_if_missing https://github.com/Openwrt-Passwall/openwrt-passwall  ""     package/passwall-luci

WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

# Inject golang1.26 and golang-bootstrap into feeds
GOLANG_FEED_DIR="feeds/packages/lang/golang"
GOLANG_SRC_DIR="$WORKSPACE_ROOT/scripts/golang"
if [ -d "$GOLANG_FEED_DIR" ] && [ -d "$GOLANG_SRC_DIR" ]; then
  echo "[diy] 注入 scripts/golang/golang1.26 到 feeds"
  mkdir -p "$GOLANG_FEED_DIR/golang1.26"
  cp -rf "$GOLANG_SRC_DIR/golang1.26/." "$GOLANG_FEED_DIR/golang1.26/"

  if [ -d "$GOLANG_SRC_DIR/golang-bootstrap" ]; then
    echo "[diy] 注入 scripts/golang/golang-bootstrap 到 feeds"
    mkdir -p "$GOLANG_FEED_DIR/golang-bootstrap"
    cp -rf "$GOLANG_SRC_DIR/golang-bootstrap/." "$GOLANG_FEED_DIR/golang-bootstrap/"
  fi

  echo "[diy] 重新安装 golang feed 包"
  ./scripts/feeds install -f golang-bootstrap
  ./scripts/feeds install -f golang1.26
else
  echo "[diy] 未找到 $GOLANG_FEED_DIR 或 $GOLANG_SRC_DIR，跳过 golang1.26 注入"
fi

# Make daed use golang1.26/host
DAED_MAKEFILE="package/dae/daed/Makefile"
if [ -f "$DAED_MAKEFILE" ]; then
  echo "[diy] patch daed -> golang1.26"
  sed -i 's#^PKG_BUILD_DEPENDS:=golang/host bpf-headers#PKG_BUILD_DEPENDS:=golang1.26/host bpf-headers#' "$DAED_MAKEFILE"
else
  echo "[diy] 未找到 $DAED_MAKEFILE，跳过 daed golang1.26 patch"
fi


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

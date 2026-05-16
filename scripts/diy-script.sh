#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认IP
echo "[diy] 修改默认IP为 192.168.123.1"
sed -i 's/192.168.6.1/192.168.123.1/g' package/base-files/files/bin/config_generate

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
CUSTOM_VER="${DATE_VERSION} by WoChen5770"
sed -i '/^CONFIG_VERSION_NUMBER=/d' .config
echo "CONFIG_VERSION_NUMBER=\"${CUSTOM_VER}\"" >> .config

# 修补 filogic 6.18 内核配置，启用 BPF 相关选项
KCFG="target/linux/mediatek/filogic/config-6.18"
if [ -f "$KCFG" ]; then
  echo "[diy] 补丁内核配置: $KCFG (启用 BPF)"
  for opt in CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_NET_SCH_BPF; do
    sed -i "/^${opt}=.*/d" "$KCFG"
    sed -i "/^# ${opt} is not set/d" "$KCFG"
  done
  cat >> "$KCFG" <<'EOF'
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_NET_SCH_BPF=y
EOF
else
  echo "[diy] 内核配置未找到: $KCFG"
fi

echo "=== diy-script: 完成 ==="

# 下载最新的 v2ray geosite.dat 和 geoip.dat 到指定目录
CFG_FILE="$WORKSPACE_ROOT/configs/CUSTOMIZE.txt"
if [ -f "$CFG_FILE" ] && \
   grep -Eq '^[[:space:]]*CONFIG_PACKAGE_daed=y([[:space:]]*(#.*)?)?$' "$CFG_FILE" && \
   grep -Eq '^[[:space:]]*CONFIG_PACKAGE_daed-geoip=n([[:space:]]*(#.*)?)?$' "$CFG_FILE"; then
  echo "[INFO] 下载最新的 v2ray geosite.dat 和 geoip.dat"
  mkdir -p files/usr/share/v2ray
  curl -L --retry 3 -o files/usr/share/v2ray/geosite.dat \
    https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
  curl -L --retry 3 -o files/usr/share/v2ray/geoip.dat \
    https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
else
  echo "[INFO] 跳过下载geosite.dat 和 geoip.dat"
fi
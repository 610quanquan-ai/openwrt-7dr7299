#!/bin/bash
set -e -o pipefail

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
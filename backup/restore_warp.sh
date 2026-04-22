#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="/root/amnezia-warp-backup"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "❌ Бэкап не найден: $BACKUP_DIR"
  echo "💡 Сначала выполните: sudo bash backup_warp.sh"
  exit 1
fi

echo "🔄 Откатываю изменения из $BACKUP_DIR..."

# 1. Останавливаем юниты скрипта
systemctl stop amnezia-warp-routing@legacy.service amnezia-warp-routing@v2.service wg-quick@wgcf.service 2>/dev/null || true
systemctl disable amnezia-warp-routing@legacy.service amnezia-warp-routing@v2.service wg-quick@wgcf.service 2>/dev/null || true

# 2. Чистим in-memory артефакты (удаляем только то, что добавил скрипт)
iptables -t mangle -D PREROUTING -j CONNMARK --restore-mark 2>/dev/null || true
iptables -t mangle -D PREROUTING -j AMN_WARP_AWG 2>/dev/null || true
iptables -t mangle -D PREROUTING -j AMN_WARP_AWG2 2>/dev/null || true
ip rule del priority 10061 10062 10066 2>/dev/null || true
ip route flush table 51820 2>/dev/null || true

# 3. Восстанавливаем файлы
if [[ -d "$BACKUP_DIR/files/etc_amnezia-warp" ]]; then
  cp -a "$BACKUP_DIR/files/etc_amnezia-warp"/* /etc/amnezia-warp/ 2>/dev/null || true
fi
if [[ -d "$BACKUP_DIR/files/etc_wireguard" ]]; then
  cp -a "$BACKUP_DIR/files/etc_wireguard"/* /etc/wireguard/ 2>/dev/null || true
fi
for f in \
  /etc/sysctl.d/99-amnezia-warp.conf \
  /usr/local/sbin/amnezia-warp-routing.sh \
  /usr/local/bin/wgcf \
  /etc/systemd/system/amnezia-warp-routing@.service \
  /etc/systemd/system/wg-quick@wgcf.service; do
  base=$(basename "$f")
  [[ -f "$BACKUP_DIR/files/$base" ]] && cp -a "$BACKUP_DIR/files/$base" "$f"
done

# 4. Восстанавливаем таблицу mangle (полная замена)
iptables-restore -t mangle < "$BACKUP_DIR/iptables/mangle.rules" 2>/dev/null || true

# 5. Применяем sysctl и перечитываем systemd
sysctl -p "$BACKUP_DIR/sysctl/bridge.conf" >/dev/null 2>&1 || true
systemctl daemon-reload

echo "✅ Откат завершён."
echo "🔍 Проверьте: sudo systemctl restart x-ui && curl -I http://127.0.0.1:<порт_панели>"

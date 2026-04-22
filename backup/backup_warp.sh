#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="/root/amnezia-warp-backup"

echo "📦 Создаю/обновляю резервную копию в $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"/{iptables,ip_rules,routes,sysctl,files}

# 1. Таблица mangle (полный снимок)
iptables-save -t mangle > "$BACKUP_DIR/iptables/mangle.rules"

# 2. Политический роутинг (для аудита)
ip rule show > "$BACKUP_DIR/ip_rules/all.rules"

# 3. Кастомная таблица маршрутов
ip route show table 51820 > "$BACKUP_DIR/routes/table_51820.rules" 2>/dev/null || true

# 4. Параметры ядра (bridge netfilter)
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables > "$BACKUP_DIR/sysctl/bridge.conf" 2>/dev/null || true

# 5. Файлы, которые создаёт/меняет скрипт
cp -a /etc/amnezia-warp "$BACKUP_DIR/files/" 2>/dev/null || mkdir "$BACKUP_DIR/files/etc_amnezia-warp"
cp -a /etc/wireguard "$BACKUP_DIR/files/" 2>/dev/null || mkdir "$BACKUP_DIR/files/etc_wireguard"

for f in \
  /etc/sysctl.d/99-amnezia-warp.conf \
  /usr/local/sbin/amnezia-warp-routing.sh \
  /usr/local/bin/wgcf \
  /etc/systemd/system/amnezia-warp-routing@.service \
  /etc/systemd/system/wg-quick@wgcf.service; do
  [[ -f "$f" ]] && cp -a "$f" "$BACKUP_DIR/files/"
done

echo "✅ Бэкап сохранён: $BACKUP_DIR"

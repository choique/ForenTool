#!/bin/bash
# Script clonación USB con whiptail + barra de progreso con pingüinos animados 🐧
# Ejecutar como root

## chmod +x clotool.sh
## sudo apt intall whiptail pv
## sudo ./clontool.sh
# Fin del script
# Autor: choique
# Licencia: GPLv3
# Fecha: 2024-06-20
# Versión: 1.0
# Repositorio:
#!/bin/bash
# Clonación bit a bit con menú interactivo, barra de progreso estable y hashes finales
# Ejecutar como root

set -u
set -e

# Verificar comandos requeridos
for cmd in whiptail lsblk pv dd sha256sum blockdev; do
  command -v $cmd >/dev/null 2>&1 || { echo "Falta $cmd"; exit 1; }
done

# --- Función para listar discos físicos ---
get_disks() {
    lsblk -dn -o NAME,SIZE,MODEL,TRAN,TYPE -P | while read -r line; do
        eval "$line"
        if [[ "$TYPE" == "disk" ]]; then
            [[ -z "$TRAN" ]] && TRAN="?"
            echo -e "$NAME\t$MODEL\t$SIZE\t$TRAN"
        fi
    done
}

# --- Construir opciones para whiptail ---
build_menu_options() {
    while IFS=$'\t' read -r name model size tran; do
        [[ -z "$name" ]] && continue
        tag="/dev/$name"
        desc="[$tran] $model ($size)"
        printf "%s\0%s\0" "$tag" "$desc"
    done < <(get_disks)
}

# --- Función para seleccionar dispositivo ---
select_device() {
    local title="$1"
    local -a options
    mapfile -d '' -t options < <(build_menu_options)

    if (( ${#options[@]} == 0 )); then
        whiptail --title "Sin discos" --msgbox "No se detectaron discos físicos." 12 60
        exit 1
    fi

    whiptail --title "$title" --menu "Seleccione un dispositivo:" 20 74 10 \
        "${options[@]}" 3>&1 1>&2 2>&3
}

# --- Inicio ---
whiptail --title "Clonación de discos" --msgbox \
"Este script clonará un disco en otro, bit a bit.

Se listan todos los discos conectados: USB, SATA, NVMe, IDE, M.2." 14 70

origen=$(select_device "Seleccione ORIGEN")
destino=$(select_device "Seleccione DESTINO")

if [[ -z "$origen" || -z "$destino" ]]; then
    whiptail --title "Cancelado" --msgbox "Operación cancelada." 8 40
    exit 1
fi
if [[ "$origen" == "$destino" ]]; then
    whiptail --title "Error" --msgbox "Origen y destino no pueden ser el mismo." 8 60
    exit 1
fi

tam_origen=$(blockdev --getsize64 "$origen")
tam_destino=$(blockdev --getsize64 "$destino")

if [[ "$tam_origen" -ne "$tam_destino" ]]; then
    whiptail --title "Error de tamaño" --msgbox "Los tamaños no coinciden." 10 60
    exit 1
fi

whiptail --title "Confirmación" --yesno \
"Se va a clonar:

Origen:  $origen
Destino: $destino
Tamaño:  $tam_origen bytes

¿Desea continuar?" 15 70 || exit 0

# --- Clonación con barra de progreso estable ---
TMPFILE=$(mktemp)

whiptail --title "Clonación" --infobox "Iniciando clonación..." 6 60
sleep 1

# Clonación en segundo plano, progreso a TMPFILE
pv -n -s "$tam_origen" "$origen" > "$destino" 2> "$TMPFILE" &
PID=$!

# Mostrar barra de progreso
(
    while kill -0 $PID 2>/dev/null; do
        if read -r pct <&3; then
            pct=${pct%.*}
            (( pct<0 )) && pct=0
            (( pct>100 )) && pct=100
            echo "$pct"
        fi
    done
) 3<"$TMPFILE" | whiptail --title "Clonando dispositivo" --gauge "Progreso..." 12 74 0

wait $PID
rm -f "$TMPFILE"
sync

# --- Generando hashes ---
whiptail --title "Hashes" --infobox "Generando hashes SHA256..." 6 60
sleep 1

hash_origen=$(dd if="$origen" bs=4M status=none | sha256sum | awk '{print $1}')
hash_destino=$(dd if="$destino" bs=4M status=none | sha256sum | awk '{print $1}')

msg="Hash Origen : $hash_origen
Hash Destino: $hash_destino

"
if [[ "$hash_origen" == "$hash_destino" ]]; then
    msg+="✅ Coinciden. Clonado exitoso."
else
    msg+="⚠️ No coinciden los hashes."
fi

whiptail --title "Resultado" --msgbox "$msg" 20 74

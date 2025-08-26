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


# --- Función para obtener lista de dispositivos USB ---
get_usb_disks() {
    lsblk -dn -o NAME,MODEL,SIZE,TRAN,TYPE | awk '$4=="usb" && $5=="disk"{print $1 " " $2 " " $3}'
}

# --- Genera opciones para whiptail ---
menu_options() {
    local opts=()
    while read -r line; do
        dev=$(echo $line | awk '{print $1}')
        info=$(echo $line | cut -d' ' -f2-)
        opts+=("/dev/$dev" "$info")
    done <<< "$(get_usb_disks)"
    echo "${opts[@]}"
}

# --- Seleccionar dispositivo con menú ---
select_device() {
    local title="$1"
    local options=($(menu_options))
    if [ ${#options[@]} -eq 0 ]; then
        whiptail --title "Error" --msgbox "No se detectaron discos USB." 10 50
        exit 1
    fi
    whiptail --title "$title" --menu "Seleccione un dispositivo:" 20 70 10 "${options[@]}" 3>&1 1>&2 2>&3
}

# --- Inicio ---
whiptail --title "Clonación USB" --msgbox "Este script clonará un dispositivo USB en otro.\n\n⚠️ ATENCIÓN: el proceso BORRARÁ todo en el destino." 12 60

origen=$(select_device "Dispositivo ORIGEN")
destino=$(select_device "Dispositivo DESTINO")

# Verificar que no sean el mismo
if [ "$origen" == "$destino" ]; then
    whiptail --title "Error" --msgbox "Origen y destino no pueden ser el mismo." 10 50
    exit 1
fi

# Verificar tamaños
tam_origen=$(blockdev --getsize64 "$origen")
tam_destino=$(blockdev --getsize64 "$destino")

if [ "$tam_origen" -ne "$tam_destino" ]; then
    whiptail --title "Error" --msgbox "Los tamaños no coinciden.\n\nOrigen: $tam_origen bytes\nDestino: $tam_destino bytes" 12 70
    exit 1
fi

# Confirmación
whiptail --title "Confirmación" --yesno "Se va a clonar:\n\nOrigen: $origen\nDestino: $destino\n\nTamaño: $tam_origen bytes\n\n¿Desea continuar?" 15 60
if [ $? -ne 0 ]; then
    exit 0
fi

# --- Frames para animación de pingüinos ---
frames=("🐧" "🐧 " " 🐧" " 🐧 ")
frame_index=0

# --- Clonado con pv + animación ---
(
    pv -n "$origen" | dd of="$destino" bs=4M conv=sync,noerror status=none
) 2>&1 | while read percent; do
    frame=${frames[$frame_index]}
    frame_index=$(( (frame_index+1) % ${#frames[@]} ))
    printf "XXX\n%d\nClonando dispositivo...\n%s\nXXX\n" "$percent" "$frame"
    sleep 0.2
done | whiptail --gauge "Iniciando clonación..." 12 70 0

sync

# --- Hashes ---
hash_origen=$(dd if="$origen" bs=4M status=none | sha256sum | awk '{print $1}')
hash_destino=$(dd if="$destino" bs=4M status=none | sha256sum | awk '{print $1}')

msg="Hash Origen : $hash_origen\nHash Destino: $hash_destino\n\n"
if [ "$hash_origen" == "$hash_destino" ]; then
    msg+="🎉 Verificación exitosa: los hashes coinciden.\n🐧🐧🐧🐧🐧"
else
    msg+="⚠️ Los hashes NO coinciden."
fi

whiptail --title "Resultado" --msgbox "$msg" 20 70






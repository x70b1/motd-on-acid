#!/bin/sh

BAR_ELEMENT="-"
BAR_HEALTHY_COLOR="32"
BAR_WARNING_THRESHOLD=70
BAR_WARNING_COLOR="33"
BAR_CRITICAL_THRESHOLD=90
BAR_CRITICAL_COLOR="31"

BANNER_KERNEL_ICON="#"
BANNER_KERNEL_COLOR="33"
BANNER_UPTIME_ICON="#"
BANNER_UPTIME_COLOR="94"
BANNER_DEBIAN_ICON="#"
BANNER_DEBIAN_COLOR="95"
BANNER_FONTPATH=""
BANNER_TEXT=""

PROCESSOR_LOADAVG_ICON="#"
PROCESSOR_LOADAVG_HEALTHY_COLOR="32"
PROCESSOR_LOADAVG_WARNING_THRESHOLD=2
PROCESSOR_LOADAVG_WARNING_COLOR="33"
PROCESSOR_LOADAVG_CRITICAL_THRESHOLD=4
PROCESSOR_LOADAVG_CRITICAL_COLOR="31"
PROCESSOR_MODEL_ICON="#"

MEMORY_ICON="#"

SWAP_ICON="#"

DISKSPACE_ICON="#"

UPDATES_ZERO_ICON="#"
UPDATES_ZERO_COLOR="32"
UPDATES_AVAILIABLE_ICON="#"
UPDATES_AVAILIABLE_COLOR="33"
UPDATES_SECURITY_ICON="#"
UPDATES_SECURITY_COLOR="31"

SERVICES_UP_ICON="#"
SERVICES_UP_COLOR="32"
SERVICES_DOWN_ICON="#"
SERVICES_DOWN_COLOR="31"
SERVICES_FILE=".bashrc_motd_services.txt"

DOCKER_VERSION_ICON="#"
DOCKER_IMAGES_ICON="#"
DOCKER_RUNNING_ICON="#"
DOCKER_RUNNING_COLOR="32"
DOCKER_OTHER_ICON="#"
DOCKER_OTHER_COLOR="90"

LETSENCRYPT_VALID_ICON="#"
LETSENCRYPT_VALID_COLOR="32"
LETSENCRYPT_WARNING_ICON="#"
LETSENCRYPT_WARNING_COLOR="33"
LETSENCRYPT_INVALID_ICON="#"
LETSENCRYPT_INVALID_COLOR="31"
LETSENCRYPT_CERTPATH="/etc/letsencrypt/live"

LOGIN_LOGIN_ICON="#"
LOGIN_LOGOUT_ICON="#"
LOGIN_IP_ICON="#"

generate_unit_byte() {
    # 1 - unit in M

    if [ "$1" -ge 1024 ]; then
        unit_symbol="G"
        unit_value=$(echo "scale=1; $1/1024" | bc -l)
    else
        unit_symbol="M"
        unit_value=$1
    fi

    echo "$unit_value$unit_symbol"
}

generate_space() {
    # 1 - already used
    # 2 - total

    space_fill=$(( $2 - ${#1} ))
    space_chars=""

    while [ $space_fill -ge 0 ]; do
        space_chars="$space_chars "
        space_fill=$(( space_fill - 1 ))
    done

    echo "$space_chars"
}

generate_bar() {
    # 1 - icon
    # 2 - total
    # 3 - used_1
    # 4 - [ used_2 ]

    bar_percent=$(( $3 * 100 / $2 ))
    bar_separator=$(( $3 * 100 * 10 / $2 / 25 ))

    if [ $bar_percent -ge "$BAR_WARNING_THRESHOLD" ]; then
        bar_color=$BAR_WARNING_COLOR
    elif [ $bar_percent -ge "$BAR_CRITICAL_THRESHOLD" ]; then
        bar_color=$BAR_CRITICAL_COLOR
    else
        bar_color=$BAR_HEALTHY_COLOR
    fi

    printf "       %s   \\033[%dm" "$1" "$bar_color"

    if [ -z "$4" ] ; then
        bar_piece=0
        while [ $bar_piece -le 40 ]; do
            if [ "$bar_piece" -ne "$bar_separator" ]; then
                printf "%s" "$BAR_ELEMENT"
            else
                printf "%s\\033[1;30m" "$BAR_ELEMENT"
            fi

            bar_piece=$(( bar_piece + 1 ))
        done
    else
        bar_cached_val=$(( $3 + $4 ))
        bar_cached_separator=$(( bar_cached_val * 100 * 10 / $2 / 25 ))

        bar_piece=0
        while [ $bar_piece -le 40 ]; do
            if [ $bar_piece -eq $bar_separator ]; then
                printf "%s\\033[1;36m" "$BAR_ELEMENT"
            elif [ $bar_piece -eq $bar_cached_separator ]; then
                printf "%s\\033[1;30m" "$BAR_ELEMENT"
            else
                printf "%s" "$BAR_ELEMENT"
            fi

            bar_piece=$(( bar_piece + 1 ))
        done
    fi

    printf "\\033[0m\\n"
}

generate_bar_memory() {
    # 1 - icon
    # 2 - total memory in M
    # 3 - used memory in M
    # 4 - cached memory in M

    bar_memory_used=$(generate_unit_byte "$3")
    bar_memory_cached=$(generate_unit_byte "$4")
    bar_memory_available=$(generate_unit_byte  $(( $2 - $3 )) )

    printf "           %s used / %s cached / %s available\\n" "$bar_memory_used" "$bar_memory_cached" "$bar_memory_available"
    generate_bar "$1" "$2" "$3" "$4"
}

generate_bar_swap() {
    # 1 - icon
    # 2 - total swap in M
    # 3 - used swap in M

    bar_swap_used=$(generate_unit_byte "$3")

    bar_swap_available=$(( $2 - $3 ))
    bar_swap_available=$(generate_unit_byte "$bar_swap_available")

    printf "           %s used / %s available\\n" "$bar_swap_used" "$bar_swap_available"
    generate_bar "$1" "$2" "$3"
}

generate_bar_disk() {
    # 1 - icon
    # 2 - total size in M
    # 3 - used space in M
    # 4 - mount path

    bar_disk_mount="$4$(generate_space "$4" 10)"

    bar_disk_used=$(generate_unit_byte "$3")
    bar_disk_used="$(generate_space "$bar_disk_used" 5)$bar_disk_used used"

    bar_disk_available=$(( $2 - $3 ))
    bar_disk_available="$(generate_unit_byte "$bar_disk_available") available"

    printf "           %s%s / %s\\n" "$bar_disk_mount" "$bar_disk_used" "$bar_disk_available"

    generate_bar "$1" "$2" "$3"
}

print_banner() {
    printf "\\n%s\\n" "$(figlet -f $BANNER_FONTPATH " $BANNER_TEXT")"

    if [ -f /etc/os-release ]; then
        . /etc/os-release

        if [ "$ID" = "debian" ]; then
            banner_distro_icon=$BANNER_DEBIAN_ICON
            banner_distro_color=$BANNER_DEBIAN_COLOR
            banner_distro_name="Debian"
            banner_distro_version=$(cat /etc/debian_version)
        else
            banner_distro_icon="?"
            banner_distro_color="0"
            banner_distro_name="Unknown"
            banner_distro_version="?"
        fi

        banner_distro_space=$(generate_space "$banner_distro_name" 13)

        printf "       \\033[%sm%s   %s\\033[0m%s%s\\n" "$banner_distro_color" "$banner_distro_icon" "$banner_distro_name" "$banner_distro_space" "$banner_distro_version"
        printf "       \\033[%sm%s   Linux\\033[0m         %s\\n\\n" "$BANNER_KERNEL_COLOR" "$BANNER_KERNEL_ICON" "$(cut -d ' ' -f 3 < /proc/version)"
        printf "       \\033[%sm%s   Uptime\\033[0m        %s\\n" "$BANNER_UPTIME_COLOR" "$BANNER_UPTIME_ICON" "$(uptime -p)"
    fi
}

print_processor() {
    printf "\\n"
    printf "    \\033[1;37mProcessor:\\033[0m\\n"

    processor_loadavg="$(cut -d " " -f 1,2,3 < /proc/loadavg)"
    if [ "$(echo "$processor_loadavg" | cut -d "." -f 1)" -ge "$PROCESSOR_LOADAVG_CRITICAL_THRESHOLD" ]; then
        processor_loadavg_color=$PROCESSOR_LOADAVG_CRITICAL_COLOR
    elif [ "$(echo "$processor_loadavg" | cut -d "." -f 1)" -ge "$PROCESSOR_LOADAVG_WARNING_THRESHOLD" ]; then
        processor_loadavg_color=$PROCESSOR_LOADAVG_WARNING_COLOR
    else
        processor_loadavg_color=$PROCESSOR_LOADAVG_HEALTHY_COLOR
    fi

    processor_info=$(cat /proc/cpuinfo)

    processor_arch=$(uname -m)

    if [ "$processor_arch" = "x86_64" ]; then
        processor_model="$(echo "$processor_info" | grep "model name" | sort -u | cut -d ':' -f 2)"
        processor_count=$(echo "$processor_info" | grep "physical id" | sort -u | wc -l)
        processor_cores=$(echo "$processor_info" | grep "cpu cores" | sort -u | cut -d ':' -f 2)
        processor_threads=$(( $(echo "$processor_info" | grep "siblings" | tail -n 1 | cut -d ':' -f 2) ))

        if [ ! "$processor_cores" -eq $processor_threads ]; then
            processor_threads=", $processor_threads Threads"
        else
            processor_threads=""
        fi
    elif [ "$processor_arch" = "mips64" ]; then
        processor_model="$(echo "$processor_info" | grep "cpu model" | sort -u | cut -d ':' -f 2)"
        processor_count=$(echo "$processor_info" | grep "package" | sort -u | wc -l)
        processor_cores=$(echo "$processor_info" | grep -c processor)
        processor_threads=""
    else
        processor_model="?"
        processor_count=0
        processor_cores=0
        processor_threads=0
    fi

    processor_model=$(echo "$processor_model" | sed "s/(R)//g")
    processor_model=$(echo "$processor_model" | sed "s/(tm)//g")
    processor_model=$(echo "$processor_model" | sed "s/ @/,/")
    processor_model=$(echo "$processor_model" | sed "s/ CPU//")
    processor_model=$(echo "$processor_model" | sed "s/  / /")
    processor_model=$(echo "$processor_model" | sed "s/^ //g")

    processor_cores=$(( processor_cores * processor_count ))

    if [ "$processor_count" -gt 1 ]; then
        processor_count="$processor_count""x "
    else
        processor_count=""
    fi

    printf "       %s   \\033[%dm%s\\033[0m\\n" "$PROCESSOR_LOADAVG_ICON" "$processor_loadavg_color" "$processor_loadavg"
    printf "       %s   %s%s  =  %s Cores%s\\n" "$PROCESSOR_MODEL_ICON" "$processor_count" "$processor_model" "$processor_cores" "$processor_threads"
}

print_memory() {
    printf "\\n"
    printf "    \\033[1;37mMemory:\\033[0m\\n"

    memory_usage=$(LANG=C free --mega | grep "Mem:")
    memory_total=$(echo "$memory_usage" | awk '{ print $2 }')
    memory_used=$(echo "$memory_usage" | awk '{ print $3 }')
    memory_cached=$(echo "$memory_usage" | awk '{ print $6 }')

    generate_bar_memory "$MEMORY_ICON" "$memory_total" "$memory_used" "$memory_cached"
}

print_swap() {
    swap_usage=$(LANG=C free --mega | grep "Swap:")

    swap_total=$(echo "$swap_usage" | awk '{ print $2 }')
    swap_used=$(echo "$swap_usage" | awk '{ print $3 }')

    if [ "$swap_total" -ne 0 ] && [ "$swap_used" -ne 0 ]; then
        printf "\\n"
        printf "    \\033[1;37mSwap:\\033[0m\\n"

        generate_bar_swap "$SWAP_ICON" "$swap_total" "$swap_used"
    fi
}

print_diskspace() {
    printf "\\n"
    printf "    \\033[1;37mDiskspace:\\033[0m\\n"

    diskspace_devices=$(lsblk -Jlo NAME,MOUNTPOINT | jq  -c '.blockdevices | sort_by(.mountpoint) | .[] | select( .mountpoint != null)')
    diskspace_partitions=$(df -B M | sed -e "s/M//g")

    diskspace_index=0
    echo "$diskspace_devices" | while read -r line; do
        diskspace_disk_name="$(echo "$line" | jq -r '.name')"
        diskspace_disk_mount="$(echo "$line" | jq -r '.mountpoint')"

        diskspace_disk_size="$(echo "$diskspace_partitions" | grep "$diskspace_disk_name" | awk '{ print $2 }')"
        diskspace_disk_used="$(echo "$diskspace_partitions" | grep "$diskspace_disk_name" | awk '{ print $3 }')"

        if [ -z "$diskspace_disk_size" ]; then
            diskspace_disk_size="$(echo "$diskspace_partitions" | grep "$diskspace_disk_mount" | awk '{ print $2 }')"
        fi

        if [ -z "$diskspace_disk_used" ]; then
            diskspace_disk_used="$(echo "$diskspace_partitions" | grep "$diskspace_disk_mount" | awk '{ print $3 }')"
        fi

        if [ "$diskspace_index" -ne 0 ]; then
            printf "\\n"
        fi

        diskspace_index=$(( diskspace_index + 1 ))

        generate_bar_disk "$DISKSPACE_ICON" "$diskspace_disk_size" "$diskspace_disk_used" "$diskspace_disk_mount"
    done
}

print_services() {
    if [ -f $SERVICES_FILE ] && [ "$(wc -l < $SERVICES_FILE )" != 0 ]; then
        printf "\\n"
        printf "    \\033[1;37mServices:\\033[0m                              \\033[1;37mVersion:\\033[0m\\n"

        while read -r line; do
            service_description=$(echo "$line" | cut -d ';' -f 1)

            service_name=$(echo "$line" | cut -d ';' -f 2)

            service_package=$(echo "$line" | cut -d ';' -f 3)

            if [ -n "$service_description" ] && [ -n "$service_name" ]; then
                if systemctl is-active --quiet "$service_name".service; then
                    service_icon=$SERVICES_UP_ICON
                    service_color=$SERVICES_UP_COLOR
                else
                    service_icon=$SERVICES_DOWN_ICON
                    service_color=$SERVICES_DOWN_COLOR
                fi

                service_space=$(generate_space "$service_description" 34)

                if [ -n "$service_package" ]; then
                    if [ -f /usr/bin/apt ]; then
                        package_version=$(dpkg -s "$service_package" | grep '^Version:' | cut -d ' ' -f 2 | cut -d ':' -f 2 | cut -d '-' -f 1)
                    else
                        package_version="?"
                    fi
                else
                    package_version="--"
                fi
            fi

            printf "       \\033[%sm%s\\033[0m   %s%s%s\\n" "$service_color" "$service_icon" "$service_description" "$service_space" "$package_version"
        done < $SERVICES_FILE | grep -v '#'
    fi
}

print_docker() {
    printf "\\n"
    printf "    \\033[1;37mDocker:\\033[0m\\n"

    docker_info=$(sudo curl -sf --unix-socket /var/run/docker.sock http:/v1.40/info)

    docker_version=$(echo "$docker_info" | jq -r '.ServerVersion')

    docker_space=$(generate_space "$docker_version" 23)

    docker_images=$(echo "$docker_info" | jq -r '.Images')

    printf "       %s   Version %s%s%s  %s Images\\n\\n" "$DOCKER_VERSION_ICON" "$docker_version" "$docker_space" "$DOCKER_IMAGES_ICON" "$docker_images"

    docker_list=$(sudo curl -sf --unix-socket /var/run/docker.sock http:/v1.40/containers/json?all=true | jq -c ' .[]')

    echo "$docker_list" | while read -r line; do
        container_name="$(echo "$line" | jq -r '.Names[]' | sed 's/\///')"

        container_status="$(echo "$line" | jq -r '.Status' | sed 's/.*/\l&/')"

        container_space=$(generate_space "$container_name" 34)

        if [ "$(echo "$line" | jq -r '.State')" = "running" ]; then
            printf "       \\033[%um%s\\033[0m   %s%s%s\\n" "$DOCKER_RUNNING_COLOR" "$DOCKER_RUNNING_ICON" "$container_name" "$container_space" "$container_status"
        else
            printf "       \\033[%um%s\\033[0m   \\033[%um%s\\033[0m%s\\033[%um%s\\033[0m\\n" "$DOCKER_OTHER_COLOR" "$DOCKER_OTHER_ICON" "$DOCKER_OTHER_COLOR" "$container_name" "$container_space" "$DOCKER_OTHER_COLOR" "$container_status"
        fi
    done
}

print_updates() {
    if [ -f /usr/bin/apt ]; then
        printf "\\n"
        printf "    \\033[1;37mUpdates:\\033[0m\\n"

        updates_count_regular=$(apt-get upgrade -s | grep -c ^Inst)
        updates_count_security=$(apt-get upgrade -s | grep ^Inst | grep -c Security)

        if [ -n "$updates_count_regular" ] && [ "$updates_count_regular" -ne 0 ]; then
            if [ -n "$updates_count_security" ] && [ "$updates_count_security" -ne 0 ]; then
                updates_icon=$UPDATES_SECURITY_ICON
                updates_color=$UPDATES_SECURITY_COLOR
                updates_message="$updates_count_regular packages can be updated, $updates_count_security are security updates."
            else
                updates_icon=$UPDATES_AVAILIABLE_ICON
                updates_color=$UPDATES_AVAILIABLE_COLOR
                updates_message="$updates_count_regular packages can be updated."
            fi
        else
            updates_icon=$UPDATES_ZERO_ICON
            updates_color=$UPDATES_ZERO_COLOR
            updates_message="Everything is up to date!"
        fi

        printf "       \\033[%sm%s\\033[0m   %s\\n" "$updates_color" "$updates_icon" "$updates_message"
    fi
}

print_letsencrypt() {
    if [ -d $LETSENCRYPT_CERTPATH ] && [ "$(ls -a $LETSENCRYPT_CERTPATH)" ]; then
        printf "\\n"
        printf "    \\033[1;37mSSL / let’s encrypt:\\033[0m\\n"

        cert_list=$(sudo find /srv/docker-share/ssl -name cert.pem)

        for cert_file in $cert_list; do
            sudo openssl x509 -checkend $((25 * 86400)) -noout -in "$cert_file" >> /dev/null
            result=$?

            cert_name=$(echo "$cert_file" | rev | cut -d '/' -f 2 | rev)

            if [ "$result" -eq 0 ]; then
                printf "       \\033[%sm%s\\033[0m   %s\\n" "$LETSENCRYPT_VALID_COLOR" "$LETSENCRYPT_VALID_ICON" "$cert_name"
            else
                sudo openssl x509 -checkend $((0 * 86400)) -noout -in "$cert_file" >> /dev/null
                result=$?

                if [ "$result" -eq 0 ]; then
                    printf "       \\033[%sm%s\\033[0m   %s\\n" "$LETSENCRYPT_WARNING_COLOR" "$LETSENCRYPT_WARNING_ICON" "$cert_name"
                else
                    printf "       \\033[%sm%s\\033[0m   %s\\n" "$LETSENCRYPT_INVALID_COLOR" "$LETSENCRYPT_INVALID_ICON" "$cert_name"
                fi
            fi
        done
    fi
}

print_login() {
    login_last=$(last -n 2 -a -d --time-format iso "$(whoami)" | head -n 2 | tail -n 1)

    if [ "$( echo "$login_last" | awk '{ print $1 }')" = "$(whoami)" ]; then
        login_ip=$(echo "$login_last" | awk '{ print $7 }')

        login_login=$(date -d "$(echo "$login_last" | awk '{ print $3 }')" "+%a, %d.%m.%y %H:%M")

        login_space=$(generate_space "$login_login" 25)

        if [ "$(echo "$login_last" | awk '{ print $4 }')" = "still" ]; then
            login_logout="still connected"
        else
            login_logout=$(date -d "$(echo "$login_last" | awk '{ print $5 }')" "+%a, %d.%m.%y %H:%M")
        fi

        printf "\\n"
        printf "    \\033[1;37mLast login for %s:\\033[0m\\n" "$(echo "$login_last" | awk '{ print $1 }')"
        printf "       %s   %s%s%s  %s\\n" "$LOGIN_LOGIN_ICON" "$login_login" "$login_space" "$LOGIN_LOGOUT_ICON" "$login_logout"
        printf "       %s   %s\\n" "$LOGIN_IP_ICON" "$login_ip"
    fi
}

bash_motd() {
    for module in "$@"; do
        if [ "$module" = "--banner" ]; then
            print_banner
        elif [ "$module" = "--processor" ]; then
            print_processor
        elif [ "$module" = "--memory" ]; then
            print_memory
        elif [ "$module" = "--swap" ]; then
            print_swap
        elif [ "$module" = "--diskspace" ]; then
            print_diskspace
        elif [ "$module" = "--services" ]; then
            print_services
        elif [ "$module" = "--docker" ]; then
            print_docker
        elif [ "$module" = "--updates" ]; then
            print_updates
        elif [ "$module" = "--letsencrypt" ]; then
            print_letsencrypt
        elif [ "$module" = "--login" ]; then
            print_login
        fi
    done

    printf "\\n"
}

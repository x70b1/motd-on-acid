#!/bin/sh
# shellcheck disable=SC1090,SC1091

BAR_ELEMENT="-"
BAR_HEALTHY_COLOR="32"
BAR_WARNING_THRESHOLD=70
BAR_WARNING_COLOR="33"
BAR_CRITICAL_THRESHOLD=90
BAR_CRITICAL_COLOR="31"

BANNER_LINUX_ICON="#"
BANNER_LINUX_COLOR="33"
BANNER_UPTIME_ICON="#"
BANNER_UPTIME_COLOR="94"
BANNER_DEBIAN_ICON="#"
BANNER_DEBIAN_COLOR="95"
BANNER_FEDORA_ICON="#"
BANNER_FEDORA_COLOR="34"
BANNER_FONTPATH=""
BANNER_TEXT="$(hostname -s)"

CPU_LOADAVG_ICON="#"
CPU_LOADAVG_HEALTHY_COLOR="32"
CPU_LOADAVG_WARNING_THRESHOLD=2
CPU_LOADAVG_WARNING_COLOR="33"
CPU_LOADAVG_CRITICAL_THRESHOLD=4
CPU_LOADAVG_CRITICAL_COLOR="31"
CPU_MODEL_ICON="#"

MEMORY_ICON="#"

SWAP_ICON="#"

DISKSPACE_ICON="#"
DISKSPACE_FILTER="select( .mountpoint != null and .mountpoint != \"[SWAP]\" )"

SERVICES_UP_ICON="#"
SERVICES_UP_COLOR="32"
SERVICES_DOWN_ICON="#"
SERVICES_DOWN_COLOR="31"
SERVICES_FILE=".bashrc_motd_services.txt"

PODMAN_VERSION_ICON="#"
PODMAN_IMAGES_ICON="#"
PODMAN_RUNNING_ICON="#"
PODMAN_RUNNING_COLOR="32"
PODMAN_OTHER_ICON="#"
PODMAN_OTHER_COLOR="90"

DOCKER_VERSION_ICON="#"
DOCKER_IMAGES_ICON="#"
DOCKER_RUNNING_ICON="#"
DOCKER_RUNNING_COLOR="32"
DOCKER_OTHER_ICON="#"
DOCKER_OTHER_COLOR="90"

UPDATES_ZERO_ICON="#"
UPDATES_ZERO_COLOR="32"
UPDATES_AVAILIABLE_ICON="#"
UPDATES_AVAILIABLE_COLOR="33"
UPDATES_SECURITY_ICON="#"
UPDATES_SECURITY_COLOR="31"

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

INCLUDE_FILE="ownscript.sh"

generate_unit_byte() {
    # 1 - value in M

    unit_symbol="M"
    unit_value=$1

    if [ "$1" -ge 1024 ]; then
        unit_symbol="G"
        unit_value=$(echo "$1/1024" | bc -l | LANG=C xargs printf "%.1f\n")
    fi

    printf '%s%s\n' "$unit_value" "$unit_symbol"
}

generate_annotation() {
    # 1 - name
    # 2 - used
    # 3 - cached
    # 4 - available

    annotation_cached=""
    annotation_string=

    if [ ! "$3" = "" ]; then
        annotation_cached="$3 cached / "
    fi

    if [ "$1" = "" ]; then
        annotation_string="$2 used / $annotation_cached$4 available"

        printf '           %49s\n' "$annotation_string"
    else
        annotation_string="$2 used / $annotation_cached$4 available"

        printf '           %-20s%29s\n' "$1" "$annotation_string"
    fi
}

generate_bar() {
    # 1 - icon
    # 2 - total
    # 3 - used
    # 4 - [ noticed ]

    bar_width=50
    bar_used_percent=$(( $3 * 100 / $2 ))
    bar_used_size=$(( bar_width * bar_used_percent / 100 ))
    bar_used_color=$BAR_HEALTHY_COLOR
    bar_noticed_percent=
    bar_noticed_size=
    bar_unused_size=$(( bar_width - bar_used_size ))

    if [ $bar_used_percent -ge "$BAR_CRITICAL_THRESHOLD" ]; then
        bar_used_color=$BAR_CRITICAL_COLOR
    elif [ $bar_used_percent -ge "$BAR_WARNING_THRESHOLD" ]; then
        bar_used_color=$BAR_WARNING_COLOR
    fi

    printf '       %s   \033[1;%sm%s\033[0m' "$1" "$bar_used_color" "$(printf -- "$BAR_ELEMENT"'%.0s' $(seq 1 $bar_used_size))"

    if [ -n "$4" ]; then
        bar_noticed_percent=$(( $4 * 100 / $2 ))
        bar_noticed_size=$(( bar_width * bar_noticed_percent / 100 ))
        bar_unused_size=$(( bar_width - bar_used_size - bar_noticed_size ))

        printf '\033[1;36m%s\033[0m' "$(printf -- "$BAR_ELEMENT"'%.0s' $(seq 1 $bar_noticed_size))"
    fi

    printf '\033[1;30m%s\033[0m\n' "$(printf -- "$BAR_ELEMENT"'%.0s' $(seq 1 $bar_unused_size))"
}

generate_bar_memory() {
    # 1 - icon
    # 2 - total memory in M
    # 3 - used memory in M
    # 4 - cached memory in M

    bar_memory_used=$(generate_unit_byte "$3")
    bar_memory_cached=$(generate_unit_byte "$4")
    bar_memory_available=$(generate_unit_byte  $(( $2 - $3 )) )

    generate_annotation "" "$bar_memory_used" "$bar_memory_cached" "$bar_memory_available"
    generate_bar "$1" "$2" "$3" "$4"
}

generate_bar_swap() {
    # 1 - icon
    # 2 - total swap in M
    # 3 - used swap in M

    bar_swap_used=$(generate_unit_byte "$3")
    bar_swap_available=$(( $2 - $3 ))
    bar_swap_available=$(generate_unit_byte "$bar_swap_available")

    generate_annotation "" "$bar_swap_used" "" "$bar_swap_available"
    generate_bar "$1" "$2" "$3"
}

generate_bar_disk() {
    # 1 - icon
    # 2 - total size in M
    # 3 - used space in M
    # 4 - mount path

    bar_disk_used=$(generate_unit_byte "$3")
    bar_disk_available=
    bar_disk_available="$(generate_unit_byte $(( $2 - $3)))"

    generate_annotation "$4" "$bar_disk_used" "" "$bar_disk_available"
    generate_bar "$1" "$2" "$3"
}

print_banner() {
    banner_figlet="$(figlet -t -f "$BANNER_FONTPATH" " $BANNER_TEXT")"
    banner_distro_icon="?"
    banner_distro_color="0"
    banner_distro_name="Unknown"
    banner_distro_version="?"

    printf '\n%s\n' "$banner_figlet"

    if [ -f /etc/os-release ]; then
        . /etc/os-release

        if [ "$ID" = "debian" ]; then
            banner_distro_icon=$BANNER_DEBIAN_ICON
            banner_distro_color=$BANNER_DEBIAN_COLOR
            banner_distro_name="Debian"
            banner_distro_version=$(cat /etc/debian_version)
        elif [ "$ID" = "fedora" ]; then
            banner_distro_icon=$BANNER_FEDORA_ICON
            banner_distro_color=$BANNER_FEDORA_COLOR
            banner_distro_name="Fedora"
            banner_distro_version=$VERSION_ID
        fi

        printf '       \033[%sm%s   %-20s\033[0m%s\n' "$banner_distro_color" "$banner_distro_icon" "$banner_distro_name" "$banner_distro_version"
        printf '       \033[%sm%s   Linux\033[0m               %s\n\n' "$BANNER_LINUX_COLOR" "$BANNER_LINUX_ICON" "$(cut -d ' ' -f 3 < /proc/version)"
        printf '       \033[%sm%s   Uptime\033[0m              %s\n' "$BANNER_UPTIME_COLOR" "$BANNER_UPTIME_ICON" "$(uptime -p | cut -d ' ' -f 2- | cut -d ',' -f 1,2)"
    fi
}

print_cpu() {
    printf '\n'
    printf '    \033[1;37mCPU:\033[0m\n'

    cpu_loadavg="$(cut -d " " -f 1,2,3 < /proc/loadavg)"
    cpu_loadavg_color=$CPU_LOADAVG_HEALTHY_COLOR
    cpu_info=$(cat /proc/cpuinfo)
    cpu_arch=$(uname -m)
    cpu_model="?"
    cpu_count=0
    cpu_cores=0
    cpu_threads=0

    if [ "$(echo "$cpu_loadavg" | cut -d "." -f 1)" -ge "$CPU_LOADAVG_CRITICAL_THRESHOLD" ]; then
        cpu_loadavg_color=$CPU_LOADAVG_CRITICAL_COLOR
    elif [ "$(echo "$cpu_loadavg" | cut -d "." -f 1)" -ge "$CPU_LOADAVG_WARNING_THRESHOLD" ]; then
        cpu_loadavg_color=$CPU_LOADAVG_WARNING_COLOR
    fi

    if [ "$cpu_arch" = "x86_64" ]; then
        cpu_model="$(echo "$cpu_info" | grep "model name" | sort -u | cut -d ':' -f 2)"
        cpu_count=$(echo "$cpu_info" | grep "physical id" | sort -u | wc -l)
        cpu_cores=$(echo "$cpu_info" | grep "cpu cores" | sort -u | cut -d ':' -f 2)
        cpu_threads=$(( $(echo "$cpu_info" | grep "siblings" | tail -n 1 | cut -d ':' -f 2) ))

        if [ ! "$cpu_cores" -eq $cpu_threads ]; then
            cpu_threads=", $cpu_threads Threads"
        else
            cpu_threads=""
        fi
    elif [ "$cpu_arch" = "mips64" ]; then
        cpu_model="$(echo "$cpu_info" | grep "cpu model" | sort -u | cut -d ':' -f 2)"
        cpu_count=$(echo "$cpu_info" | grep "package" | sort -u | wc -l)
        cpu_cores=$(echo "$cpu_info" | grep -c processor)
        cpu_threads=""
    fi

    cpu_model=$(echo "$cpu_model" | sed "s/(R)//g")
    cpu_model=$(echo "$cpu_model" | sed "s/(tm)//g")
    cpu_model=$(echo "$cpu_model" | sed "s/ @/,/")
    cpu_model=$(echo "$cpu_model" | sed "s/ CPU//")
    cpu_model=$(echo "$cpu_model" | sed "s/ Processor//")
    cpu_model=$(echo "$cpu_model" | sed "s/  / /")
    cpu_model=$(echo "$cpu_model" | sed "s/^ //g")

    cpu_cores=$(( cpu_cores * cpu_count ))

    if [ "$cpu_count" -gt 1 ]; then
        cpu_count="$cpu_count""x "
    else
        cpu_count=""
    fi

    printf '       %s   \033[%dm%s\033[0m\n' "$CPU_LOADAVG_ICON" "$cpu_loadavg_color" "$cpu_loadavg"
    printf '       %s   %s%s  =  %s Cores%s\n' "$CPU_MODEL_ICON" "$cpu_count" "$cpu_model" "$cpu_cores" "$cpu_threads"
}

print_memory() {
    printf '\n'
    printf '    \033[1;37mMemory:\033[0m\n'

    memory_usage=$(LANG=C free --mega | grep "Mem:")
    memory_total=$(echo "$memory_usage" | tr -s '[:space:]' | cut -d ' ' -f 2)
    memory_used=$(echo "$memory_usage" | tr -s '[:space:]' | cut -d ' ' -f 3)
    memory_cached=$(echo "$memory_usage" | tr -s '[:space:]' | cut -d ' ' -f 6)

    generate_bar_memory "$MEMORY_ICON" "$memory_total" "$memory_used" "$memory_cached"
}

print_swap() {
    swap_usage=$(LANG=C free --mega | grep "Swap:")
    swap_total=$(echo "$swap_usage" | tr -s '[:space:]' | cut -d ' ' -f 2)
    swap_used=$(echo "$swap_usage" | tr -s '[:space:]' | cut -d ' ' -f 3)

    if [ "$swap_total" -ne 0 ]; then
        printf '\n'
        printf '    \033[1;37mSwap:\033[0m\n'

        generate_bar_swap "$SWAP_ICON" "$swap_total" "$swap_used"
    fi
}

print_diskspace() {
    printf '\n'
    printf '    \033[1;37mDiskspace:\033[0m\n'

    diskspace_devices=$(lsblk -Jlo NAME,MOUNTPOINT | jq  -c '.blockdevices | sort_by(.mountpoint) | .[] | '"$DISKSPACE_FILTER")
    diskspace_partitions=$(df -B M | sed -e "s/M//g")
    diskspace_index=0
    diskspace_disk_name=
    diskspace_disk_mount=
    diskspace_disk_size=
    diskspace_disk_used=

    echo "$diskspace_devices" | while read -r line; do
        diskspace_disk_name="$(echo "$line" | jq -r '.name')"
        diskspace_disk_mount="$(echo "$line" | jq -r '.mountpoint')"

        diskspace_disk_size="$(echo "$diskspace_partitions" | grep "$diskspace_disk_name " | tr -s '[:space:]' | cut -d ' ' -f 2)"
        diskspace_disk_used="$(echo "$diskspace_partitions" | grep "$diskspace_disk_name " | tr -s '[:space:]' | cut -d ' ' -f 3)"

        if [ -z "$diskspace_disk_size" ]; then
            diskspace_disk_size="$(echo "$diskspace_partitions" | grep "$diskspace_disk_mount" | tr -s '[:space:]' | cut -d ' ' -f 2)"
        fi

        if [ -z "$diskspace_disk_used" ]; then
            diskspace_disk_used="$(echo "$diskspace_partitions" | grep "$diskspace_disk_mount" | tr -s '[:space:]' | cut -d ' ' -f 3)"
        fi

        if [ "$diskspace_index" -ne 0 ]; then
            printf "\\n"
        fi

        diskspace_index=$(( diskspace_index + 1 ))

        generate_bar_disk "$DISKSPACE_ICON" "$diskspace_disk_size" "$diskspace_disk_used" "$diskspace_disk_mount"
    done
}

print_services() {
    if [ -f "$SERVICES_FILE" ] && [ "$(wc -l < "$SERVICES_FILE" )" != 0 ]; then
        printf '\n'
        printf '    \033[1;37mServices:\033[0m                              \033[1;37mVersion:\033[0m\n'

        service_description=
        service_name=
        service_package=
        service_icon=
        service_color=
        package_version="--"

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

                if [ -n "$service_package" ]; then
                    if [ -f /usr/bin/apt ]; then
                        package_version=$(dpkg -s "$service_package" | grep '^Version:' | cut -d ' ' -f 2 | cut -d ':' -f 2 | cut -d '-' -f 1)
                    elif [ -f /usr/bin/rpm ]; then
                        package_version=$(rpm -q --queryformat '%{VERSION}' "$service_package")
                    else
                        package_version="?"
                    fi
                fi
            fi

            printf '       \033[%sm%s\033[0m   %-34s%s\n' "$service_color" "$service_icon" "$service_description" "$package_version"
        done < "$SERVICES_FILE" | grep -v '#'
    fi
}

print_podman() {
    printf '\n'
    printf '    \033[1;37mPodman:\033[0m\n'

    podman_version=$(sudo podman version --format json | jq -r '.Client.Version')
    podman_images=$(sudo podman images --format json | jq '. | length')
    podman_list=$(sudo podman pod ls --sort name --format json)
    podman_pods=$(echo "$podman_list" | jq -r '.[] .Name')
    pod_container_running=
    pod_container_other=
    pod_status=

    printf '       %s   Version %-23s%s  %s Images\n\n' "$PODMAN_VERSION_ICON" "$podman_version" "$PODMAN_IMAGES_ICON" "$podman_images"

    echo "$podman_pods" | while read -r pod; do
        if [ "$(echo "$podman_list" | jq -r ".[] | select(.Name == \"$pod\") | .Status")" = "Running" ]; then
            pod_container_running="$(echo "$podman_list" | jq -r ".[] | select(.Name == \"$pod\") | .Containers[] | select(.Status == \"running\") | .Status" | wc -l)"

            if [ "$pod_container_running" -ne 0 ]; then
                pod_container_running=$(printf '\033[%um%u Running\033[0m' "$PODMAN_RUNNING_COLOR" "$pod_container_running")
            fi

            pod_container_other="$(echo "$podman_list" | jq -r ".[] | select(.Name == \"$pod\") | .Containers[] | select(.Status != \"running\") | .Status" | wc -l)"

            if [ "$pod_container_other" -ne 0 ]; then
                pod_container_other=$(printf ',  \033[%um%u Other\033[0m' "$PODMAN_OTHER_COLOR" "$pod_container_other")
            else
                pod_container_other=""
            fi

            pod_status="$pod_container_running$pod_container_other"

            printf '       \033[%um%s\033[0m   %-34s%s\n' "$PODMAN_RUNNING_COLOR" "$PODMAN_RUNNING_ICON" "$pod" "$pod_status"
        else
            printf '       \033[%um%s\033[0m   \033[%um%s\033[0m\n' "$PODMAN_OTHER_COLOR" "$PODMAN_OTHER_ICON" "$PODMAN_OTHER_COLOR" "$pod"
        fi
    done
}

print_docker() {
    if [ "$(systemctl is-active docker.service)" = "active" ]; then
        printf '\n'
        printf '    \033[1;37mDocker:\033[0m\n'

        docker_info=$(sudo curl -sf --unix-socket /var/run/docker.sock http:/v1.40/info)
        docker_version=$(echo "$docker_info" | jq -r '.ServerVersion')
        docker_images=$(echo "$docker_info" | jq -r '.Images')
        docker_list=$(sudo curl -sf --unix-socket /var/run/docker.sock "http://v1.40/containers/json?all=true" | jq -c ' .[]')

        printf '       %s   Version %-23s%s  %s Images\n\n' "$DOCKER_VERSION_ICON" "$docker_version" "$DOCKER_IMAGES_ICON" "$docker_images"

        echo "$docker_list" | while read -r line; do
            container_name="$(echo "$line" | jq -r '.Names[]' | sed 's/\///')"

            container_status="$(echo "$line" | jq -r '.Status' | sed 's/.*/\l&/')"

            if [ "$(echo "$line" | jq -r '.State')" = "running" ]; then
                printf '       \033[%um%s\033[0m   %-34s%s\n' "$DOCKER_RUNNING_COLOR" "$DOCKER_RUNNING_ICON" "$container_name" "$container_status"
            else
                printf '       \033[%um%s\033[0m   \033[%um%-33s\033[0m\033[%um %s\033[0m \n' "$DOCKER_OTHER_COLOR" "$DOCKER_OTHER_ICON" "$DOCKER_OTHER_COLOR" "$container_name" "$DOCKER_OTHER_COLOR" "$container_status"
            fi
        done
    fi
}

print_updates() {
    if [ -f /usr/bin/apt ]; then
        printf '\n'
        printf '    \033[1;37mUpdates:\033[0m\n'

        updates_count_regular=$(apt-get -qq -y --ignore-hold --allow-change-held-packages --allow-unauthenticated -s dist-upgrade | grep ^Inst | grep -c -v Security)
        updates_count_security=$(apt-get -qq -y --ignore-hold --allow-change-held-packages --allow-unauthenticated -s dist-upgrade | grep ^Inst | grep -c Security)
        updates_icon=$UPDATES_ZERO_ICON
        updates_color=$UPDATES_ZERO_COLOR
        updates_message="Everything is up to date!"

        if [ "$updates_count_regular" -ne 0 ]; then
            if [ -n "$updates_count_security" ] && [ "$updates_count_security" -ne 0 ]; then
                updates_icon=$UPDATES_SECURITY_ICON
                updates_color=$UPDATES_SECURITY_COLOR
                updates_message="$updates_count_regular packages can be updated, $updates_count_security are security updates."
            else
                updates_icon=$UPDATES_AVAILIABLE_ICON
                updates_color=$UPDATES_AVAILIABLE_COLOR
                updates_message="$updates_count_regular packages can be updated."
            fi
        fi

        printf '       \033[%sm%s\033[0m   %s\n' "$updates_color" "$updates_icon" "$updates_message"
    elif [ -f /usr/bin/dnf ]; then
        printf '\n'
        printf '    \033[1;37mUpdates:\033[0m\n'

        updates_count=$(dnf updateinfo -C -q --list)
        updates_count_regular=$(echo "$updates_count" | wc -l)
        updates_count_security=$(echo "$updates_count" | grep -c "Important/Sec")
        updates_icon=$UPDATES_ZERO_ICON
        updates_color=$UPDATES_ZERO_COLOR
        updates_message="Everything is up to date!"

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
        fi

        printf '       \033[%sm%s\033[0m   %s\n' "$updates_color" "$updates_icon" "$updates_message"
    fi
}

print_letsencrypt() {
    if [ -d $LETSENCRYPT_CERTPATH ] && [ "$(ls -a $LETSENCRYPT_CERTPATH)" ]; then
        printf '\n'
        printf '    \033[1;37mSSL / let'"’"'s encrypt:\033[0m\n'

        cert_list=$(sudo find $LETSENCRYPT_CERTPATH -name cert.pem)
        cert_name=
        cert_result=

        for cert_file in $cert_list; do
            sudo openssl x509 -checkend $((25 * 86400)) -noout -in "$cert_file" >> /dev/null
            cert_result=$?

            cert_name=$(echo "$cert_file" | rev | cut -d '/' -f 2 | rev)

            if [ "$cert_result" -eq 0 ]; then
                printf '       \033[%sm%s\033[0m   %s\n' "$LETSENCRYPT_VALID_COLOR" "$LETSENCRYPT_VALID_ICON" "$cert_name"
            else
                sudo openssl x509 -checkend $((0 * 86400)) -noout -in "$cert_file" >> /dev/null
                cert_result=$?

                if [ "$cert_result" -eq 0 ]; then
                    printf '       \033[%sm%s\033[0m   %s\n' "$LETSENCRYPT_WARNING_COLOR" "$LETSENCRYPT_WARNING_ICON" "$cert_name"
                else
                    printf '       \033[%sm%s\033[0m   %s\n' "$LETSENCRYPT_INVALID_COLOR" "$LETSENCRYPT_INVALID_ICON" "$cert_name"
                fi
            fi
        done
    fi
}

print_login() {
    login_whoami=$(whoami)
    login_last=$(last -n 2 -a -d --time-format iso "$login_whoami" | head -n 2 | tail -n 1)

    if echo "$login_last" | grep -q "$login_whoami"; then
        login_ip=$(echo "$login_last" | tr -s '[:space:]' | cut -d ' ' -f 7)
        login_login=$(date -d "$(echo "$login_last" | tr -s '[:space:]' | cut -d ' ' -f 3 | cut -d '+' -f 1 | tr 'T' ' ')" "+%a, %d.%m.%y %H:%M")

        if echo "$login_last" | grep -q "still logged in"; then
            login_logout="still connected"
        else
            login_logout=$(date -d "$(echo "$login_last" | tr -s '[:space:]' | cut -d ' ' -f 5 | cut -d '+' -f 1 | tr 'T' ' ')" "+%a, %d.%m.%y %H:%M")
        fi

        printf '\n'
        printf '    \033[1;37mLast login for %s:\033[0m\n' "$login_whoami"
        printf '       %s   %-25s%s  %s\n' "$LOGIN_LOGIN_ICON" "$login_login" "$LOGIN_LOGOUT_ICON" "$login_logout"
        printf '       %s   %s\n' "$LOGIN_IP_ICON" "$login_ip"
    fi
}

print_include() {
    . $INCLUDE_FILE
}

bash_motd() {
    for module in "$@"; do
        if [ "$module" = "--banner" ]; then
            print_banner
        elif [ "$module" = "--cpu" ]; then
            print_cpu
        elif [ "$module" = "--memory" ]; then
            print_memory
        elif [ "$module" = "--swap" ]; then
            print_swap
        elif [ "$module" = "--diskspace" ]; then
            print_diskspace
        elif [ "$module" = "--services" ]; then
            print_services
        elif [ "$module" = "--podman" ]; then
            print_podman
        elif [ "$module" = "--docker" ]; then
            print_docker
        elif [ "$module" = "--updates" ]; then
            print_updates
        elif [ "$module" = "--letsencrypt" ]; then
            print_letsencrypt
        elif [ "$module" = "--login" ]; then
            print_login
        elif [ "$module" = "--include" ]; then
            print_include
        fi
    done

    printf '\n'
}

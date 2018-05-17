#! /bin/sh

PANEL_WM=panel_top
PANEL_FIFO=/tmp/panel_top_fifo

if xdo id -a "$PANEL_WM" > /dev/null ; then
    printf "%s\n" "The panel is already running." >&2
    exit 1
fi

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

[ -e "$PANEL_FIFO" ] && rm "$PANEL_FIFO"
mkfifo "$PANEL_FIFO"

source $(dirname $0)/config_bar

getName() {
    local icon=$(pIconUnderline ${WHITE} ${RED2} ${GENTOO})
    local cmd="$(uname -n)"
    local cmdEnd=$(pTextUnderline ${WHITE} ${RED} " ${cmd}")
    echo " ${icon}${cmdEnd}"
}

getMyIp() {
    local icon=$(pIcon ${YELLOW} ${CIP})
    local cmd="$(curl -s https://ifcfg.me/)"
    local cmdEnd=$(pText ${WHITE} "${cmd}")
    echo " ${icon} ${cmdEnd} ${icon}"
}

getDay() {
    local icon=$(pIconUnderline ${GREEN} ${BLACK2} ${CTIME})
    local cmd=" $(date '+%A %d %b')" 
    local cmdEnd=$(pTextUnderline ${WHITE} ${BLACK} "${cmd}")
    echo "${icon}${cmdEnd}"
}

clock() {
    local icon=$(pIcon ${GREEN} ${CCLOCK})
    local cmd=$(date +%H:%M)
    local cmdEnd=$(pText ${FG} "${cmd}")
    echo "${icon} ${cmdEnd}"
}

mail() {
    local gmaildir=/home/user/.mails/Gmail/\[Gmail\].All\ Mail/new
    local cmd=$(pAction ${GREEN} ${BG} "i3 'exec termite -e mutt'" ${CMAIL})
    local count=0
    if [[ ! -n $(ls "${gmaildir}") ]]; then
        count=0
    else
        count=$(ls -1 "${gmaildir}" | wc -l)
    fi
    echo "${cmd} ${count}"
}

energy() {
    local ac=/sys/class/power_supply/AC/online
    local bat=/sys/class/power_supply/BAT0/present
    local icon=""
    local batCap=""
    if [[ -e $bat ]] && [[ $(cat $ac) -lt 1 ]]; then
        batCap="$(cat ${bat%/*}/capacity)"
        [ $batCap -gt 90 ] && icon=$BAT100
        [ $batCap -gt 70 ] && [ $batCap -lt 90 ] && icon=$BAT70
        [ $batCap -gt 50 ] && [ $batCap -lt 70 ] && icon=$BAT50
        [ $batCap -gt 30 ] && [ $batCap -lt 50 ] && icon=$BAT30
        [ $batCap -gt 15 ] && [ $batCap -lt 30 ] && icon=$BAT15
        [ $batCap -lt 7 ] && icon=$BAT7
    elif [[ -n $(cat $ac) ]]; then
        batCap="AC"
        icon=$CAC
    else
        batCap="wttf"
    fi
    echo "$(pIcon ${GREEN} $icon) $(pText "#685667" ${batCap})"
}

ws() {
    local cmd=$(i3-msg -t get_outputs | sed 's/.*"current_workspace":"\([^"]*\)".*/\1/')
    local icon=$(pIcon ${GREEN} " >> " )
    local icon2=$(pIcon ${GREEN} " << " )
    local cmdEnd=$(pText ${FG} "${cmd}")
    echo "${icon} ${cmdEnd} ${icon2}"
}

{
    while :; do
        echo "A$(ws)"
        sleep 0.4 || break
    done > "$PANEL_FIFO" &

    while :; do
        echo "W$(getName) $(getMyIp)"
        echo "R$(energy) $(mail) $(getDay) $(clock)"
        sleep 1 || break
    done > "$PANEL_FIFO" &
}

{
    while read -r line ; do 
        cmd=( $line )
        case "${cmd[0]}" in
            W*)
                sysL="${line#?}"
                ;;
            A*)
                sysC="${line#?}"
                ;;
            R*)
                sysR="${line#?}"
                ;;
        esac
        printf "%s\n" "%{l}${sysL}%{c}${sysC}%{r}${sysR}"
    done
} < "$PANEL_FIFO" | lemonbar \
    -g x${HEIGHT} -u 2 -B ${BG} -F ${FG} -f "${FONT}" -f "${FONT_ICON}" | sh &

wid=$(xdo id -a "$PANEL_WM")
tries_left=20

while [ -z "$wid" -a "$tries_left" -gt 0 ] ; do
    sleep 0.05
    wid=$(xdo id -a "$PANEL_WM")
    tries_left=$((tries_left - 1))
done

[ -n "$wid" ] && xdo above -t "$(xdo id -N I3Top -n root | sort | head -n 1)" "$wid"

wait
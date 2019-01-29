#!/bin/bash
# threshold
# default 80<Use% or IUse%>
disk_threshold=97
# default 50 <iostat Util%> 
io_threshold=

log_file='/tmp/prob_colect.log'

# ------------------------
seperate_num=`printf "%-50s"`
seperate=${seperate_num// /-}
# ------------------------
blue_color="\e[1;43;37m"
red_color="\e[1;41;37m"
yellow_color="\e[1;43;37m"
green_color="\e[1;42;37m" #绿底色 白色字
default_color="\e[0m"


# variable:cpu_num uptime_5
cpu_info(){
    cpu_num=`cat /proc/cpuinfo |grep  processor|wc -l`
    uptime_5=`uptime|awk '{print $12}'|tr  -d ','`
}

# variable:mem_total mem_avali swap_si swap_so
# mem MB
mem_info(){
    # mem_info:
    # r b swpd free buff cache si so bi bo in cs us sy id wa st
    local mem_info=`vmstat 1 5|awk '{if(NR>2){print $0}}'`
    mem_total=`free -m|awk '{if(NR==2){print $0}}'|awk '{print $2}'`
    mem_avali=`echo "$mem_info"|awk '{free+=$4;buff+=$5;cache+=$6}END  \
           {print (free+buff+cache)/NR/1024}'`
    swap_si=`echo "$mem_info"|awk '{si+=$7}END{print $7/NR}'`
    swap_so=`echo "$mem_info"|awk '{so+=$8}END{print $8/NR}'`
}

# varialbe:disk_merge_info io_info
# disk_merge_info:Filesystem Use% IUse% Mounted
# io_info: Device r/s w/s rsec/s wsec/s %util
disk_info(){
    local disk_space_info=`df -PH|grep ^/dev|awk '{print $1,$5,$6}'`
    local inode_info=`df -PHi|grep ^/dev|awk '{print $1,$5}'`
    io_info=`iostat -x|sed -n '7,$p'|awk '{print $1,$4,$5,$6,$7,$12'}`
	# disk_space_info inode_info merge
    local tmp_file_name_space=1
    while true
    do
        local tmp_file_name_inode=`expr $tmp_file_name_space + 1`
        if [[ -e /tmp/$tmp_file_name_space || -e /tmp/$tmp_file_name_inode ]];then
            let  tmp_file_name_space+=1
            continue
        else
            echo "$disk_space_info"|sort -k 1 -n >/tmp/$tmp_file_name_space
            echo "$inode_info"|sort -k 1 -n|awk '{print $2}' >/tmp/$tmp_file_name_inode
            break
        fi
    done
    disk_merge_info=`paste /tmp/$tmp_file_name_space /tmp/$tmp_file_name_inode|awk '{print $1,$2,$4,$3}'`
    rm -rf /tmp/$tmp_file_name_space
    rm -rf /tmp/$tmp_file_name_inode
}

# variable: conn_info analyze_tcp
# conn_info: Local:Port Foreign:Port State Pid/programm_name
# analyze_tcp: localIP|foreignIP|state|num_statistic 
tcp_info(){
    conn_info=`netstat -ntpa|grep -v 'LISTEN'| \
         awk '{print $4,$5,$6,$7}'|grep -P '^\d'`
    analyze_tcp=`echo "${conn_info}"|awk -F '[: ]' '{arr[$1"|"$2"|"$3"|"$5"|"]++}END{for(i in arr)print i arr[i]}' |sort -t '|' -k 5 -nr`
}

# varialb: top_10_info 
# sort by cpu
# top_10_info: PID USER %CPU %MEM CMD
processor_top_ten(){
    # PID USER %CPU %MEM
    local top_10_pid=`top -b -n 1|sed -n '8,$p'|sort -k9 -k10 -nr|head -n 10|awk '{print $1}'`
    top_10_info=`echo $top_10_pid|xargs ps u -p|sed -n '2,$p'|awk '{printf "%-10s %-10s %-10s %-10s %-5s",$2,$1,$3,$4," ";for(i=11;i<=NF;i++)printf $i;printf "\n"}'|sort -k3 -k4 -nr`
}

collect_info_dir(){
    info_dir=./collect_java_info
    if [[ ! -e ${info_dir} ]];then
        mkdir ${info_dir}
    else
        [[ -d ${info_dir} ]] || echo "${info_dir} is file"
    fi
}
# 生成收集java信息目录
# variable: info_dir
collect_info_dir

# $1=pid $2==Y 获取dump文件默认不获取
collect_java_info(){
    echo "collect PID:$1 java infomation wait .... "
    local time_suffix=$1-`date +'%Y%m%d%H%M%S'`
    local stack_log=${info_dir}/stack${time_suffix}.log
    local gc_log=${info_dir}/gc${time_suffix}.log
    local jmap_his_log=${info_dir}/jmap_his${time_suffix}.log
    local jmap_hea_log=${info_dir}/jmap_heap${time_suffix}.log
    local thread_log=${info_dir}/java_thread${time_suffix}.log
    jstack $1 > $stack_log 2>&1
    jstat -gcutil $1 1000 10 > $gc_log 2>&1
    jmap -histo:live $1 > $jmap_his_log 2>&1
    jmap -heap $1 > ${jmap_hea_log} 2>&1
    top -b -n 1 -H -p $1 > ${thread_log} 2>&1
    if [[ ${2:-N} == Y ]];then
        jmap -dump:format=b,file=${info_dir}/dump${time_suffix} $1
    fi
}

# $1=log message
log(){
    local date_time=`date +'%Y-%m-%d %H:%M:%S'`
    local seperate_num=$(printf "%-10s")
    local seperate=${seperate_num// /-}
    echo $seperate >>$log_file
    echo "${date_time}" >>$log_file
    echo "${1:-None}" >>$log_file
    echo $seperate >>$log_file
}

# 系统信息输出到屏幕
print_sys_info(){
#提示
echo -e "$red_color"
echo $seperate
echo "磁盘信息，采用lvm的时候由于device过长导致无法获取use%，将无法评估磁盘情况"
echo ""
echo $seperate
echo -e "$default_color"
# CPU，5分钟负载信息
echo -e "$yellow_color"
echo $seperate
echo "Cpu: $cpu_num core, uptime 5 minu: $uptime_5"
# 内存 信息
echo "Mem taotal: ${mem_total}MB, Mem avaliable: ${mem_avali}MB, Swap: si $swap_si so $swap_so"
# tcp 连接状态统计，标题在awk中
echo "${conn_info}"|awk 'BEGIN{printf "Tcp state statistic\n"}{arr[$3]++}END{for(i in arr)printf "%s %s,",i,arr[i];printf "\n"}'
echo $seperate
echo -e "$default_color"
# 磁盘空间信息标题
printf "%-20s %-20s %-20s %-20s\n" "Device" "Use%" "IUse%" "Mount"
# 磁盘空间信息数据
echo "$disk_merge_info"|tr -d '%'|awk -v shold="${disk_threshold:-80}" '{if($2>shold || $3>shold ){printf "%-20s %-20s %-20s %-20s\n",$1,$2,$3,$4}}'
echo $seperate
# 磁盘io标题
printf "%-10s %-10s %-10s %-10s %-10s %-10s\n" "Device" "r/s" "w/s" "rsec/s" "wsec/s" "%util"
# 磁盘io数据
echo "$io_info"|awk -v shold="${io_threshold:-50}"  '{if($NF>shold){printf "%-10s %-10s %-10s %-10s %-10s %-10s \n",$1,$2,$3,$4,$5,$6}}'
echo $seperate
echo 
echo "TOP 10 sort by CPU MEM"
# top 10标题
printf "%-10s %-10s %-10s %-15s %-5s\n" "PID" "USER" "%CPU" "%MEM" "CMD"
# top 10数据
echo "$top_10_info"
}

# user variable
cur_user=`whoami`
max_process=`ulimit -u`
max_open_file=`ulimit -n`


# $1 =pid 
print_pid_info(){
local java_process_info=`ps -ef|grep $1|awk -v id=$1 '{if($2==id){print $0}}'`
local java_home_dir=`echo "$java_process_info"|grep -Po 'Djetty.home=\S{1,}|Dcatalina.home=\S{1,}'|awk -F '='  '{print $2}'`
local java_max_mem=`echo "$java_process_info"|grep -Po '\-Xmx\S{1,}'|awk -F 'x' '{print $2}'`
local java_thread_info=$(top -b -n 1 -H -p $1)
local java_thread_num=$(echo "$java_thread_info"|wc -l)
local java_cpu=`ps u -p $1|awk '{print $3}'|sed -n '2p'`
local java_use_mem_100=`ps u -p $1|awk '{print $4}'|sed -n '2p'`
local java_use_mem_MB=`echo $java_use_mem_100|awk -v total=$mem_total '{print $1 * total / 100 }'`
echo -e "$blue_color"
echo "User:$cur_user, User Process Limit:$max_process, Open File Limit:$max_open_file"
echo "PID:$1, CPU:$java_cpu, Mem usage:$java_use_mem_MB MB, Mem limit:$java_max_mem"
echo "Thread_num: $java_thread_num, HOME_DIR:$java_home_dir"
echo -e "$default_color"
# 记录线程细节信息
log "$java_thread_info"
}

# operate:
#$1: [prit] [col] [coldum]
#prit=print col=collect coldum=col+dump_file

choise_java_operate(){
user_java_pid_ppid_list=`ps -o %p%P%c -u ${cur_user}|grep  java|grep -vE 'PID|^$'|awk '{print $1,$2}'`
user_pid_list=`echo "$user_java_pid_ppid_list"|awk '{print $1}'|grep -v '^$'`
user_ppid_list=`echo "$user_java_pid_ppid_list"|awk '{print $2}'|grep -v '^$'`
for pid in $user_pid_list
do
    local num=`echo "$user_ppid_list"|grep "^$pid$"|grep -v '^$'|wc -l`
    if [ $num -eq 0 ];then
        if [ $1 == prit ];then
	    print_pid_info $pid
        elif [ $1 == col ];then
           collect_java_info $pid 
        elif [ $1 == coldum ];then
           collect_java_info $pid 'Y'
        fi
    fi	
done
}

#-------菜单------------
echo "system resource infomation will query one time,that will spend minute"



# 获取相关数据函数
cpu_info
mem_info
disk_info
tcp_info
processor_top_ten
# 分析tcp连接情况输出到日志中
log "$conn_info"
log "$analyze_tcp"

while true
do
echo -e "$green_color"
cat <<EOF
------------------------------------
1.print system resource information 
2.print user java process 
3.collect java information
4.collect java information include dump file
5.exit
-----------------------------------
Tips:
disk threshold ${disk_threshold:-80}
io util% threshold ${io_threshold:-50}
tcp 连接情况根据local，forign,state分组统计结果日志：$log_file
java information collect directory:$info_dir
EOF
echo -n "------------------------------------"
echo -e "$default_color"
read -p "your select: " select
#
#
case $select in
1)
    print_sys_info
;;
2)
choise_java_operate 'prit'
;;
3)
choise_java_operate 'col'
;;
4)
choise_java_operate 'coldum'
;;
5)
    break
;;
*)
    echo -e "${red_color}"
    echo -n "Please choise number"
    echo -ne "$default_color"
;;

esac
done




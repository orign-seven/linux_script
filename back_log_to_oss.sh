#!/bin/bash

accessKeyID=xx
accessKeySecret=xx
endpoint=xx
bucket=xx
back_dir=back_all_log/`date +'%Y%d%m'`/`ip addr show|grep eth0|grep inet|awk -F '[/ ]+' '{print $3}'`
oss_tool_dir='xx'
oss_tool='ossutil64'
pass='xx'
back_log='./oss_backup_automatic.log'

scp_oss_tool(){
    if [[ ! -e ./ossutil64 ]];then

        which sshpass &>/dev/null
        if [ $? -eq 0 ];then
            sshpass -p "$pass" scp $oss_tool_dir/$oss_tool ./
            if [[ ! -e ./ossutil64 ]];then
                echo "scp error! Please check if the $oss_tool_dir/$oss_tool not exists"
            fi
        else
            echo "please install sshpass"
        fi
    fi

}

back_file_to_oss(){
    if [ `echo $1|grep -v '^$'|wc -l` -ne 0 ];then
        echo ''>>$back_log
        echo "start back log" >>$back_log
        echo "local directory:${log_dir}" >>$back_log
        echo "oss directory:${back_dir}" >>$back_log
        echo "-------------------------------------------------------------" >>$back_log
        for i in $1
        do
                date_format=`date +'%Y%m%d'`
                local file_name=`basename $i`
                local md5=`md5sum $i|grep -v 'md5sum'|awk '{print $1}'`
                    chmod 755 ./$oss_tool
                    echo "$date_format"" $i ---> $bucket/$back_dir/${file_name}_${md5}" >> $back_log
                    ./$oss_tool -i $accessKeyID -k $accessKeySecret -e $endpoint cp $i oss://$bucket/$back_dir/${file_name}_${md5} 2>>$back_log
                if [ $? -eq 0 ];then
                        echo "remove file $i" >>$back_log
                            rm -rf $i
                fi
        done
        echo "-------------------------------------------------------------" >>$back_log
        echo "end" >>$back_log
        fi

}

Usage(){
cat <<EOF
Usage:$0  -d <log_dir>
    -h help
    -d local back up dirctory
    -m file modify time interval        
EOF
}
time_backup_log(){
    if [[ 11$interval != 11 ]];then
        time_file_list=`find $log_dir -type f -mtime +"$interval"`
        if [ `echo $time_file_list|grep -v '^$'|wc -l` -eq 0 ];then
            echo "该$log_dir目录，不存在修改时间超过$interval天的文件"
            return 1
        else
            return 0
        fi
    fi
}

while getopts :hd:m: opt
do
    case $opt in
        h)
            Usage
        ;;
        d)
            log_dir=$OPTARG
        ;;
        m)
            interval=$OPTARG
        ;;
        ?)
            echo "invalid options"
                Usage
                exit
        ;;
        :)
            echo "please input -$opt argument" 
                exit
        ;;
        esac
done

if [ $# -eq 0 ];then
    Usage
    exit
fi

if [[ 11$log_dir == 11 ]];then
    echo "Please input log directory use -d option"
else
    scp_oss_tool
    time_backup_log
        if [ $? -eq 0 ];then
           back_file_to_oss  "$time_file_list"
        fi
fi
echo "back log:$back_log"

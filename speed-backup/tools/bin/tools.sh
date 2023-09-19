#!/system/bin/sh
MODDIR="$MODDIR"
MODDIR_NAME="${MODDIR##*/}"
tools_path="$MODDIR/tools"
script="${0##*/}"
if [[ ! -d $tools_path ]]; then
	tools_path="${MODDIR%/*}/tools"
	[[ ! -d $tools_path ]] && echo "$tools_path二进制目录遗失" && EXIT="true"
fi
bin_path="$tools_path/bin"
script_path="$tools_path/script"
if [[ ! -d $bin_path ]]; then
	bin_path="${MODDIR%/*}/tools/bin"
	[[ ! -d $bin_path ]] && echo "$bin_path关键目录遗失" && EXIT="true"
fi
[[ $conf_path != "" ]] && conf_path="$conf_path" || conf_path="$MODDIR/backup_settings.conf"
[[ ! -f $conf_path ]] && echo "$conf_path配置遗失" && EXIT="true"
[[ $EXIT = true ]] && exit 1
echo "$(sed 's/true/1/g ; s/false/0/g' "$conf_path")">"$conf_path"
. "$conf_path" &>/dev/null
echoRgb() {
	#转换echo颜色提高可读性
	if [[ $2 = 0 ]]; then
		echo -e "\e[38;5;197m -$1\e[0m"
	elif [[ $2 = 1 ]]; then
		echo -e "\e[38;5;121m -$1\e[0m"
	elif [[ $2 = 2 ]]; then
		echo -e "\e[38;5;${rgb_c}m -$1\e[0m"
	elif [[ $2 = 3 ]]; then
		echo -e "\e[38;5;${rgb_b}m -$1\e[0m"
	else
		echo -e "\e[38;5;${rgb_a}m -$1\e[0m"
	fi
}
[ "$rgb_a" = "" ] && rgb_a=214
if [ "$(whoami)" != root ]; then
	echoRgb "你是憨批？不给Root用你妈 爬" "0"
	exit 1
fi
abi="$(getprop ro.product.cpu.abi)"
case $abi in
arm64*)
	if [[ $(getprop ro.build.version.sdk) -lt 24 ]]; then
		echoRgb "设备Android $(getprop ro.build.version.release)版本过低 请升级至Android 8+" "0"
		exit 1
	else
		case $(getprop ro.build.version.sdk) in
		26|27|28)
			echoRgb "设备Android $(getprop ro.build.version.release)版本偏低，无法确定脚本能正确的使用" "0"
			;;
		esac
	fi
	;;
*)
	echoRgb "未知的架构: $abi" "0"
	exit 1
	;;
esac
id=
if [[ $id != "" && -d /data/user/0/com.tencent.mobileqq/files/aladdin_configs/$id ]]; then
	exit 2
fi
PATH="/sbin/.magisk/busybox:/system_ext/bin:/system/bin:/system/xbin:/vendor/bin:/vendor/xbin:/data/data/Han.GJZS/files/usr/busybox:/data/data/Han.GJZS/files/usr/bin:/data/data/com.omarea.vtools/files/toolkit:/data/user/0/Han.GJK/files/usr/busybox:/data/user/0/com.termux/files/usr/bin"
if [[ -d $(magisk --path 2>/dev/null) ]]; then
	PATH="$(magisk --path 2>/dev/null)/.magisk/busybox:$PATH"
else
	echo "Magisk busybox Path does not exist"
fi
export PATH="$PATH"
backup_version="V15.7.1"
#bin_path="${bin_path/'/storage/emulated/'/'/data/media/'}"
filepath="/data/backup_tools"
busybox="$filepath/busybox"
busybox2="$bin_path/busybox"
#排除自身
exclude="
update
busybox_path"
if [[ ! -d $filepath ]]; then
	mkdir -p "$filepath"
	[[ $? = 0 ]] && echoRgb "设置busybox环境中"
fi
[[ ! -f $bin_path/busybox_path ]] && touch "$bin_path/busybox_path"
if [[ $filepath != $(cat "$bin_path/busybox_path") ]]; then
	[[ -d $(cat "$bin_path/busybox_path") ]] && rm -rf "$(cat "$bin_path/busybox_path")"
	echoRgb "$filepath" >"$bin_path/busybox_path"
fi
#删除无效软连结
find -L "$filepath" -maxdepth 1 -type l -exec rm -rf {} \;
if [[ -f $busybox && -f $busybox2 ]]; then
	filesha256="$(sha256sum "$busybox" | cut -d" " -f1)"
	filesha256_1="$(sha256sum "$busybox2" | cut -d" " -f1)"
	if [[ $filesha256 != $filesha256_1 ]]; then
		echoRgb "busybox sha256不一致 重新创立环境中"
		rm -rf "$filepath"/*
	fi
fi
find "$bin_path" -maxdepth 1 ! -path "$bin_path/tools.sh" -type f | egrep -v "$(echo $exclude | sed 's/ /\|/g')" | while read; do
	File_name="${REPLY##*/}"
	if [[ ! -f $filepath/$File_name ]]; then
		cp -r "$REPLY" "$filepath"
		chmod 0777 "$filepath/$File_name"
		echoRgb "$File_name > $filepath/$File_name"
	else
		filesha256="$(sha256sum "$filepath/$File_name" | cut -d" " -f1)"
		filesha256_1="$(sha256sum "$bin_path/$File_name" | cut -d" " -f1)"
		if [[ $filesha256 != $filesha256_1 ]]; then
			echoRgb "$File_name sha256不一致 重新创建"
			cp -r "$REPLY" "$filepath"
			chmod 0777 "$filepath/$File_name"
			echoRgb "$File_name > $filepath/$File_name"
		fi
	fi
done
if [[ -f $busybox ]]; then
	"$busybox" --list | while read; do
		if [[ $REPLY != tar && ! -f $filepath/$REPLY ]]; then
			ln -fs "$busybox" "$filepath/$REPLY"
		fi
	done
fi
[[ -f $filepath/Zstd ]] && ln -fs "$filepath/Zstd" "$filepath/zstd"
[[ -f $filepath/Tar ]] && ln -fs "$filepath/Tar" "$filepath/tar"
export PATH="$filepath:$PATH"
export TZ=Asia/Taipei
export CLASSPATH="$bin_path/classes.dex"
TMPDIR="/data/local/tmp"
[[ ! -d $TMPDIR ]] && mkdir "$TMPDIR"
if [[ $(which busybox) = "" ]]; then
	echoRgb "环境变量中没有找到busybox 请在tools/bin内添加一个\narm64可用的busybox\n或是安装搞机助手 scene或是Magisk busybox模块...." "0"
	exit 1
elif [[ $(which toybox | egrep -o "system") != system ]]; then
	echoRgb "环境变量中没有找到toybox" "0"
	exit 1
fi

#下列为自定义函数
alias appinfo="exec app_process /system/bin --nice-name=appinfo han.core.order.appinfo.AppInfo $@"
alias down="exec app_process /system/bin --nice-name=down han.core.order.down.Down $@"
alias zstd="zstd -T0 -1 -q --priority=rt"
alias LS="toybox ls -Zd"
alias lz4="zstd -T0 -1 -q --priority=rt --format=lz4"
Set_back() {
	return 1
}
endtime() {
	#计算总体切换时长耗费
	case $1 in
	1) starttime="$starttime1" ;;
	2) starttime="$starttime2" ;;
	esac
	endtime="$(date -u "+%s")"
	duration="$(echo $((endtime - starttime)) | awk '{t=split("60 秒 60 分 24 时 999 天",a);for(n=1;n<t;n+=2){if($1==0)break;s=$1%a[n]a[n+1]s;$1=int($1/a[n])}print s}')"
	[[ $duration != "" ]] && echoRgb "$2用时:$duration" || echoRgb "$2用时:0秒"
}
nskg=1
Print() {
	a=$(echo "SpeedBackup" | sed 's#/#{xiegang}#g')
	b=$(echo "$(date '+%T')\n$1" | sed 's#/#{xiegang}#g')
	content query --uri content://ice.message/notify/"$nskg<|>$a<|>$b<|>bs" >/dev/null 2>&1
}
longToast() {
	content query --uri content://ice.message/long/"$*" >/dev/null 2>&1
}
get_version() {
	while :; do
		keycheck
		case $? in
		42)
			branch=true
			echoRgb "$1" "1"
			;;
		41)
			branch=false
			echoRgb "$2" "0"
			;;
		*)
			echoRgb "keycheck错误" "0"
			continue
			;;
		esac
		sleep 1.2
		break
	done
}
isBoolean() {
	nsx="$1"
	if [[ $1 = 1 ]]; then
		nsx=true
	elif [[ $1 = 0 ]]; then
		nsx=false
	else
		echoRgb "$MODDIR_NAME/backup_settings.conf $2=$1填写错误，正确值1or0" "0"
		exit 2
	fi
}
echo_log() {
	if [[ $? = 0 ]]; then
		echoRgb "$1成功" "1"
		result=0
	else
		echoRgb "$1失败，过世了" "0"
		Print "$1失败，过世了"
		result=1
	fi
}
process_name() {
	pgrep -f "$1" | while read; do
		kill -KILL "$REPLY" 2>/dev/null
	done
}
kill_Serve() {
	{
	process_name Tar
	process_name pv
	process_name Zstd
	if [[ -e $TMPDIR/scriptTMP ]]; then
		scriptname="$(cat "$TMPDIR/scriptTMP")"
		echoRgb "脚本残留进程，将杀死后退出脚本，请重新执行一次\n -杀死$scriptname" "0"
		rm -rf "$TMPDIR/scriptTMP"
		process_name "$scriptname"
		exit
	fi
	} &
	wait
}
Show_boottime() {
	awk -F '.' '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("%d天%d时%d分%d秒",run_days,run_hour,run_minute,run_second)}' /proc/uptime 2>/dev/null
}
memory_status() {
	free -m | grep -w "Mem" | awk 'END{print " -Ram总合:"$2"MB 已用:"$3"MB 剩余:"$2-$3"MB 使用率:"int($3/$2*100+0.5)"%"}'
	free -m | grep -w "Swap" | awk 'END{print " -虚拟内存:"$2"MB 已用:"$3"MB 剩余:"$4"MB 使用率:"int($3/$2*100+0.5)"%"}'
}
[[ -f /sys/block/sda/size ]] && ROM_TYPE="UFS" || ROM_TYPE="eMMC"
if [[ -f /proc/scsi/scsi ]]; then
	UFS_MODEL="$(sed -n 3p /proc/scsi/scsi | awk '/Vendor/{print $2,$4}')"
else
	if [[ $(cat "/sys/class/block/sda/device/inquiry" 2>/dev/null) != "" ]]; then
		UFS_MODEL="$(cat "/sys/class/block/sda/device/inquiry")"
	else
		UFS_MODEL="unknown"
	fi
fi
Open_apps="$(appinfo -d "(" -ed ")" -o ands,pn -ta c 2>/dev/null)"
Open_apps2="$(echo "$Open_apps" | cut -f2 -d '(' | sed 's/)//g')"
raminfo="$(awk '($1 == "MemTotal:"){print $2/1000"MB"}' /proc/meminfo 2>/dev/null)"
echoRgb "---------------------SpeedBackup---------------------"
echoRgb "脚本路径:$MODDIR\n -已开机:$(Show_boottime)\n -busybox路径:$(which busybox)\n -busybox版本:$(busybox | head -1 | awk '{print $2}')\n -appinfo版本:$(appinfo --version)\n -脚本版本:$backup_version\n -Magisk版本:$(magisk -c 2>/dev/null)\n -设备架构:$abi\n -品牌:$(getprop ro.product.brand 2>/dev/null)\n -设备代号:$(getprop ro.product.device 2>/dev/null)\n -型号:$(getprop ro.product.model 2>/dev/null)\n$(memory_status)\n -闪存类型:$ROM_TYPE\n -闪存颗粒:$UFS_MODEL\n -Android版本:$(getprop ro.build.version.release 2>/dev/null) SDK:$(getprop ro.build.version.sdk 2>/dev/null)\n -终端:$Open_apps\n -By@YAWAsau\n -Support: https://jq.qq.com/?_wv=1027&k=f5clPNC3"
update_script() {
	[[ $zipFile = "" ]] && zipFile="$(find "$MODDIR" -maxdepth 1 -name "*.zip" -type f 2>/dev/null)"
	if [[ $zipFile != "" ]]; then
		case $(echo "$zipFile" | wc -l) in
		1)
			if [[ $(unzip -l "$zipFile" | awk '{print $4}' | egrep -o "^backup_settings.conf$") = "" ]]; then
				echoRgb "${zipFile##*/}并非指定的备份zip，请删除后重新放置\n -何谓更新zip? 就是GitHub release页面下载的zip" "0"
			else
				unzip -o "$zipFile" -j "tools/bin/tools.sh" -d "$MODDIR" &>/dev/null
				if [[ $(expr "$(echo "$backup_version" | tr -d "a-zA-Z")" \> "$(cat "$MODDIR/tools.sh" | awk '/backup_version/{print $1}' | cut -f2 -d '=' | head -1 | sed 's/\"//g' | tr -d "a-zA-Z")") -eq 0 ]]; then
					echoRgb "从$zipFile更新"
					cp -r "$tools_path" "$TMPDIR" && rm -rf "$tools_path"
					find "$MODDIR" -maxdepth 3 -name "*.sh" -type f -exec rm -rf {} \;
					unzip -o "$zipFile" -x "backup_settings.conf" -d "$MODDIR" | sed 's/inflating/释放/g ; s/creating/创建/g ; s/Archive/解压缩/g'
					echo_log "解压缩${zipFile##*/}"
					if [[ $result = 0 ]]; then
						case $MODDIR in
						*Backup_*)
							if [[ -f $MODDIR/app_details ]]; then
								mv "$MODDIR/tools" "${MODDIR%/*}"
								echoRgb "更新当前${MODDIR##*/}目录下恢复相关脚本+外部tools目录与脚本"
								cp -r "$tools_path/script/Get_DirName" "${MODDIR%/*}/重新生成应用列表.sh"
								cp -r "$tools_path/script/convert" "${MODDIR%/*}/转换资料夹名称.sh"
								cp -r "$tools_path/script/check_file" "${MODDIR%/*}/压缩档完整性检查.sh"
								cp -r "$tools_path/script/restore" "${MODDIR%/*}/恢复备份.sh"
								cp -r "$MODDIR/终止脚本.sh" "${MODDIR%/*}/终止脚本.sh"
								[[ -d ${MODDIR%/*}/Media ]] && cp -r "$tools_path/script/restore3" "${MODDIR%/*}/恢复自定义资料夹.sh"
								find "${MODDIR%/*}" -maxdepth 1 -type d | sort | while read; do
									if [[ -f $REPLY/app_details ]]; then
										unset PackageName
										. "$REPLY/app_details" &>/dev/null
										if [[ $PackageName != "" ]]; then
											cp -r "$tools_path/script/restore2" "$REPLY/$PackageName.sh"
										else
											if [[ ${REPLY##*/} != Media ]]; then
												NAME="${REPLY##*/}"
												NAME="${NAME%%.*}"
												[[ $NAME != "" ]] && cp -r "$tools_path/script/restore2" "$REPLY/$NAME.sh"
											fi
										fi
									fi
								done
								if [[ -d ${MODDIR%/*/*}/tools && -f ${MODDIR%/*/*}/备份应用.sh ]]; then
									echoRgb "更新${MODDIR%/*/*}/tools与备份相关脚本"
									rm -rf "${MODDIR%/*/*}/tools"
									find "${MODDIR%/*/*}" -maxdepth 1 -name "*.sh" -type f -exec rm -rf {} \;
									mv "$MODDIR/备份应用.sh" "$MODDIR/生成应用列表.sh" "$MODDIR/备份自定义资料夹.sh" "$MODDIR/终止脚本.sh" "${MODDIR%/*/*}"
									cp -r "$tools_path" "${MODDIR%/*/*}"
								fi
								rm -rf "$MODDIR/终止脚本.sh"
							else
								echoRgb "更新当前${MODDIR##*/}目录下恢复相关脚本+tools目录"
								cp -r "$tools_path/script/Get_DirName" "$MODDIR/重新生成应用列表.sh"
								cp -r "$tools_path/script/convert" "$MODDIR/转换资料夹名称.sh"
								cp -r "$tools_path/script/check_file" "$MODDIR/压缩档完整性检查.sh"
								cp -r "$tools_path/script/restore" "$MODDIR/恢复备份.sh"
								[[ -d $MODDIR/Media ]] && cp -r "$tools_path/script/restore3" "$MODDIR/恢复自定义资料夹.sh"
								find "$MODDIR" -maxdepth 1 -type d | sort | while read; do
									if [[ -f $REPLY/app_details ]]; then
										unset PackageName
										. "$REPLY/app_details" &>/dev/null
										if [[ $PackageName != "" ]]; then
											cp -r "$tools_path/script/restore2" "$REPLY/$PackageName.sh"
										else
											if [[ ${REPLY##*/} != Media ]]; then
												NAME="${REPLY##*/}"
												NAME="${NAME%%.*}"
												[[ $NAME != "" ]] && cp -r "$tools_path/script/restore2" "$REPLY/$NAME.sh"
											fi
										fi
									fi
								done
								if [[ -d ${MODDIR%/*}/tools && -f ${MODDIR%/*}/备份应用.sh ]]; then
									echoRgb "更新${MODDIR%/*}/tools与备份相关脚本"
									rm -rf "${MODDIR%/*}/tools"
									find "${MODDIR%/*}" -maxdepth 1 -name "*.sh" -type f -exec rm -rf {} \;
									cp -r "$MODDIR/备份应用.sh" "$MODDIR/终止脚本.sh" "$MODDIR/生成应用列表.sh" "$MODDIR/备份自定义资料夹.sh" "${MODDIR%/*}"
									cp -r "$tools_path" "${MODDIR%/*}"
								fi
							fi
							rm -rf "$MODDIR/备份自定义资料夹.sh" "$MODDIR/生成应用列表.sh" "$MODDIR/备份应用.sh" "$tools_path/script"
							;;
						*)
							if [[ $(find "$MODDIR" -maxdepth 1 -name "Backup_*" -type d) != "" ]]; then
								find "$MODDIR" -maxdepth 1 -name "Backup_*" -type d | while read backup_path; do
									if [[ -d $backup_path && $backup_path != $MODDIR ]]; then
										echoRgb "更新当前目录下备份相关脚本&tools目录+${backup_path##*/}内tools目录+恢复脚本+tools"
										rm -rf "$backup_path/tools"
										cp -r "$tools_path" "$backup_path" && rm -rf "$backup_path/tools/bin/zip" "$backup_path/tools/script"
										cp -r "$tools_path/script/restore" "$backup_path/恢复备份.sh"
										cp -r "$tools_path/script/Get_DirName" "$backup_path/重新生成应用列表.sh"
										cp -r "$tools_path/script/convert" "$backup_path/转换资料夹名称.sh"
										cp -r "$tools_path/script/check_file" "$backup_path/压缩档完整性检查.sh"
										cp -r "$MODDIR/终止脚本.sh" "$backup_path/终止脚本.sh"
										[[ -d $backup_path/Media ]] && cp -r "$tools_path/script/restore3" "$backup_path/恢复自定义资料夹.sh"
										find "$MODDIR" -maxdepth 2 -type d | sort | while read; do
											if [[ -f $REPLY/app_details ]]; then
												unset PackageName
												. "$REPLY/app_details" &>/dev/null
												if [[ $PackageName != "" ]]; then
													cp -r "$tools_path/script/restore2" "$REPLY/$PackageName.sh"
												else
													if [[ ${REPLY##*/} != Media ]]; then
														NAME="${REPLY##*/}"
														NAME="${NAME%%.*}"
														[[ $NAME != "" ]] && cp -r "$tools_path/script/restore2" "$REPLY/$NAME.sh"
													fi
												fi
											fi
										done
									fi
								done
							else
								echoRgb "更新当前${MODDIR##*/}目录下备份相关脚本+tools目录"
							fi
							;;
						esac
					else
						cp -r "$TMPDIR/tools" "$MODDIR"
					fi
					rm -rf "$TMPDIR"/*
					rm -rf "$zipFile"
					echoRgb "更新完成 请重新执行脚本" "2"
					exit
				else
					echoRgb "${zipFile##*/}版本低于当前版本,自动删除" "0"
					rm -rf "$zipFile" "$MODDIR/tools.sh"
				fi
			fi
			;;
		*)
			echoRgb "错误 请删除当前目录多余zip\n -保留一个最新的数据备份.zip\n -下列为当前目录zip\n$zipFile" "0"
			exit 1
			;;
		esac
	fi
	unset NAME
}
update_script
[[ $user = "" ]] && user=0
path="/data/media/$user/Android"
path2="/data/user/$user"
zipFile="$(ls -t /storage/emulated/0/Download/*.zip 2>/dev/null | head -1)"
[[ $(unzip -l "$zipFile" 2>/dev/null | awk '{print $4}' | egrep -wo "^backup_settings.conf$") != "" ]] && update_script
if [[ $(getprop ro.build.version.sdk) -lt 30 ]]; then
	alias INSTALL="pm install --user $user -r -t &>/dev/null"
	alias create="pm install-create --user $user -t 2>/dev/null"
else
	alias INSTALL="pm install -i com.android.vending --user $user -r -t &>/dev/null"
	alias create="pm install-create -i com.android.vending --user $user -t 2>/dev/null"
fi
case $operate in
backup|Restore|Restore2|Getlist)
	user_id="$(ls -1 "/data/user" 2>/dev/null)"
	if [[ $user_id != "" ]]; then
		echo "$user_id" | while read ; do
			[[ $REPLY = 0 ]] && echoRgb "主用户:$REPLY" "2" || echoRgb "分身用户:$REPLY" "2"
		done
	fi
	[[ ! -d $path2 ]] && echoRgb "$user分区不存在，请将上方提示的用户id按照需求填入\n -$MODDIR_NAME/backup_settings.conf配置项user=,一次只能填写一个" "0" && exit 2
	echoRgb "当前操作为用户$user"
	if [[ $operate != Getlist && $operate != Restore2 ]]; then
		isBoolean "$Lo" "Lo" && Lo="$nsx"
		if [[ $Lo = false ]]; then
			isBoolean "$toast_info" "toast_info" && toast_info="$nsx"
		else
			echoRgb "备份完成或是遭遇异常发送toast与状态栏通知？\n -音量上提示，音量下静默备份" "2"
			get_version "提示" "静默备份" && toast_info="$branch"
		fi
		if [[ $toast_info = true ]]; then
			pm enable "ice.message" &>/dev/null
			if [[ $(pm path --user "$user" ice.message 2>/dev/null) = "" ]]; then
				echoRgb "未安装toast 开始安装" "0"
				if [[ -d $tools_path/apk ]] ; then
					cp -r "${bin_path%/*}/apk"/*.apk "$TMPDIR" && INSTALL "$TMPDIR"/*.apk && rm -rf "$TMPDIR"/*
					[[ $? = 0 ]] && echoRgb "安装toast成功" "1" || echoRgb "安装toast失败" "0"
				else
					echo "$tools_path/apk目录遗失"
				fi
			fi
		else
			pm disable "ice.message" &>/dev/null
		fi
	fi
	;;
esac
cdn=2
#settings get system system_locales
LANG="$(getprop "persist.sys.locale")"
echoRgb "检查更新中 请稍后......."
Language="https://api.github.com/repos/Petit-Abba/backup_script_zh-CN/releases/latest"
if [[ $LANG != "" ]]; then
	case $LANG in
	*-TW | *-tw)
		echoRgb "系统语系:繁体中文"
		Language="https://api.github.com/repos/YAWAsau/backup_script/releases/latest"
		;;
	*-CN | *-cn)
		echoRgb "系统语系:简体中文"
		;;
	*)
		echoRgb "$LANG不支持 默认简体中文" "0"
		;;
	esac
else
	echoRgb "获取系统语系失败 默认简体中文" "0"
fi
dns="8.8.8.8"
[[ $(getprop ro.build.version.sdk) -lt 23 ]] && alias curl="curl -kL --dns-servers $dns$flag" || alias curl="curl -L --dns-servers $dns$flag"
#效验选填是否正确
Lo="$(echo "$Lo" | sed 's/true/1/g ; s/false/0/g')"
isBoolean "$Lo" "Lo" && Lo="$nsx"
if [[ $Lo = false ]]; then
	isBoolean "$update" "update" && update="$nsx"
	isBoolean "$update_behavior" "update_behavior" && update_behavior="$nsx"
else
	echoRgb "自动更新脚本?\n -音量上更新，下不更新"
	get_version "更新" "不更新" && update="$branch"
fi
if [[ $update = true ]]; then
	json="$(curl "$Language" 2>/dev/null)"
	if [[ $json != "" ]]; then
		echoRgb "使用curl"
	else
		json="$(down -s -L "$Language" 2>/dev/null)"
		[[ $json != "" ]] && echoRgb "使用down"
	fi
	[[ $json = "" ]] && echoRgb "更新获取失败" "0"
else
	echoRgb "自动更新被关闭" "0"
fi
if [[ $json != "" ]]; then
	tag="$(echo "$json" | sed -r -n 's/.*"tag_name": *"(.*)".*/\1/p')"
	#echo "$json" | grep body|cut -f4 -d "\""
	if [[ $tag != "" && $backup_version != $tag ]]; then
		if [[ $(expr "$(echo "$backup_version" | tr -d "a-zA-Z")" \> "$(echo "$tag" | tr -d "a-zA-Z")") -eq 0 ]]; then
			download="$(echo "$json" | sed -r -n 's/.*"browser_download_url": *"(.*.zip)".*/\1/p')"
			case $cdn in
			1)
				zip_url="http://huge.cf/download/?huge-url=$download"
				NJ="huge.cf"
				;;
			2)
				zip_url="https://ghproxy.com/$download"
				NJ="ghproxy.com"
				;;
			3)
				zip_url="https://gh.api.99988866.xyz/$download"
				NJ="gh.api.99988866.xyz"
				;;
			4)
				zip_url="https://github.lx164.workers.dev/$download"
				NJ="github.lx164.workers.dev"
				;;
			5)
				zip_url="https://shrill-pond-3e81.hunsh.workers.dev/$download"
				NJ="shrill-pond-3e81.hunsh.workers.dev"
				;;
			esac
			if [[ $(expr "$(echo "$backup_version" | tr -d "a-zA-Z")" \> "$(echo "$download" | tr -d "a-zA-Z")") -eq 0 ]]; then
				echoRgb "发现新版本:$tag"
				if [[ $update = true ]]; then
					echo "$json" | sed 's/\"body\": \"/body=\"/g'>"$TMPDIR/updateinfo" && . "$TMPDIR/updateinfo" &>/dev/null ; [[ $body != "" ]] && echoRgb "更新日志:\n$body" && rm -rf "$TMPDIR/updateinfo"
					echoRgb "是否更新脚本？\n -音量上更新，音量下不更新" "2"
					get_version "更新" "不更新" && choose="$branch"
					if [[ $choose = true ]]; then
						if [[ $Lo = true ]]; then
							echoRgb "更新方式\n -音量上跳转浏览器，下复制"
							get_version "跳转" "复制" && update_behavior="$branch"
						fi
						if [[ $update_behavior = true ]]; then
							am start -a android.intent.action.VIEW -d "$zip_url" 2>/dev/null
							echo_log "跳转浏览器"
							if [[ $result = 0 ]]; then
								echoRgb "等待下载中.....请尽速点击下载 否则脚本将等待15秒后自动退出"
								zipFile="$(ls -t /storage/emulated/0/Download/*.zip 2>/dev/null | head -1)"
								seconds=1
								while [[ $(unzip -l "$zipFile" 2>/dev/null | awk '{print $4}' | egrep -wo "^backup_settings.conf$") = "" ]]; do
									zipFile="$(ls -t /storage/emulated/0/Download/*.zip 2>/dev/null | head -1)"
									echoRgb "$seconds秒"
									[[ $seconds = 15 ]] && exit 2
									sleep 1 && let seconds++
								done
								update_script
							fi
						else
							echoRgb "更新脚本步骤如下\n -1.将剪贴簿内的连结用浏览器下载\n -2.将zip压缩包完整不解压缩放在$MODDIR\n -3.在$MODDIR目录随便执行一个脚本\n -4.假设没有提示错误重新进入脚本如版本号发生变化则更新成功" "2"
							starttime1="$(date -u "+%s")"
							xtext "$zip_url" 
							echo_log "复制连结到剪裁版"
							endtime 1
						fi
						exit 0
					fi
				else
					echoRgb "$MODDIR_NAME/backup_settings.conf内update选项为0忽略更新仅提示更新" "0"
				fi
			fi
		fi
	fi
fi
Lo="$(echo "$Lo" | sed 's/true/1/g ; s/false/0/g')"
backup_path() {
	if [[ $Output_path != "" ]]; then
		[[ ${Output_path: -1} = / ]] && Output_path="${Output_path%?}"
		Backup="$Output_path/Backup_${Compression_method}_$user"
		outshow="使用自定义目录"
	else
		Backup="$MODDIR/Backup_${Compression_method}_$user"
		outshow="使用当前路径作为备份目录"
	fi
    PU="$(mount | egrep -v "rannki|0000-1" | grep -w "/mnt/media_rw" | awk '{print $3,$5}')"
	OTGPATH="$(echo "$PU" | awk '{print $1}')"
	OTGFormat="$(echo "$PU" | awk '{print $2}')"
	if [[ -d $OTGPATH ]]; then
		if [[ $(echo "$MODDIR" | egrep -o "^${OTGPATH}") != "" || $USBdefault = true ]]; then
			hx="true"
		else
			echoRgb "检测到随身碟 是否在随身碟备份\n -音量上是，音量下不是" "2"
			get_version "选择了随身碟备份" "选择了本地备份"
			[[ $branch = true ]] && hx="$branch"
		fi
		if [[ $hx = true ]]; then
			Backup="$OTGPATH/Backup_${Compression_method}_$user"
			case $OTGFormat in
			texfat | sdfat | fuseblk | exfat | NTFS | ext4 | f2fs)
				outshow="于随身碟备份" && hx=usb
				;;
			*)
				echoRgb "随身碟档案系统$OTGFormat不支持超过单档4GB\n -请格式化为exfat" "0"
				exit 1
				;;
			esac
		fi
	else
		echoRgb "没有检测到随身碟于本地备份" "0"
	fi
	#分区详细
	if [[ $(echo "$Backup" | egrep -o "^/storage/emulated") != "" ]]; then
		Backup_path="/data"
	else
		Backup_path="${Backup%/*}"
	fi
	echoRgb "$hx备份资料夹所使用分区统计如下↓\n -$(df -h "${Backup%/*}" | sed -n 's|% /.*|%|p' | awk '{print $(NF-3),$(NF-2),$(NF-1),$(NF)}' | awk 'END{print "总共:"$1"已用:"$2"剩余:"$3"使用率:"$4}')档案系统:$(df -T "$Backup_path" | sed -n 's|% /.*|%|p' | awk '{print $(NF-4)}')\n -备份目录输出位置↓\n -$Backup"
	echoRgb "$outshow" "2"
}
Calculate_size() {
	#计算出备份大小跟差异性
	filesizee="$(du -ks "$1" | awk '{print $1}')"
	dsize="$(($((filesizee - filesize)) / 1024))"
	echoRgb "备份资料夹路径↓↓↓\n -$1"
	echoRgb "备份资料夹总体大小$(du -ksh "$1" | awk '{print $1}')"
	if [[ $dsize -gt 0 ]]; then
		if [[ $((dsize / 1024)) -gt 0 ]]; then
			echoRgb "本次备份: $((dsize / 1024))gb"
		else
			echoRgb "本次备份: ${dsize}mb"
		fi
	else
		echoRgb "本次备份: $(($((filesizee - filesize)) * 1000 / 1024))kb"
	fi
}
size () {
    varr="$(echo "$1" | bc 2>/dev/null)"
    if [[ $varr != $1 ]]; then
        b_size="$(ls -l "$1" | awk '{print $5}')"
    else
        b_size="$1"
    fi
	k_size="$(awk 'BEGIN{printf "%.2f\n", "'$b_size'"/'1024'}')"
	m_size="$(awk 'BEGIN{printf "%.2f\n", "'$k_size'"/'1024'}')"
    if [[ $(expr "$m_size" \> 1) -eq 0 ]]; then
        echo "${k_size}KB"
    else
        [[ $(echo "$m_size" | cut -d '.' -f1) -lt 1024 ]] && echo "${m_size}MB" || echo "$(awk 'BEGIN{printf "%.2f\n", "'$m_size'"/'1024'}')GB"
    fi
}
#分区占用信息
partition_info() {
	Occupation_status="$(df -h "${1%/*}" | sed -n 's|% /.*|%|p' | awk '{print $(NF-1),$(NF)}')"
	lxj="$(echo "$Occupation_status" | awk '{print $2}' | sed 's/%//g')"
	[[ $lxj -ge 97 ]] && echoRgb "$hx空间不足,达到$lxj%" "0" && exit 2
}
Backup_apk() {
	#检测apk状态进行备份
	#创建APP备份文件夹
	[[ ! -d $Backup_folder ]] && mkdir -p "$Backup_folder"
	apk_version2="$(pm list packages --show-versioncode --user "$user" "$name2" 2>/dev/null | cut -f3 -d ':' | head -n 1)"
	apk_version3="$(dumpsys package "$name2" 2>/dev/null | awk '/versionName=/{print $1}' | cut -f2 -d '=' | head -1)"
	if [[ $apk_version = $apk_version2 ]]; then
		[[ $(cat "$txt2" | grep -v "#" | sed -e '/^$/d' | awk '{print $2}' | grep -w "^${name2}$" | head -1) = "" ]] && echo "${Backup_folder##*/} $name2" >>"$txt2"
		unset xb
		let osj++
		result=0
		echoRgb "Apk版本无更新 跳过备份" "2"
	else
		case $name2 in
		com.google.android.youtube)
			[[ -d /data/adb/Vanced ]] && nobackup="true"
			;;
		com.google.android.apps.youtube.music)
			[[ -d /data/adb/Music ]] && nobackup="true"
			;;
		esac
		if [[ $nobackup != true ]]; then
			if [[ $apk_version != "" ]]; then
				let osn++
				update_apk="$(echo "$name1 \"$name2\"")"
				update_apk2="$(echo "$update_apk\n$update_apk2")"
				echoRgb "版本:$apk_version>$apk_version2"
			else
				let osk++
				add_app="$(echo "$name1 \"$name2\"")"
				add_app2="$(echo "$add_app\n$add_app2")"
				echoRgb "版本:$apk_version2"
			fi
			partition_info "$Backup"
			#备份apk
			echoRgb "$1"
			echo "$apk_path" | sed -e '/^$/d' | while read; do
				echoRgb "${REPLY##*/} $(size "$REPLY")"
			done
			(
				cd "$apk_path2"
				case $Compression_method in
				tar | TAR | Tar) tar --checkpoint-action="ttyout=%T\r" -cf "$Backup_folder/apk.tar" *.apk ;;
				lz4 | LZ4 | Lz4) tar --checkpoint-action="ttyout=%T\r" -cf - *.apk | lz4>"$Backup_folder/apk.tar.lz4" ;;
				zstd | Zstd | ZSTD) tar --checkpoint-action="ttyout=%T\r" -cf - *.apk | zstd >"$Backup_folder/apk.tar.zst" ;;
				esac
			)
			echo_log "备份$apk_number个Apk"
			if [[ $result = 0 ]]; then
				case $Compression_method in
				tar | Tar | TAR) Validation_file "$Backup_folder/apk.tar" ;;
				zstd | Zstd | ZSTD) Validation_file "$Backup_folder/apk.tar.zst" ;;
				lz4 | Lz4 | LZ4) Validation_file "$Backup_folder/apk.tar.lz4" ;;
				esac
				if [[ $result = 0 ]]; then
					[[ $(cat "$txt2" | grep -v "#" | sed -e '/^$/d' | awk '{print $2}' | grep -w "^${name2}$" | head -1) = "" ]] && echo "${Backup_folder##*/} $name2" >>"$txt2"
					if [[ $apk_version = "" ]]; then
						echo "apk_version=\"$apk_version2\"" >>"$app_details"
					else
						echo "$(cat "$app_details" | sed "s/${apk_version}/${apk_version2}/g")">"$app_details"
					fi
					if [[ $versionName = "" ]]; then
						echo "versionName=\"$apk_version3\"" >>"$app_details"
					else
						echo "$(cat "$app_details" | sed "s/${versionName}/${apk_version3}/g")">"$app_details"
					fi
					[[ $PackageName = "" ]] && echo "PackageName=\"$name2\"" >>"$app_details"
					[[ $ChineseName = "" ]] && echo "ChineseName=\"$name1\"" >>"$app_details"
					[[ ! -f $Backup_folder/$name2.sh ]] && cp -r "$script_path/restore2" "$Backup_folder/$name2.sh"
				else
					rm -rf "$Backup_folder"
				fi
				if [[ $name2 = com.android.chrome ]]; then
					#删除所有旧apk ,保留一个最新apk进行备份
					ReservedNum=1
					FileNum="$(ls /data/app/*/com.google.android.trichromelibrary_*/base.apk 2>/dev/null | wc -l)"
					while [[ $FileNum -gt $ReservedNum ]]; do
						OldFile="$(ls -rt /data/app/*/com.google.android.trichromelibrary_*/base.apk 2>/dev/null | head -1)"
						rm -rf "${OldFile%/*/*}" && echoRgb "删除文件:${OldFile%/*/*}"
						let "FileNum--"
					done
					[[ -f $(ls /data/app/*/com.google.android.trichromelibrary_*/base.apk 2>/dev/null) && $(ls /data/app/*/com.google.android.trichromelibrary_*/base.apk 2>/dev/null | wc -l) = 1 ]] && cp -r "$(ls /data/app/*/com.google.android.trichromelibrary_*/base.apk 2>/dev/null)" "$Backup_folder/nmsl.apk"
				fi
			else
				rm -rf "$Backup_folder"
			fi
		else
			let osj++
			echoRgb "$name1不支持备份 需要使用vanced安装" "0" && rm -rf "$Backup_folder"
		fi
	fi
	[[ $name2 = bin.mt.plus && ! -f $Backup/$name1.apk ]] && cp -r "$apk_path" "$Backup/$name1.apk"
}
#检测数据位置进行备份
Backup_data() {
	data_path="$path/$1/$name2"
	case $1 in
	user) Size="$userSize" && data_path="$path2/$name2" ;;
	data) Size="$dataSize" ;;
	obb) Size="$obbSize" ;;
	*)
		[[ -f $app_details ]] && Size="$(cat "$app_details" | awk "/$1Size/"'{print $1}' | cut -f2 -d '=' | tail -n1 | sed 's/\"//g')"
		data_path="$2"
		if [[ $1 != storage-isolation && $1 != thanox ]]; then
			Compression_method1="$Compression_method"
			Compression_method=tar
			[[ -d $data_path ]] && echo "$2" >"$2/PATH"
		fi
		zsize=1
		;;
	esac
	if [[ -d $data_path ]]; then
	    unset Filesize m_size k_size
        Filesize="$(du -ks "$data_path" | awk '{print $1}')"
        k_size="$(awk 'BEGIN{printf "%.2f\n", "'$Filesize'"'*1024'/'1024'}')"
	    m_size="$(awk 'BEGIN{printf "%.2f\n", "'$k_size'"/'1024'}')"
        if [[ $(expr "$m_size" \> 1) -eq 0 ]]; then
            get_size="$(awk 'BEGIN{printf "%.2f\n", "'$k_size'"/'1024'}')KB"
        else
            [[ $(echo "$m_size" | cut -d '.' -f1) -lt 1000 ]] && get_size="${m_size}MB" || get_size="$(awk 'BEGIN{printf "%.2f\n", "'$m_size'"/'1024'}')GB"
        fi
		if [[ $Size != $Filesize ]]; then
			partition_info "$Backup"
			echoRgb "备份$1数据($get_size)"
			case $1 in
			user)
				case $Compression_method in
				tar | Tar | TAR) tar --checkpoint-action="ttyout=%T\r" --exclude="${data_path##*/}/.ota" --exclude="${data_path##*/}/cache" --exclude="${data_path##*/}/lib" --exclude="${data_path##*/}/code_cache" --exclude="${data_path##*/}/no_backup" -cpf "$Backup_folder/$1.tar" -C "${data_path%/*}" "${data_path##*/}" 2>/dev/null ;;
				zstd | Zstd | ZSTD) tar --checkpoint-action="ttyout=%T\r" --exclude="${data_path##*/}/.ota" --exclude="${data_path##*/}/cache" --exclude="${data_path##*/}/lib" --exclude="${data_path##*/}/code_cache" --exclude="${data_path##*/}/no_backup" -cpf - -C "${data_path%/*}" "${data_path##*/}" | zstd>"$Backup_folder/$1.tar.zst" 2>/dev/null ;;
				lz4 | Lz4 | LZ4) tar --checkpoint-action="ttyout=%T\r" --exclude="${data_path##*/}/.ota" --exclude="${data_path##*/}/cache" --exclude="${data_path##*/}/lib" --exclude="${data_path##*/}/code_cache" --exclude="${data_path##*/}/no_backup" -cpf - -C "${data_path%/*}" "${data_path##*/}" | lz4>"$Backup_folder/$1.tar.lz4" 2>/dev/null ;;
				esac
				;;
			*)
				case $Compression_method in
				tar | Tar | TAR) tar --checkpoint-action="ttyout=%T\r" --exclude="Backup_"* --exclude="${data_path##*/}/cache" -cpf "$Backup_folder/$1.tar" -C "${data_path%/*}" "${data_path##*/}" ;;
				zstd | Zstd | ZSTD) tar --checkpoint-action="ttyout=%T\r" --exclude="Backup_"* --exclude="${data_path##*/}/cache" -cpf - -C "${data_path%/*}" "${data_path##*/}" | zstd>"$Backup_folder/$1.tar.zst" 2>/dev/null ;;
				lz4 | Lz4 | LZ4) tar --checkpoint-action="ttyout=%T\r" --exclude="Backup_"* --exclude="${data_path##*/}/cache" -cpf - -C "${data_path%/*}" "${data_path##*/}" | lz4>"$Backup_folder/$1.tar.lz4" 2>/dev/null ;;
				esac
				;;
			esac
			echo_log "备份$1数据"
			if [[ $result = 0 ]]; then
				case $Compression_method in
				tar | Tar | TAR) Validation_file "$Backup_folder/$1.tar" ;;
				zstd | Zstd | ZSTD) Validation_file "$Backup_folder/$1.tar.zst" ;;
				lz4 | Lz4 | LZ4) Validation_file "$Backup_folder/$1.tar.lz4" ;;
				esac
				if [[ $result = 0 ]]; then
					if [[ $zsize != "" ]]; then
						rm -rf "$2/PATH"
						if [[ $Size != "" ]]; then
							echo "$(cat "$app_details" | sed "s/$Size/$Filesize/g")">"$app_details"
						else
							echo "#$1Size=\"$Filesize\"" >>"$app_details"
						fi
					else
						if [[ $Size != "" ]]; then
							echo "$(cat "$app_details" | sed "s/$Size/$Filesize/g")">"$app_details"
						else
							echo "$1Size=\"$Filesize\"" >>"$app_details"
						fi
					fi
				else
					rm -rf "$Backup_folder/$1".tar.*
				fi
			fi
			[[ $Compression_method1 != "" ]] && Compression_method="$Compression_method1"
			unset Compression_method1
		else
			echoRgb "$1数据无发生变化 跳过备份" "2"
		fi
	else
		[[ -f $data_path ]] && echoRgb "$1是一个文件 不支持备份" "0" || echoRgb "$1数据不存在跳过备份" "2"
	fi
	partition_info "$Backup"
}
Release_data() {
	tar_path="$1"
	X="$path2/$name2"
	MODDIR_NAME="${tar_path%/*}"
	MODDIR_NAME="${MODDIR_NAME##*/}"
	FILE_NAME="${tar_path##*/}"
	FILE_NAME2="${FILE_NAME%%.*}"
	case ${FILE_NAME##*.} in
	lz4 | zst | tar)
		unset FILE_PATH Size Selinux_state
		case $FILE_NAME2 in
		user) 
		    if [[ -d $X ]]; then
		        FILE_PATH="$path2"
		        Size="$userSize"
		        Selinux_state="$(LS "$X" | awk 'NF>1{print $1}' | sed -e "s/system_data_file/app_data_file/g" 2>/dev/null)"
		    else
		        echoRgb "$X不存在 无法恢复$FILE_NAME2数据" "0"
		    fi;;
		data) FILE_PATH="$path/data" Size="$dataSize" Selinux_state="$(LS "$FILE_PATH" | awk 'NF>1{print $1}' | sed -e "s/system_data_file/app_data_file/g" 2>/dev/null)";;
		obb) FILE_PATH="$path/obb" Size="$obbSize" Selinux_state="$(LS "$FILE_PATH" | awk 'NF>1{print $1}' | sed -e "s/system_data_file/app_data_file/g" 2>/dev/null)";;
		thanox)	FILE_PATH="/data/system" Size="$(cat "$app_details" | awk "/${FILE_NAME2}Size/"'{print $1}' | cut -f2 -d '=' | tail -n1 | sed 's/\"//g')" && find "/data/system" -name "thanos*" -maxdepth 1 -type d -exec rm -rf {} \; 2>/dev/null ;;
		storage-isolation)	FILE_PATH="/data/adb" Size="$(cat "$app_details" | awk "/${FILE_NAME2}Size/"'{print $1}' | cut -f2 -d '=' | tail -n1 | sed 's/\"//g')" ;;
		*)
			if [[ $A != "" ]]; then
				if [[ ${MODDIR_NAME##*/} = Media ]]; then
					case ${FILE_NAME##*.} in
					tar) tar -xpf "$tar_path" -C "$TMPDIR" --wildcards --no-anchored 'PATH' && FILE_PATH="$(cat "$TMPDIR/$FILE_NAME2/PATH" 2>/dev/null)" ;;
					esac
					if [[ $FILE_PATH = "" ]]; then
						echoRgb "解压路径获取失败" "0"
					else
						echoRgb "解压路径↓\n -$FILE_PATH" "2"
						TMPPATH="$FILE_PATH"
						FILE_PATH="${FILE_PATH%/*}"
						Size="$(cat "$app_details" | awk "/${FILE_NAME2}Size/"'{print $1}' | cut -f2 -d '=' | tail -n1 | sed 's/\"//g')"
						[[ ! -d $FILE_PATH ]] && mkdir -p "$FILE_PATH"
					fi
				fi
			fi ;;
		esac
        echoRgb "恢复$FILE_NAME2数据 释放$(size "$(awk 'BEGIN{printf "%.2f\n", "'$Size'"*'1024'}')")" "3"
   		if [[ $FILE_PATH != "" ]]; then
            [[ ${MODDIR_NAME##*/} != Media ]] && rm -rf "$FILE_PATH/$name2"
		    case ${FILE_NAME##*.} in
			lz4 | zst)
			    tar --checkpoint-action="ttyout=%T\r" -I zstd -xmpf "$tar_path" -C "$FILE_PATH"
		        ;;
			tar)
			    [[ ${MODDIR_NAME##*/} = Media ]] && tar --checkpoint-action="ttyout=%T\r" -axf "$tar_path" -C "$FILE_PATH" || tar --checkpoint-action="ttyout=%T\r" -amxf "$tar_path" -C "$FILE_PATH"
			    ;;
			esac
		else
			Set_back
		fi
		echo_log "解压缩${FILE_NAME##*.}"
		if [[ $result = 0 ]]; then
			[[ -d $TMPPATH ]] && rm -rf "$TMPPATH/PATH"
			case $FILE_NAME2 in
			user|data|obb)
			    if [[ -f /config/sdcardfs/$name2/appid ]]; then
					G="$(cat "/config/sdcardfs/$name2/appid")"
				else
					G="$(dumpsys package "$name2" 2>/dev/null | grep -w 'userId' | head -1)"
				fi
                G="$(echo "$G" | egrep -o '[0-9]+')"
				if [[ $G != "" ]]; then
					if [[ -d $X ]]; then
					    [[ $user = 0 ]] && uid="$G:$G" || uid="$user$G:$user$G"
                        if [[ $FILE_NAME2 = user ]]; then
						    echoRgb "路径:$X"
						    Path_details="$(stat -c "%A/%a %U/%G" "$X")"
						    chown -hR "$uid" "$X/"
						    echo_log "设置用户组:$(echo "$Path_details" | awk '{print $2}'),shell in :$uid"
						    chcon -hR "$Selinux_state" "$X/" 2>/dev/null
						    echo_log "selinux上下文设置"
					    elif [[ $FILE_NAME2 = data || $FILE_NAME2 = obb ]]; then
                            chown -hR "$uid" "$FILE_PATH/$name2/"
                            chcon -hR "$Selinux_state" "$FILE_PATH/$name2/" 2>/dev/null
					    fi
				    else
				        echoRgb "路径$X不存在" "0"
					fi
				else
                    echoRgb "uid获取失败" "0"
				fi
				;;
			thanox)
				restorecon -RF "$(find "/data/system" -name "thanos*" -maxdepth 1 -type d 2>/dev/null)/" 2>/dev/null
				echo_log "selinux上下文设置" && echoRgb "警告 thanox配置恢复后务必重启\n -否则不生效" "0"
				;;
			storage-isolation)
				restorecon -RF "/data/adb/storage-isolation/" 2>/dev/null
				echo_log "selinux上下文设置"
				;;
			esac
		fi
		;;
	*)
		echoRgb "$FILE_NAME 压缩包不支持解压缩" "0"
		Set_back
		;;
	esac
	rm -rf "$TMPDIR"/*
}
installapk() {
	apkfile="$(find "$Backup_folder" -maxdepth 1 -name "apk.*" -type f 2>/dev/null)"
	if [[ $apkfile != "" ]]; then
		rm -rf "$TMPDIR"/*
		case ${apkfile##*.} in
		lz4 | zst) tar --checkpoint-action="ttyout=%T\r" -I zstd -xmpf "$apkfile" -C "$TMPDIR" ;;
		tar) tar --checkpoint-action="ttyout=%T\r" -xmpf "$apkfile" -C "$TMPDIR" ;;
		*)
			echoRgb "${apkfile##*/} 压缩包不支持解压缩" "0"
			Set_back
			;;
		esac
		echo_log "${apkfile##*/}解压缩" && [[ -f $Backup_folder/nmsl.apk ]] && cp -r "$Backup_folder/nmsl.apk" "$TMPDIR"
	else
		echoRgb "你的Apk压缩包离家出走了，可能备份后移动过程遗失了\n -解决办法手动安装Apk后再执行恢复脚本" "0"
	fi
	if [[ $result = 0 ]]; then
		case $(find "$TMPDIR" -maxdepth 1 -name "*.apk" -type f 2>/dev/null | wc -l) in
		1)
			echoRgb "恢复普通apk" "2"
			INSTALL "$TMPDIR"/*.apk
			echo_log "Apk安装"
			;;
		0)
			echoRgb "$TMPDIR中没有apk" "0"
			;;
		*)
			echoRgb "恢复split apk" "2"
			b="$(create 2>/dev/null | egrep -o '[0-9]+')"
			if [[ -f $TMPDIR/nmsl.apk ]]; then
				INSTALL "$TMPDIR/nmsl.apk"
				echo_log "nmsl.apk安装"
			fi
			find "$TMPDIR" -maxdepth 1 -name "*.apk" -type f 2>/dev/null | grep -v 'nmsl.apk' | while read; do
				pm install-write "$b" "${REPLY##*/}" "$REPLY" &>/dev/null
				echo_log "${REPLY##*/}安装"
			done
			pm install-commit "$b" &>/dev/null
			echo_log "split Apk安装"
			;;
		esac
	fi
}
disable_verify() {
	#禁用apk验证
	settings put global verifier_verify_adb_installs 0 2>/dev/null
	#禁用安装包验证
	settings put global package_verifier_enable 0 2>/dev/null
	#未知来源
	settings put secure install_non_market_apps 1 2>/dev/null
	#关闭play安全效验
	if [[ $(settings get global package_verifier_user_consent 2>/dev/null) != -1 ]]; then
		settings put global package_verifier_user_consent -1 2>/dev/null
		settings put global upload_apk_enable 0 2>/dev/null
		echoRgb "PLAY安全验证为开启状态已被脚本关闭防止apk安装失败" "3"
	fi
}
get_name(){
	txt="$MODDIR/appList.txt"
	txt2="$MODDIR/mediaList.txt"
	txt="${txt/'/storage/emulated/'/'/data/media/'}"
	if [[ $1 = Apkname ]]; then
		rm -rf "$txt" "$txt2"
		echoRgb "列出全部资料夹内应用名与自定义目录压缩包名称" "3"
	fi
	rgb_a=118
	find "$MODDIR" -maxdepth 2 -name "apk.*" -type f 2>/dev/null | sort | while read; do
		Folder="${REPLY%/*}"
		[[ $rgb_a -ge 229 ]] && rgb_a=118
		unset PackageName NAME DUMPAPK ChineseName
		[[ -f $Folder/app_details ]] && . "$Folder/app_details" &>/dev/null
		[[ ! -f $txt ]] && echo "#不需要恢复还原的应用请在开头注释# 比如#xxxxxxxx 酷安" >"$txt"
		if [[ $PackageName = "" || $ChineseName = "" ]]; then
			echoRgb "${Folder##*/}包名获取失败，解压缩获取包名中..." "0"
			rm -rf "$TMPDIR"/*
			case ${REPLY##*.} in
			lz4 | zst) tar -I zstd -xmpf "$REPLY" -C "$TMPDIR" --wildcards --no-anchored 'base.apk' ;;
			tar) tar -xmpf "$REPLY" -C "$TMPDIR" --wildcards --no-anchored 'base.apk' ;;
			*)
			    echoRgb "${REPLY##*/} 压缩包不支持解压缩" "0"
				Set_back
				;;
			esac
			echo_log "${REPLY##*/}解压缩"
			if [[ $result = 0 ]]; then
				if [[ -f $TMPDIR/base.apk ]]; then
					DUMPAPK="$(appinfo -sort-i -d " " -o ands,pn -f "$TMPDIR/base.apk")"
					if [[ $DUMPAPK != "" ]]; then
						app=($DUMPAPK $DUMPAPK)
						PackageName="${app[1]}"
						ChineseName="${app[2]}"
						rm -rf "$TMPDIR"/*
					else
						echoRgb "appinfo输出失败" "0"
					fi
				fi
			fi
		fi
		if [[ $PackageName != "" && $ChineseName != "" ]]; then
			case $1 in
			Apkname)
				echoRgb "$ChineseName $PackageName" && echo "$ChineseName $PackageName" >>"$txt" ;; 
			convert)
				if [[ ${Folder##*/} = $PackageName ]]; then
					mv "$Folder" "${Folder%/*}/$ChineseName" && echoRgb "${Folder##*/} > $ChineseName"
				else
					mv "$Folder" "${Folder%/*}/$PackageName" && echoRgb "${Folder##*/} > $PackageName"
				fi ;;
			esac
		fi
		let rgb_a++
	done
	if [[ -d $MODDIR/Media ]]; then
		echoRgb "存在媒体资料夹" "2"
		[[ ! -f $txt2 ]] && echo "#不需要恢复的资料夹请在开头注释# 比如#媒体" > "$txt2"
		find "$MODDIR/Media" -maxdepth 1 -name "*.tar*" -type f 2>/dev/null | while read; do
			echoRgb "${REPLY##*/}" && echo "${REPLY##*/}" >> "$txt2"
		done
		echoRgb "$txt2重新生成" "1"
	fi
	exit 0
}
self_test() {
	if [[ $(dumpsys deviceidle get charging) = false && $(dumpsys battery | awk '/level/{print $2}' | egrep -o '[0-9]+') -le 15 ]]; then
		echoRgb "电量$(dumpsys battery | awk '/level/{print $2}' | egrep -o '[0-9]+')%太低且未充电\n -为防止备份档案或是恢复因低电量强制关机导致档案损毁\n -请连接充电器后备份" "0" && exit 2
	fi
}
Validation_file() {
	MODDIR_NAME="${1%/*}"
	MODDIR_NAME="${MODDIR_NAME##*/}"
	FILE_NAME="${1##*/}"
	echoRgb "效验$FILE_NAME"
	case ${FILE_NAME##*.} in
	lz4 | zst) zstd -t "$1" 2>/dev/null ;;
	tar) tar -tf "$1" &>/dev/null ;;
	esac
	echo_log "效验"
}
Check_archive() {
	starttime1="$(date -u "+%s")"
	error_log="$TMPDIR/error_log"
	rm -rf "$error_log"
	FIND_PATH="$(find "$1" -maxdepth 3 -name "*.tar*" -type f 2>/dev/null | sort)"
	i=1
	r="$(find "$MODDIR" -maxdepth 2 -name "app_details" -type f 2>/dev/null | wc -l)"
	find "$MODDIR" -maxdepth 2 -name "app_details" -type f 2>/dev/null | sort | while read; do
		REPLY="${REPLY%/*}"
		echoRgb "效验第$i/$r个资料夹 剩下$((r - i))个" "3"
		echoRgb "效验:${REPLY##*/}"
		find "$REPLY" -maxdepth 1 -name "*.tar*" -type f 2>/dev/null | sort | while read; do
			Validation_file "$REPLY"
			[[ $result != 0 ]] && echo "$REPLY">>"$error_log"
		done
		echoRgb "$((i * 100 / r))%"
		let i++ nskg++
	done
	endtime 1
	[[ -f $error_log ]] && echoRgb "以下为失败的档案\n $(cat "$error_log")" || echoRgb "恭喜~~全数效验通过" 
	rm -rf "$error_log"
}
case $operate in
backup)
	kill_Serve
	self_test
	[[ ! -d $script_path ]] && echo "$script_path脚本目录遗失" && exit 2
	case $MODDIR in
	/storage/emulated/0/Android/* | /data/media/0/Android/* | /sdcard/Android/*) echoRgb "请勿在$MODDIR内备份" "0" && exit 2 ;;
	esac
	case $Compression_method in
	zstd | Zstd | ZSTD | tar | Tar | TAR | lz4 | Lz4 | LZ4) ;;
	*) echoRgb "$Compression_method为不支持的压缩算法" "0" && exit 2 ;;
	esac
	#效验选填是否正确
	isBoolean "$Lo" "Lo" && Lo="$nsx"
	if [[ $Lo = false ]]; then
		isBoolean "$default_behavior" "default_behavior" && default_behavior="$nsx"
		isBoolean "$delete_folder" "delete_folder" && delete_folder="$nsx"
		isBoolean "$USBdefault" "USBdefault" && USBdefault="$nsx"
		isBoolean "$Backup_obb_data" "Backup_obb_data" && Backup_obb_data="$nsx"
		isBoolean "$Backup_user_data" "Backup_user_data" && Backup_user_data="$nsx"
		isBoolean "$backup_media" "backup_media" && backup_media="$nsx"
	else
		echoRgb "检查目录是否存在已卸载应用?\n -音量上检查，下不检查"
		get_version "检查" "不检查" && delete_folder="$branch"
		echoRgb "检查到已卸载应用\n -音量上删除资料夹，下移动到其他处"
		get_version "删除" "移动到其他处" && default_behavior="$branch"
		echoRgb "存在usb随身碟是否默认使用随身碟?\n -音量上默认，下进行询问"
		get_version "默认" "询问" && USBdefault="$branch"
		echoRgb "是否备分外部数据 即比如原神的数据包\n -音量上备份，音量下不备份" "2"
		get_version "备份" "不备份" && Backup_obb_data="$branch"
		echoRgb "是否备份使用者数据\n -音量上备份，音量下不备份" "2"
		get_version "备份" "不备份" && Backup_user_data="$branch"
		echoRgb "全部应用备份结束后是否备份自定义目录\n -音量上备份，音量下不备份" "2"
		get_version "备份" "不备份" && backup_media="$branch"
	fi
	i=1
	#数据目录
	txt="$MODDIR/appList.txt"
	txt="${txt/'/storage/emulated/'/'/data/media/'}"
	[[ ! -f $txt ]] && echoRgb "请执行\"生成应用列表.sh\"获取应用列表再来备份" "0" && exit 1
	sort -u "$txt" -o "$txt" 2>/dev/null
	data="$MODDIR"
	hx="本地"
	echoRgb "提示 脚本支持后台压缩 可以直接离开脚本\n -或是关闭终端也能备份 如需终止脚本\n -请执行终止脚本.sh即可停止\n -备份结束将发送toast提示语" "3"
	backup_path
	echoRgb "配置详细:\n -压缩方式:$Compression_method\n -音量键确认:$Lo\n -Toast:$toast_info\n -更新:$update\n -已卸载应用检查:$delete_folder\n -卸载应用默认操作(true删除false移动):$default_behavior\n -默认使用usb:$USBdefault\n -备分外部数据:$Backup_obb_data\n -备份user数据:$Backup_user_data\n -自定义目录备份:$backup_media"
	D="1"
	C="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
	if [[ $delete_folder = true ]]; then
		if [[ -d $Backup ]]; then
			if [[ $1 = "" ]]; then
				find "$Backup" -maxdepth 1 -type d 2>/dev/null | sort | while read; do
					if [[ -f $REPLY/app_details ]]; then
						unset PackageName
						. "$REPLY/app_details" &>/dev/null
						if [[ $PackageName != "" && $(pm path --user "$user" "$PackageName" 2>/dev/null | cut -f2 -d ':') = "" ]]; then
							if [[ $default_behavior = true ]]; then
								rm -rf "$REPLY"
								echoRgb "${REPLY##*/}不存在系统 删除资料夹" "0"
							else
								if [[ ! -d $Backup/被卸载的应用 ]]; then
									mkdir -p "$Backup/被卸载的应用" && mv "$REPLY" "$Backup/被卸载的应用/"
								else
									mv "$REPLY" "$Backup/被卸载的应用/"
								fi
								[[ ! -d $Backup/被卸载的应用/tools ]] && cp -r "$tools_path" "$Backup/被卸载的应用" && rm -rf "$Backup/被卸载的应用/tools/bin/zip" "$Backup/被卸载的应用/tools/script"
								[[ ! -f $Backup/被卸载的应用/恢复备份.sh ]] && cp -r "$script_path/restore" "$Backup/被卸载的应用/恢复备份.sh"
								[[ ! -f $Backup/被卸载的应用/重新生成应用列表.sh ]] && cp -r "$script_path/Get_DirName" "$Backup/被卸载的应用/重新生成应用列表.sh"
								[[ ! -f $Backup/被卸载的应用/转换资料夹名称.sh ]] && cp -r "$script_path/convert" "$Backup/被卸载的应用/转换资料夹名称.sh"
								[[ ! -f $Backup/被卸载的应用/压缩档完整性检查.sh ]] && cp -r "$script_path/check_file" "$Backup/被卸载的应用/压缩档完整性检查.sh"
								[[ ! -f $Backup/被卸载的应用/终止脚本.sh ]] && cp -r "$MODDIR/终止脚本.sh" "$Backup/被卸载的应用/终止脚本.sh"
								[[ ! -f $Backup/被卸载的应用/backup_settings.conf ]] && echo "#1开启0关闭\n\n#是否在每次执行恢复脚本时使用音量键询问如下需求\n#如果是那下面两项项设置就被忽略，改为音量键选择\nLo=$Lo\n\n#备份与恢复遭遇异常或是结束后发送通知(toast与状态栏提示)\ntoast_info=$toast_info\n\n#脚本检测更新后进行更新?\nupdate=$update\n\n#检测到更新后的行为(1跳转浏览器 0不跳转浏览器，但是复制连结到剪裁版)\nupdate_behavior=$update_behavior\n#主色\nrgb_a=$rgb_a\n#辅色\nrgb_b=$rgb_b\nrgb_c=$rgb_c">"$Backup/backup_settings.conf" && echo "$(sed 's/true/1/g ; s/false/0/g' "$Backup/backup_settings.conf")">"$Backup/被卸载的应用/backup_settings.conf" && echo "$(sed 's/true/1/g ; s/false/0/g' "$Backup/backup_settings.conf")">"$Backup/被卸载的应用/backup_settings.conf"
								txt2="$Backup/被卸载的应用/appList.txt"
								[[ ! -f $txt2 ]] && echo "#不需要恢复还原的应用请在开头注释# 比如#xxxxxxxx 酷安">"$txt2"
								echo "${REPLY##*/} $PackageName">>"$txt2"
								echo "$(sed -e "s/${REPLY##*/} $PackageName//g ; /^$/d" "$Backup/appList.txt")" >"$Backup/appList.txt"
								echoRgb "${REPLY##*/}不存在系统 已移动到$Backup/被卸载的应用" "0"
							fi
						fi
					fi
				done
			fi
		fi
	fi
	if [[ $1 = "" ]]; then
		echoRgb "检查备份列表中是否存在已经卸载应用" "3"
		while [[ $D -le $C ]]; do
			name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${D}p" | awk '{print $1}')"
			name2="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${D}p" | awk '{print $2}')"
			if [[ $name2 != "" && $(pm path --user "$user" "$name2" 2>/dev/null | cut -f2 -d ':') = "" ]]; then
				echoRgb "$name1不存在系统，从列表中删除" "0"
				echo "$(sed -e "s/$name1 $name2//g ; /^$/d" "$txt")" >"$txt"
			fi
			let D++
		done
		echo "$(sed -e '/^$/d' "$txt")" >"$txt"
	fi
	r="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
	[[ $1 != "" ]] && r=1
	[[ $r = "" ]] && echoRgb "$MODDIR_NAME/appList.txt是空的或是包名被注释备份个鬼\n -检查是否注释亦或者执行$MODDIR_NAME/生成应用列表.sh" "0" && exit 1
	[[ $Backup_user_data = false ]] && echoRgb "当前$MODDIR_NAME/backup_settings.conf的\n -Backup_user_data=0将不备份user数据" "0"
	[[ $Backup_obb_data = false ]] && echoRgb "当前$MODDIR_NAME/backup_settings.conf的\n -Backup_obb_data=0将不备分外部数据" "0"
	[[ $backup_media = false ]] && echoRgb "当前$MODDIR_NAME/backup_settings.conf的\n -backup_media=0将不备份自定义资料夹" "0"
	[[ ! -d $Backup ]] && mkdir -p "$Backup"
	txt2="$Backup/appList.txt"
	[[ ! -f $txt2 ]] && echo "#不需要恢复还原的应用请在开头注释# 比如#xxxxxxxx 酷安">"$txt2"
	[[ ! -d $Backup/tools ]] && cp -r "$tools_path" "$Backup" && rm -rf "$Backup/tools/bin/zip" "$Backup/tools/script"
	[[ ! -f $Backup/恢复备份.sh ]] && cp -r "$script_path/restore" "$Backup/恢复备份.sh"
	[[ ! -f $Backup/终止脚本.sh ]] && cp -r "$MODDIR/终止脚本.sh" "$Backup/终止脚本.sh"
	[[ ! -f $Backup/重新生成应用列表.sh ]] && cp -r "$script_path/Get_DirName" "$Backup/重新生成应用列表.sh"
	[[ ! -f $Backup/转换资料夹名称.sh ]] && cp -r "$script_path/convert" "$Backup/转换资料夹名称.sh"
	[[ ! -f $Backup/压缩档完整性检查.sh ]] && cp -r "$script_path/check_file" "$Backup/压缩档完整性检查.sh"
	[[ -d $Backup/Media ]] && cp -r "$script_path/restore3" "$Backup/恢复自定义资料夹.sh"
	[[ ! -f $Backup/backup_settings.conf ]] && echo "#1开启0关闭\n\n#是否在每次执行恢复脚本时使用音量键询问如下需求\n#如果是那下面两项项设置就被忽略，改为音量键选择\nLo=$Lo\n\n#备份与恢复遭遇异常或是结束后发送通知(toast与状态栏提示)\ntoast_info=$toast_info\n\n#使用者\nuser=\n\n#脚本检测更新后进行更新?\nupdate=$update\n\n#检测到更新后的行为(1跳转浏览器 0不跳转浏览器，但是复制连结到剪裁版)\nupdate_behavior=$update_behavior\n\n#恢复模式(1仅恢复未安装应用0全恢复)\nrecovery_mode=0\n\n#主色\nrgb_a=$rgb_a\n#辅色\nrgb_b=$rgb_b\nrgb_c=$rgb_c">"$Backup/backup_settings.conf" && echo "$(sed 's/true/1/g ; s/false/0/g' "$Backup/backup_settings.conf")">"$Backup/backup_settings.conf"
	filesha256="$(sha256sum "$bin_path/tools.sh" | cut -d" " -f1)"
	filesha256_1="$(sha256sum "$Backup/tools/bin/tools.sh" | cut -d" " -f1)"
	[[ $filesha256 != $filesha256_1 ]] && cp -r "$bin_path/tools.sh" "$Backup/tools/bin/tools.sh"
	filesize="$(du -ks "$Backup" | awk '{print $1}')"
	Quantity=0
	#开始循环$txt内的资料进行备份
	#记录开始时间
	starttime1="$(date -u "+%s")"
	TIME="$starttime1"
	en=118
	echo "$script">"$TMPDIR/scriptTMP" && echo "$script">"$TMPDIR/scriptTMP"
	osn=0; osj=0; osk=0
	#获取已经开启的无障碍
	var="$(settings get secure enabled_accessibility_services 2>/dev/null)"
	#获取预设键盘
	keyboard="$(settings get secure default_input_method 2>/dev/null)"
	[[ $(cat "$txt" | grep -v "#" | sed -e '/^$/d' | awk '{print $2}' | grep -w "^${keyboard%/*}$") != ${keyboard%/*} ]] && unset keyboard
	{
	while [[ $i -le $r ]]; do
		[[ $en -ge 229 ]] && en=118
		unset name1 name2 apk_path apk_path2
		if [[ $1 != "" ]]; then
			name1="$(appinfo -sort-i -d " " -o ands -pn "$1")"
			name2="$1"
		else
			name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $1}')"
			name2="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $2}')"
		fi
		[[ $name2 = "" ]] && echoRgb "警告! appList.txt应用包名获取失败，可能修改有问题" "0" && exit 1
		apk_path="$(pm path --user "$user" "$name2" 2>/dev/null | cut -f2 -d ':')"
		apk_path2="$(echo "$apk_path" | head -1)"
		apk_path2="${apk_path2%/*}"
		if [[ -d $apk_path2 ]]; then
			echoRgb "备份第$i/$r个应用 剩下$((r - i))个" "3"
			echoRgb "备份 $name1 \"$name2\"" "2"
			unset Backup_folder ChineseName PackageName nobackup No_backupdata result apk_version versionName apk_version2 apk_version3 zsize Size data_path userSize dataSize obbSize
			if [[ $name1 = !* || $name1 = ！* ]]; then
				name1="$(echo "$name1" | sed 's/!//g ; s/！//g')"
				echoRgb "跳过备份所有数据" "0"
				No_backupdata=1
			fi
			if [[ $(echo "$blacklist" | grep -w "$name2") = $name2 ]]; then
				echoRgb "黑名单应用跳过备份所有数据" "0"
				No_backupdata=1
			fi
			Backup_folder="$Backup/$name1"
			app_details="$Backup_folder/app_details"
			if [[ -f $app_details ]]; then
				. "$app_details" &>/dev/null
				if [[ $PackageName != $name2 ]]; then
					unset Backup_folder ChineseName PackageName nobackup No_backupdata result apk_version versionName apk_version2 apk_version3 zsize Size data_path userSize dataSize obbSize
					Backup_folder="$Backup/${name1}[${name2}]"
					app_details="$Backup_folder/app_details"
					[[ -f $app_details ]] && . "$app_details" &>/dev/null
				fi
			fi
			[[ $hx = USB && $PT = "" ]] && echoRgb "随身碟意外断开 请检查稳定性" "0" && exit 1
			starttime2="$(date -u "+%s")"
			[[ $name2 = com.tencent.mobileqq ]] && echoRgb "QQ可能恢复备份失败或是丢失聊天记录，请自行用你信赖的应用备份" "0"
			[[ $name2 = com.tencent.mm ]] && echoRgb "WX可能恢复备份失败或是丢失聊天记录，请自行用你信赖的应用备份" "0"
			apk_number="$(echo "$apk_path" | wc -l)"
			#停止应用
			[[ $name2 != $Open_apps2 ]] && am force-stop --user "$user" "$name2"
			if [[ $apk_number = 1 ]]; then
				Backup_apk "非Split Apk" "3"
			else
				Backup_apk "Split Apk支持备份" "3"
			fi
			if [[ $result = 0 && $No_backupdata = "" && $nobackup != true ]]; then
				if [[ $Backup_obb_data = true ]]; then
					#备份data数据
					Backup_data "data"
					#备份obb数据
					Backup_data "obb"
				fi
				#备份user数据
				[[ $Backup_user_data = true ]] && Backup_data "user"
				[[ $name2 = github.tornaco.android.thanos ]] && Backup_data "thanox" "$(find "/data/system" -name "thanos*" -maxdepth 1 -type d 2>/dev/null)"
				[[ $name2 = moe.shizuku.redirectstorage ]] && Backup_data "storage-isolation" "/data/adb/storage-isolation"
			fi
			endtime 2 "$name1 备份" "3"
			Occupation_status="$(df -h "${Backup%/*}" | sed -n 's|% /.*|%|p' | awk '{print $(NF-1),$(NF)}')"
			lxj="$(echo "$Occupation_status" | awk '{print $3}' | sed 's/%//g')"
			echoRgb "完成$((i * 100 / r))% $hx$(echo "$Occupation_status" | awk 'END{print "剩余:"$1"使用率:"$2}')" "3"
			rgb_d="$rgb_a"
			rgb_a=188
			echoRgb "_________________$(endtime 1 "已经")___________________"
			rgb_a="$rgb_d"
		else
			echoRgb "$name1[$name2] 不在安装列表，备份个寂寞？" "0"
		fi
		if [[ $i = $r ]]; then
			endtime 1 "应用备份" "3"
			#设置无障碍开关
			if [[ $var != "" ]]; then
				if [[ $var != null ]]; then
					settings put secure enabled_accessibility_services "$var" &>/dev/null 
					echo_log "设置无障碍"
					settings put secure accessibility_enabled 1 &>/dev/null
					echo_log "打开无障碍开关"
				fi
			fi
			#设置键盘
			if [[ $keyboard != "" ]]; then
				ime enable "$keyboard" &>/dev/null
				ime set "$keyboard" &>/dev/null
				settings put secure default_input_method "$keyboard" &>/dev/null
				echo_log "设置键盘$(appinfo -d "(" -ed ")" -o ands,pn -pn "${keyboard%/*}" 2>/dev/null)"
			fi
			[[ $update_apk2 = "" ]] && update_apk2="暂无更新"
			[[ $add_app2 = "" ]] && add_app2="暂无更新"
			echoRgb "\n -已更新的apk=\"$osn\"\n -已新增的备份=\"$osk\"\n -apk版本号无变化=\"$osj\"\n -下列为版本号已变更的应用\n$update_apk2\n -新增的备份....\n$add_app2" "3"
			echo "$(sort "$txt2" | sed -e '/^$/d')" >"$txt2"
			if [[ $backup_media = true ]]; then
				A=1
				B="$(echo "$Custom_path" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
				if [[ $B != "" ]]; then
					echoRgb "备份结束，备份多媒体" "1"
					starttime1="$(date -u "+%s")"
					Backup_folder="$Backup/Media"
					[[ ! -f $Backup/恢复自定义资料夹.sh ]] && cp -r "$script_path/restore3" "$Backup/恢复自定义资料夹.sh"
					[[ ! -d $Backup_folder ]] && mkdir -p "$Backup_folder"
					app_details="$Backup_folder/app_details"
					[[ -f $app_details ]] && . "$app_details" &>/dev/null
					mediatxt="$Backup/mediaList.txt"
					[[ ! -f $mediatxt ]] && echo "#不需要恢复的资料夹请在开头注释# 比如#媒体" > "$mediatxt"
					echo "$Custom_path" | grep -v "#" | sed -e '/^$/d' | while read; do
						echoRgb "备份第$A/$B个资料夹 剩下$((B - A))个" "3"
						starttime2="$(date -u "+%s")"
						Backup_data "${REPLY##*/}" "$REPLY"
						[[ $result = 0 ]] && [[ $(cat "$mediatxt" | grep -v "#" | sed -e '/^$/d' | grep -w "^${REPLY##*/}.tar$" | head -1) = "" ]] && echo "${REPLY##*/}.tar" >> "$mediatxt"
						endtime 2 "${REPLY##*/}备份" "1"
						echoRgb "完成$((A * 100 / B))% $hx$(echo "$Occupation_status" | awk 'END{print "剩余:"$1"使用率:"$2}')" "2"
						rgb_d="$rgb_a"
						rgb_a=188
						echoRgb "_________________$(endtime 1 "已经")___________________"
						rgb_a="$rgb_d" && let A++
					done
					echoRgb "目录↓↓↓\n -$Backup_folder"
					endtime 1 "自定义备份"
				else
					echoRgb "自定义路径为空 无法备份" "0"
				fi
			fi
		fi
		let i++ en++ nskg++
	done
	rm -rf "$TMPDIR/scriptTMP"
	Calculate_size "$Backup"
	echoRgb "批量备份完成"
	starttime1="$TIME"
	endtime 1 "批量备份开始到结束"
	longToast "批量备份完成"
	Print "批量备份完成 执行过程请查看$Status_log"
	#打开应用
	i=1
	am_start="$(echo "$am_start" | head -n 4 | xargs | sed 's/ /\|/g')"
	while [[ $i -le $r ]]; do
		unset pkg name1
		pkg="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $2}')"
		name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $1}')"
		if [[ $(echo "$pkg" | egrep -wo "^$am_start$") = $pkg ]]; then
			am start -n "$(appinfo -sort-i -d "/" -o pn,sa -pn "$pkg" 2>/dev/null)" &>/dev/null
			echo_log "启动$name1"
		fi
		let i++
	done
	} &
	wait && exit
	;;
dumpname)
	get_name "Apkname"
	;;
convert)
	get_name "convert"
	;;
check_file)
	Check_archive "$MODDIR"
	;;
Restore)
	kill_Serve
	self_test
	echoRgb "假设反悔了要终止脚本请尽速离开此脚本点击$MODDIR_NAME/终止脚本.sh\n -否则脚本将继续执行直到结束" "0"
	echoRgb "如果大量提示找不到资料夹请执行$MODDIR_NAME/转换资料夹名称.sh"
	disable_verify
	[[ ! -d $path2 ]] && echoRgb "设备不存在user目录" "0" && exit 1
	i=1
	txt="$MODDIR/appList.txt"
	[[ ! -f $txt ]] && echoRgb "请执行\"重新生成应用列表.sh\"获取应用列表再来恢复" "0" && exit 2
	sort -u "$txt" -o "$txt" 2>/dev/null
	r="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
	[[ $r = "" ]] && echoRgb "appList.txt包名为空或是被注释了\n -请执行\"重新生成应用列表.sh\"获取应用列表再来恢复" "0" && exit 1
	#效验选填是否正确
	isBoolean "$Lo" "Lo" && Lo="$nsx"
	if [[ $Lo = false ]]; then
		isBoolean "$recovery_mode" "recovery_mode" && recovery_mode="$nsx"
	else
		echoRgb "选择应用恢复模式\n -音量上仅恢复未安装，下全恢复"
		get_version "恢复未安装" "全恢复" && recovery_mode="$branch"
	fi
	Get_user="$(echo "$MODDIR" | rev | cut -d '/' -f1 | cut -d '_' -f1 | rev | egrep -o '[0-9]+')"
	if [[ $Get_user != $user ]]; then
	    echoRgb "检测当前用户$user与恢复资料夹用户:$Get_user不同\n -音量上继续恢复，下不恢复并离开脚本"
		get_version "恢复安装" "不恢复安装" && recovery_mode2="$branch"
	fi
	[[ $recovery_mode2 = false ]] && exit 2
	if [[ $recovery_mode = true ]]; then
		echoRgb "获取未安装应用中"
		TXT="$MODDIR/TEMP.txt"
		while [[ $i -le $r ]]; do
			name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $1}')"
			name2="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $2}')"
			if [[ $(pm list packages --user "$user" "$name2" 2>/dev/null | cut -f2 -d ':') = "" ]]; then
				echo "$name1 $name2">>"$TXT"
			fi
			let i++
		done
		i=1
		sort -u "$TXT" -o "$TXT" 2>/dev/null
		r="$(cat "$TXT" 2>/dev/null | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
		if [[ $r != "" ]]; then
			echoRgb "获取完成 预计安装$r个应用"
			txt="$TXT"
		else
			echoRgb "获取完成 但备分内应用都已安装....正在退出脚本" "0" && exit 0
		fi
	fi
	[[ $(which restorecon) = "" ]] && echoRgb "restorecon命令不存在" "0" && exit 1
	#开始循环$txt内的资料进行恢复
	#记录开始时间
	starttime1="$(date -u "+%s")"
	TIME="$starttime1"
	en=118
	echo "$script">"$TMPDIR/scriptTMP"
	{
	while [[ $i -le $r ]]; do
		[[ $en -ge 229 ]] && en=118
		echoRgb "恢复第$i/$r个应用 剩下$((r - i))个" "3"
		name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $1}')"
		name2="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${i}p" | awk '{print $2}')"
		unset No_backupdata apk_version
		if [[ $name1 = *! || $name1 = *！ ]]; then
			name1="$(echo "$name1" | sed 's/!//g ; s/！//g')"
			echoRgb "跳过恢复$name1 所有数据" "0"
			No_backupdata=1
		fi
		Backup_folder="$MODDIR/$name1"
		Backup_folder2="$MODDIR/Media"
		[[ -f "$Backup_folder/app_details" ]] && app_details="$Backup_folder/app_details" . "$Backup_folder/app_details" &>/dev/null
		[[ $name2 = "" ]] && echoRgb "应用包名获取失败" "0" && exit 1
		if [[ -d $Backup_folder ]]; then
			echoRgb "恢复$name1 ($name2)" "2"
			starttime2="$(date -u "+%s")"
			if [[ $(pm path --user "$user" "$name2" 2>/dev/null) = "" ]]; then
				installapk
			else
				if [[ $apk_version -gt $(pm list packages --show-versioncode --user "$user" "$name2" 2>/dev/null | cut -f3 -d ':' | head -n 1) ]]; then
					installapk
					echoRgb "版本提升$(pm list packages --show-versioncode --user "$user" "$name2" 2>/dev/null | cut -f3 -d ':' | head -n 1)>$apk_version" "1"
				fi
			fi
			if [[ $(pm path --user "$user" "$name2" 2>/dev/null) != "" ]]; then
				if [[ $No_backupdata = "" ]]; then
				    #停止应用
        			[[ $name2 != $Open_apps2 ]] && am force-stop --user "$user" "$name2"
					find "$Backup_folder" -maxdepth 1 ! -name "apk.*" -name "*.tar*" -type f 2>/dev/null | sort | while read; do
						Release_data "$REPLY"
					done
				fi
			else
				[[ $No_backupdata = "" ]]&& echoRgb "$name1没有安装无法恢复数据" "0"
			fi
			endtime 2 "$name1恢复" "2" && echoRgb "完成$((i * 100 / r))%" "3"
			rgb_d="$rgb_a"
			rgb_a=188
			echoRgb "_________________$(endtime 1 "已经")___________________"
			rgb_a="$rgb_d"
		else
			echoRgb "$Backup_folder资料夹遗失，无法恢复" "0"
		fi
		if [[ $i = $r ]]; then
			endtime 1 "应用恢复" "2"
			if [[ -d $Backup_folder2 ]]; then
				Print "是否恢复多媒体数据 音量上恢复，音量下不恢复"
				echoRgb "是否恢复多媒体数据\n -音量上恢复，音量下不恢复" "2"
				get_version "恢复媒体数据" "跳过恢复媒体数据"
				starttime1="$(date -u "+%s")"
				app_details="$Backup_folder2/app_details"
				A=1
				B="$(find "$Backup_folder2" -maxdepth 1 -name "*.tar*" -type f 2>/dev/null | wc -l)"
				if [[ $branch = true ]]; then
					find "$Backup_folder2" -maxdepth 1 -name "*.tar*" -type f 2>/dev/null | while read; do
						starttime2="$(date -u "+%s")"
						echoRgb "恢复第$A/$B个压缩包 剩下$((B - A))个" "3"
						Release_data "$REPLY"
						endtime 2 "$FILE_NAME2恢复" "2" && echoRgb "完成$((A * 100 / B))%" "3" && echoRgb "____________________________________" && let A++
					done
					endtime 1 "自定义恢复" "2"
				fi
			fi
		fi
		let i++ en++ nskg++
	done
	rm -rf "$TMPDIR/scriptTMP" "$TXT"
	starttime1="$TIME"
	echoRgb "批量恢复完成" && endtime 1 "批量恢复开始到结束" && echoRgb "如发现应用闪退请重新开机"
	longToast "批量恢复完成"
	Print "批量恢复完成 执行过程请查看$Status_log" && rm -rf "$TMPDIR"/*
	} &
	wait && exit
	;;
Restore2)
	kill_Serve
	self_test
	disable_verify
	[[ ! -d $path2 ]] && echoRgb "设备不存在user目录" "0" && exit 1
	[[ $(which restorecon) = "" ]] && echoRgb "restorecon命令不存在" "0" && exit 1
	#记录开始时间
	starttime1="$(date -u "+%s")"
	echo "$script">"$TMPDIR/scriptTMP"
	Backup_folder="$MODDIR"
	if [[ ! -f $Backup_folder/app_details ]]; then
		echoRgb "$Backup_folder/app_details遗失，无法获取包名" "0" && exit 1
	else
		. "$Backup_folder/app_details" &>/dev/null
	fi
	name1="$ChineseName"
	[[ $name1 = "" ]] && name1="${Backup_folder##*/}"
	[[ $name1 = "" ]] && echoRgb "应用名获取失败" "0" && exit 2
	name2="$PackageName"
	if [[ $name2 = "" ]]; then
		Script_path="$(find "$MODDIR" -maxdepth 1 -name "*.sh*" -type f 2>/dev/null)"
		name2="$(echo "${Script_path##*/}" | sed 's/.sh//g')"
	fi
	[[ $name2 = "" ]] && echoRgb "包名获取失败" "0" && exit 2
	echoRgb "恢复$name1 ($name2)" "2"
	starttime2="$(date -u "+%s")"
	if [[ $(pm path --user "$user" "$name2" 2>/dev/null) = "" ]]; then
		installapk
	else
		apk_version="$(echo "$apk_version" | head -n 1)"
		if [[ $apk_version -gt $(pm list packages --show-versioncode --user "$user" "$name2" 2>/dev/null | cut -f3 -d ':' | head -n 1) ]]; then
			installapk
			echoRgb "版本提升$(pm list packages --show-versioncode --user "$user" "$name2" 2>/dev/null | cut -f3 -d ':' | head -n 1)>$apk_version" "1"
		fi
	fi
	if [[ $(pm path --user "$user" "$name2" 2>/dev/null) != "" ]]; then
	    #停止应用
		[[ $name2 != $Open_apps2 ]] && am force-stop --user "$user" "$name2"
		find "$Backup_folder" -maxdepth 1 ! -name "apk.*" -name "*.tar*" -type f 2>/dev/null | sort | while read; do
			Release_data "$REPLY"
		done
	else
		echoRgb "$name1没有安装无法恢复数据" "0"
	fi
	endtime 1 "恢复开始到结束" && echoRgb "如发现应用闪退请重新开机" && rm -rf "$TMPDIR"/*
	rm -rf "$TMPDIR/scriptTMP"
	wait && exit
	;;
Restore3)
	kill_Serve
	self_test
	echoRgb "点错了?这是恢复自定义资料夹脚本 如果你是要恢复应用那你就点错了\n -音量上继续恢复自定义资料夹，音量下离开脚本" "2"
	echoRgb "假设反悔了要终止脚本请尽速离开此脚本点击终止脚本.sh,否则脚本将继续执行直到结束" "0"
	get_version "恢复自定义资料夹" "离开脚本" && [[ "$branch" = false ]] && exit 0
	mediaDir="$MODDIR/Media"
	[[ -f "$mediaDir/app_details" ]] && app_details="$mediaDir/app_details" &>/dev/null
	Backup_folder2="$mediaDir"
	[[ ! -d $mediaDir ]] && echoRgb "媒体资料夹不存在" "0" && exit 2
	txt="$MODDIR/mediaList.txt"
	[[ ! -f $txt ]] && echoRgb "请执行\"重新生成应用列表.sh\"获取媒体列表再来恢复" "0" && exit 2
	sort -u "$txt" -o "$txt" 2>/dev/null
	#记录开始时间
	starttime1="$(date -u "+%s")"
	echo_log() {
		if [[ $? = 0 ]]; then
			echoRgb "$1成功" "1" && result=0
		else
			echoRgb "$1恢复失败，过世了" "0" && result=1
		fi
	}
	starttime1="$(date -u "+%s")"
	A=1
	B="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
	[[ $B = "" ]] && echoRgb "mediaList.txt压缩包名为空或是被注释了\n -请执行\"重新生成应用列表.sh\"获取列表再来恢复" "0" && exit 1
	echo "$script">"$TMPDIR/scriptTMP"
	{
	while [[ $A -le $B ]]; do
		name1="$(cat "$txt" | grep -v "#" | sed -e '/^$/d' | sed -n "${A}p" | awk '{print $1}')"
		starttime2="$(date -u "+%s")"
		echoRgb "恢复第$A/$B个压缩包 剩下$((B - A))个" "3"
		Release_data "$mediaDir/$name1"
		endtime 2 "$FILE_NAME2恢复" "2" && echoRgb "完成$((A * 100 / B))%" "3" && echoRgb "____________________________________" && let A++
	done
	endtime 1 "恢复结束"
	rm -rf "$TMPDIR/scriptTMP"
	} &
	;;
Getlist)
	case $MODDIR in
	/storage/emulated/0/Android/* | /data/media/0/Android/* | /sdcard/Android/*) echoRgb "请勿在$MODDIR内生成列表" "0" && exit 2 ;;
	esac
	#效验选填是否正确
	isBoolean "$Lo" "Lo" && Lo="$nsx"
	isBoolean "$debug_list" "debug_list" && debug_list="$nsx"
	txtpath="$MODDIR"
	[[ $debug_list = true ]] && txtpath="${txtpath/'/storage/emulated/'/'/data/media/'}"
	nametxt="$txtpath/appList.txt"
	[[ ! -e $nametxt ]] && echo '#不需要备份的应用请在开头注释# 比如#酷安 xxxxxxxx\n#不需要备份数据比如!酷安 xxxxxxxx应用名前方方加一个惊叹号即可 注意是应用名不是包名' >"$nametxt"
	echoRgb "请勿关闭脚本，等待提示结束"
	rgb_a=118
	rm -rf "$MODDIR/tmp"
	starttime1="$(date -u "+%s")"
	echoRgb "提示!因为系统自带app(位于data分区或是可卸载预装应用)备份恢复可能存在问题\n -所以不会输出..但是检测为Xposed类型包名将输出\n -如果提示不是Xposed但他就是Xposed可能为此应用元数据不符合规范导致" "0"
	xposed_name="$(appinfo -o pn -xm)"
	[[ $user = 0 ]] && Apk_info="$(appinfo -sort-i -d " " -o ands,pn -pn $system -3 2>/dev/null | egrep -v 'ice.message|com.topjohnwu.magisk' | sort -u)" || Apk_info="$(appinfo -sort-i -d " " -o ands,pn -pn $system $(pm list packages -3 --user "$user" | cut -f2 -d ':') 2>/dev/null | egrep -v 'ice.message|com.topjohnwu.magisk' | sort -u)"
	[[ $Apk_info = "" ]] && echoRgb "appinfo输出失败" "0" && exit 2
	Apk_Quantity="$(echo "$Apk_info" | wc -l)"
	LR="1"
	echoRgb "列出第三方应用......." "2"
	i="0"
	rc="0"
	rd="0"
	Q="0"
	echo "$Apk_info" | sed 's/\///g ; s/\://g ; s/(//g ; s/)//g ; s/\[//g ; s/\]//g ; s/\-//g ; s/!//g' | while read; do
		[[ $rgb_a -ge 229 ]] && rgb_a=118
		app_1=($REPLY $REPLY)
		if [[ $(cat "$nametxt" | cut -f2 -d ' ' | egrep -w "^${app_1[1]}$") != ${app_1[1]} ]]; then
			case ${app_1[1]} in
			*oneplus* | *miui* | *xiaomi* | *oppo* | *flyme* | *meizu* | com.android.soundrecorder | com.mfashiongallery.emag | com.mi.health | *coloros*)
				if [[ $(echo "$xposed_name" | egrep -w "${app_1[1]}$") = ${app_1[1]} ]]; then
					echoRgb "${app_1[2]}为Xposed模块 进行添加" "0"
					echo "$REPLY" >>"$nametxt" && [[ ! -e $MODDIR/tmp ]] && touch "$MODDIR/tmp"
					let i++ rd++
				else
					if [[ $(echo "$whitelist" | egrep -w "^${app_1[1]}$") = ${app_1[1]} ]]; then
						echo "$REPLY" >>"$nametxt" && [[ ! -e $MODDIR/tmp ]] && touch "$MODDIR/tmp"
						echoRgb "$REPLY($rgb_a)"
						let i++
					else
						echoRgb "${app_1[2]}非Xposed模块 忽略输出" "0"
						let rc++
					fi
				fi
				;;
			*)
				echo "$REPLY" >>"$nametxt" && [[ ! -e $MODDIR/tmp ]] && touch "$MODDIR/tmp"
				echoRgb "$REPLY($rgb_a)"
				let i++
				;;
			esac
		else
			let Q++
		fi
		if [[ $LR = $Apk_Quantity ]]; then
			if [[ $(cat "$nametxt" | wc -l | awk '{print $1-2}') -lt $i ]]; then
				rm -rf "$nametxt" "$MODDIR/tmp"
				echoRgb "\n -输出异常 请将$MODDIR_NAME/backup_settings.conf中的debug_list=\"0\"改为1或是重新执行本脚本" "0"
				exit
			fi
			[[ -e $MODDIR/tmp ]] && echoRgb "\n -第三方apk数量=\"$Apk_Quantity\"\n -已过滤=\"$rc\"\n -xposed=\"$rd\"\n -存在列表中=\"$Q\"\n -输出=\"$i\""
		fi
		let rgb_a++ LR++
	done
	if [[ -f $nametxt ]]; then
		D="1"
		C="$(cat "$nametxt" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
		while [[ $D -le $C ]]; do
			name1="$(cat "$nametxt" | grep -v "#" | sed -e '/^$/d' | sed -n "${D}p" | awk '{print $1}')"
			name2="$(cat "$nametxt" | grep -v "#" | sed -e '/^$/d' | sed -n "${D}p" | awk '{print $2}')"
			{
			if [[ $name2 != "" && $(pm path --user "$user" "$name2" 2>/dev/null | cut -f2 -d ':') = "" ]]; then
				echoRgb "$name1 $name2不存在系统，从列表中删除" "0"
				echo "$(sed -e "s/$name1 $name2//g ; /^$/d" "$nametxt")" >"$nametxt"
			fi
			} &
			let D++
		done
		echo "$(sort "$nametxt" | sed -e '/^$/d')" >"$nametxt"
	fi
	wait
	endtime 1
	[[ ! -e $MODDIR/tmp ]] && echoRgb "无新增应用" || echoRgb "输出包名结束 请查看$nametxt"
	rm -rf "$MODDIR/tmp"
	;;
backup_media)
	kill_Serve
	self_test
	backup_path
	echoRgb "假设反悔了要终止脚本请尽速离开此脚本点击终止脚本.sh,否则脚本将继续执行直到结束" "0"
	A=1
	B="$(echo "$Custom_path" | grep -v "#" | sed -e '/^$/d' | sed -n '$=')"
	if [[ $B != "" ]]; then
		starttime1="$(date -u "+%s")"
		Backup_folder="$Backup/Media"
		[[ ! -d $Backup_folder ]] && mkdir -p "$Backup_folder"
		[[ ! -f $Backup/恢复自定义资料夹.sh ]] && cp -r "$script_path/restore3" "$Backup/恢复自定义资料夹.sh"
		[[ ! -f $Backup/重新生成应用列表.sh ]] && cp -r "$script_path/Get_DirName" "$Backup/重新生成应用列表.sh"
		[[ ! -f $Backup/转换资料夹名称.sh ]] && cp -r "$script_path/convert" "$Backup/转换资料夹名称.sh"
		[[ ! -f $Backup/压缩档完整性检查.sh ]] && cp -r "$script_path/check_file" "$Backup/压缩档完整性检查.sh"
		[[ ! -d $Backup/tools ]] && cp -r "$tools_path" "$Backup" && rm -rf "$Backup/tools/bin/zip" "$Backup/tools/script"
		[[ ! -f $Backup/backup_settings.conf ]] && echo "#1开启0关闭\n\n#是否在每次执行恢复脚本时使用音量键询问如下需求\n#如果是那下面两项项设置就被忽略，改为音量键选择\nLo=$Lo\n\n#备份与恢复遭遇异常或是结束后发送通知(toast与状态栏提示)\ntoast_info=$toast_info\n\n#使用者\nuser=\n\n#脚本检测更新后进行更新?\nupdate=$update\n\n#检测到更新后的行为(1跳转浏览器 0不跳转浏览器，但是复制连结到剪裁版)\nupdate_behavior=$update_behavior\n\n#恢复模式(1仅恢复未安装应用0全恢复)\nrecovery_mode=0\n\n#主色\nrgb_a=$rgb_a\n#辅色\nrgb_b=$rgb_b\nrgb_c=$rgb_c">"$Backup/backup_settings.conf" && echo "$(sed 's/true/1/g ; s/false/0/g' "$Backup/backup_settings.conf")">"$Backup/backup_settings.conf"
		app_details="$Backup_folder/app_details"
		filesize="$(du -ks "$Backup_folder" | awk '{print $1}')"
		[[ -f $app_details ]] && . "$app_details" &>/dev/null || touch "$app_details"
		mediatxt="$Backup/mediaList.txt"
		[[ ! -f $mediatxt ]] && echo "#不需要恢复的资料夹请在开头注释# 比如#媒体" > "$mediatxt"
		echo "$script">"$TMPDIR/scriptTMP"
		{
		echo "$Custom_path" | grep -v "#" | sed -e '/^$/d' | while read; do
			echoRgb "备份第$A/$B个资料夹 剩下$((B - A))个" "3"
			starttime2="$(date -u "+%s")" 
			[[ ${REPLY: -1} = / ]] && REPLY="${REPLY%?}"
			Backup_data "${REPLY##*/}" "$REPLY"
			[[ $result = 0 ]] && [[ $(cat "$mediatxt" | grep -v "#" | sed -e '/^$/d' | grep -w "^${REPLY##*/}.tar$" | head -1) = "" ]] && echo "${REPLY##*/}.tar" >> "$mediatxt"
			endtime 2 "${REPLY##*/}备份" "1"
			echoRgb "完成$((A * 100 / B))% $hx$(echo "$Occupation_status" | awk 'END{print "剩余:"$1"使用率:"$2}')" "2" && echoRgb "____________________________________" && let A++
		done
		Calculate_size "$Backup_folder"
		endtime 1 "自定义备份"
		rm -rf "$TMPDIR/scriptTMP"
		} &
	else
		echoRgb "自定义路径为空 无法备份" "0"
	fi
	;;
esac
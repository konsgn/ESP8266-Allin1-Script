#!/bin/bash

firstarg=$1

#Change these settings to match your setup

Boot=new	#(old=boot_v1.1, new=boot_v1.2+, none=none)
APP=1	#0=eagle.flash.bin+eagle.irom0text.bin, 1=user1.bin, 2=user2.bin
SSPEED=80	#20=20MHz, 26.7=26.7MHz, 40=40MHz, 80=80MHz
SIZEMAP=6		
# SPI Size map settings
# 0= 512KB( 256KB+ 256KB)" //not implemented yet
# 2=1024KB( 512KB+ 512KB)" 8m
# 3=2048KB( 512KB+ 512KB)" 16m
# 4=4096KB( 512KB+ 512KB)" 32m
# 5=2048KB(1024KB+1024KB)" 16m-c1
# 6=4096KB(1024KB+1024KB)" 32m-c1
Baud=230400

Blank=1  # if set, erases esp parameters

XCCPATH=/run/media/$USER/Kondrive/src/ESP/esp-open-sdk/xtensa-lx106-elf/bin
ESPTOOLPATH=/run/media/$USER/Kondrive/src/ESP/esp-open-sdk/esptool/esptool.py
PORT=/dev/ttyUSB0
PORTB=/dev/ttyACM0

#Settings that change based on sizemap
if [[ "$SIZEMAP" = "2" ]];then
	INIT_DATA=0xfc000
	BLANK1='0x7e000'
	BLANK2='0xfe000'
	FILETYPE=8m
elif [[ "$SIZEMAP" = "3" ]];then
	INIT_DATA=0x1fc000
	BLANK1='0x7e000'
	BLANK2='0x1fe000'
	FILETYPE=16m
elif [[ "$SIZEMAP" = "4" ]];then
	INIT_DATA=0x3fc000
	BLANK1='0x7e000'
	BLANK2='0x3fe000'
	FILETYPE=32m
elif [[ "$SIZEMAP" = "5" ]];then
	INIT_DATA=0x1fc000
	BLANK1='0xfe000'
	BLANK2='0x1fe000'
	FILETYPE=16m-c1
elif [[ "$SIZEMAP" = "6" ]];then
	INIT_DATA=0x3fc000
	BLANK1='0xfe000'
	BLANK2='0x3fe000'
	FILETYPE=32m-c1
fi

makeg(){
	#Just in case export path
	export PATH=$XCCPATH:$PATH

	echo "[+] Cleaning:"
	make clean
	echo "[!] Clean!"

	echo ""
	echo "[+] Gcc start:"
	echo ""
	if make COMPILE=gcc BOOT=$Boot APP=$APP SPI_SPEED=$SSPEED SPI_MODE=QIO SPI_SIZE_MAP=$SIZEMAP ; then
		echo "[!] Done!"
	else 
		echo "[-] Compile Failed"
		exit 1
	fi
}

program(){
	if [ $APP == 0 ]; then
		Bootfile='../bin/upgrade/eagle.flash.bin'
		Targetfile='../bin/upgrade/eagle.irom0text.bin'
	elif [ $APP == 1 ]; then
		Bootfile='../bin/boot_v1.4(b1).bin'
		files=(../bin/upgrade/user1*.bin) Targetfile=${files[0]}
		for f in "${files[@]}"; do
		  if [[ $f -nt $Targetfile ]]; then
			Targetfile=$f
		  fi
		done
		#echo $Targetfile
	elif [ $APP == 2 ]; then
		Bootfile='../bin/boot_v1.4\(b1\).bin'
		files=(../bin/upgrade/user2*.bin) Targetfile=${files[0]}
		for f in "${files[@]}"; do
		  if [[ $f -nt $Targetfile ]]; then
			Targetfile=$f
		  fi
		done
	fi

	if [ $Blank == 1 ]; then
		Blank=$BLANK1' ../bin/blank.bin '$BLANK2' ../bin/blank.bin'
	else 
		Blank=' '
	fi
	echo "$Blank"
	
	PROGRAM_SUCCESS=0
	COUNT=1
	echo "[+] Program start"
	while [[ $PROGRAM_SUCCESS -lt 1  &&  $COUNT -lt 4 ]];do
		echo "[!] Attempt number $COUNT"
		if python2.7 $ESPTOOLPATH -p $PORT -b $Baud write_flash 0x00000 $Bootfile 0x01000 $Targetfile $INIT_DATA ../bin/kon_init_data_default.bin $Blank -fs $FILETYPE -ff 80m ; then
	# 0xfe000 ../bin/blank.bin
			let PROGRAM_SUCCESS=PROGRAM_SUCCESS+1
		else 
			let COUNT=COUNT+1 
		fi
	done
	if [ $PROGRAM_SUCCESS -gt 0 ];then
		echo "[!] Done!"
	else 
		echo "[-] Program Failed"
		exit 1
	fi 
}

monitor(){
	echo "[+] Starting Serial monitor"
	screen $PORT 115200
}

erase(){
	ERASE_SUCCESS=0
	COUNT=1
	echo "[+] Erase  start"
	while [[ $ERASE_SUCCESS -lt 1  &&  $COUNT -lt 4 ]];do
		echo "[!] Attempt number $COUNT"
		if python2.7 $ESPTOOLPATH -p $PORT -b $Baud write_flash 0x00000 ../bin/boot_v1.4\(b1\).bin $INIT_DATA ../bin/esp_init_data_default.bin 0x200000 ../bin/blank.bin $BLANK1 ../bin/blank.bin $BLANK2 ../bin/blank.bin -fs $FILETYPE -ff 80m; then
	# 0xfe000 ../bin/blank.bin
			let ERASE_SUCCESS=ERASE_SUCCESS+1
		else 
			let COUNT=COUNT+1 
		fi
	done

	if [ $ERASE_SUCCESS -gt 0 ];then
		echo "[!] Done!"
	else 
		echo "[-] Erase Failed"
	fi 
}

if [[ -z "$firstarg" ]]; then
	makeg
	program
	monitor
elif [[ "$firstarg" = "c" ]];then
	makeg
elif [[ "$firstarg" = "p" ]];then
	program
	monitor
elif [[ "$firstarg" = "m" ]];then
	monitor
elif [[ "$firstarg" = "e" ]];then
	erase
fi

clear
echo "[!] Goodbye"
exit

# ***********************BOOT MODE***********************
# download:
# Flash size 8Mbit: 512KB+512KB
# boot_v1.2+.bin 0x00000
# user1.1024.new.2.bin 0x01000
# esp_init_data_default.bin 0xfc000 (optional)
# blank.bin 0x7e000 & 0xfe000
#
# Flash size 16Mbit: 512KB+512KB
# boot_v1.2+.bin 0x00000
# user1.1024.new.2.bin 0x01000
# esp_init_data_default.bin 0x1fc000 (optional)
# blank.bin 0x7e000 & 0x1fe000
#
# Flash size 16Mbit-C1: 1024KB+1024KB
# boot_v1.2+.bin 0x00000
# user1.2048.new.5.bin 0x01000
# esp_init_data_default.bin 0x1fc000 (optional)
# blank.bin 0xfe000 & 0x1fe000
#
# Flash size 32Mbit: 512KB+512KB
# boot_v1.2+.bin 0x00000
# user1.1024.new.2.bin 0x01000
# esp_init_data_default.bin 0x3fc000 (optional)
# blank.bin 0x7e000 & 0x3fe000
#
# Flash size 32Mbit-C1: 1024KB+1024KB
# boot_v1.2+.bin 0x00000
# user1.2048.new.5.bin 0x01000
# esp_init_data_default.bin 0x3fc000 (optional)
# blank.bin 0xfe000 & 0x3fe000
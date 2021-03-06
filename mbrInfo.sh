#!/bin/bash
# Purpose = Read MBR - GPT from any device or DD image
# Output: infromation about MBR - GPT structure and partitions
# Created on 06/11/2017
# Author = G.Nikolaidis
# Contact = gnlinuz@yahoo.com
# Version 1.00

partitionCount=0
firstEntry=1024
gptPartitionCounter=0
c=0
h="hex"
noExtend="yes"
vol=1
#_____________________________________FUNCTIONS_____________________________________________
#___________________________________________________________________________________________
start()
{ 	clear
	echo "--------------------------------------------------------------------------------------------------------"
	echo "Please enter the device to read the mbr. (ex. /dev/sda) or"
	echo "enter the path and filename of mbr to check (ex. /mnt/mbr.img)"
	echo "--------------------------------------------------------------------------------------------------------"
	echo -en '\E[32;40m'"devices that have been discovered:"; echo -e '\E[0m'
	echo "--------------------------------------------------------------------------------------------------------"
	fdisk -l |grep "Disk /dev/"
	echo "--------------------------------------------------------------------------------------------------------"
	read path_of
	echo "--------------------------------------------------------------------------------------------------------"
	if [ ! -e $path_of ] && [ ! -b $path_of ] || [ -z $path_of ]; then
    		echo -en '\E[32;40m'"The filename does not exist!! check your path or filename "; echo -e '\E[0m'}
    	exit
	fi
}
#______________________________Read the 4 MBR partition lines_______________________________
#___________________________________________________________________________________________
read4PartitionsLines()
{
	local i=0
	local j=430
	for i in {0..3}
	do
        	let "j=j+16"
        	partitionLines[$i]=`hexdump -C $path_of -s $j -n 16`
	done
}
#_______________________________Get clean partition line____________________________________
#___________________________________________________________________________________________
getPartitionLine()
{
        local partTableNo=$1
        local wholePartitionLine=${partitionLines[partTableNo]}
        cleanPartitionLine=${wholePartitionLine:10:48}
}
#____________________________Read and save partition type___________________________________
#___________________________________________________________________________________________
readPartitionType()
{
	cpl=$1
	pline=""
	partitionType=$(echo $cpl | cut -d' ' -f5)
	while read pline
	do
		ptype=$(echo $pline | cut -d' ' -f1)
		if [ "$partitionType" == "$ptype" ];then
			partitionTypeIs=$pline
		fi
	done<partition_types
}
#______________________________Get partition size and starting sector_______________________
#___________________________________________________________________________________________
getPartitionSizeSector()
{
	getPartitionLine $partitionCount
	for t in {16..13}
	do
		partitionSize=$partitionSize$(echo $cleanPartitionLine | cut -d' ' -f$t)
	done
	for r in {12..9}
    	do
		startingSector=$startingSector$(echo $cleanPartitionLine | cut -d' ' -f$r)
    	done
}
#____________Calculate partition size,starting sector,ending sector_________________________
#___________________________________________________________________________________________
calculateSizeSector()
{
	pS=$1
	sS=$2
	pHex=`echo "${pS^^}"`
	dVal=`echo "ibase=16; $pHex"|bc`

    	printf "Partition size in Hex value is = 0x$pHex"
    	printf " -- in Dec value is = $dVal"

	decPartitionSize=`echo "ibase=16; $pHex"|bc`
	bSize=`echo "$decPartitionSize*512"|bc`
	gb=`echo "scale=3; $bSize / 1024^3"|bc`

	if (( `echo "scale=3; $gb<1"|bc` == 1 ));then
		gbb=`echo "scale=3; $bSize / 1024^2"|bc`
		echo -en '\E[32;40m'" -- size: $gbb MB "; echo -e '\E[0m'
    	else
		echo -en '\E[32;40m'" -- size: $gb GB "; echo -e '\E[0m'
	fi

	pHex=`echo -e "${sS^^}"`
	decStartingSector=`echo -e "ibase=16; $pHex"|bc`

	printf "start sector: $decStartingSector "
	mExtSSb=$((decStartingSector*512))
	endSector=$(($decStartingSector+$decPartitionSize-1))
	printf ", end sector: $endSector "
}
#_________________________Checks if partition is bootable___________________________________
#___________________________________________________________________________________________
isPartitionBootable()
{
	cpl=$1
	pIsBoot=$(echo $cpl |cut -d' ' -f1)
	if [ "$pIsBoot" == "80" ];then
        	boot="bootable 80"
	else
		boot="not bootable 00"
        fi
}
#___________________________________Get the hard disk signature_____________________________
#___________________________________________________________________________________________
getHardDiskSignature()
{
	local tmp=`hexdump -C $path_of -s 440 -n 4`
	cleanSigLine=${tmp:10:13}
	for e in {4..1}
	do
        	sigLine=$sigLine$(echo $cleanSigLine | cut -d' ' -f$e)
	done
}



#_____________________________________GPT PARTITION_________________________________________
#___________________________________________________________________________________________
readGptHeader()
{
     	echo

}
getUuidDisk()
{
	offSet=$1
	uuid=""
	line1=""
	line2=""
	line3=""
	line4=""
	cleanGptLine=""
	wholeGptLine=`hexdump -C $path_of -s$offSet -n16`
	cleanGptLine=${wholeGptLine:10:48}
	#echo "clean line is: $cleanGptLine"
	d="-"
	for i in {4..1}
	do
        line1=$line1$(echo $cleanGptLine |cut -d' ' -f$i)
	done

	for i in {6..5}
	do
        line2=$line2$(echo $cleanGptLine |cut -d' ' -f$i)
	done

	for i in {8..7}
	do
        line3=$line3$(echo $cleanGptLine |cut -d' ' -f$i)
	done

	for i in {9..16}
	do
        line4=$line4$(echo $cleanGptLine |cut -d' ' -f$i)
        if [ "$i" == "10" ];then
                line4=$line4$d
        fi
	done

	uuid=$line1$d$line2$d$line3$d$line4
	xUUID=`echo ${uuid^^}`
}
getGptVer()
{
	verGptLine=`hexdump -C $path_of -s520 -n4`
	gptVer=${verGptLine:10:20}
	echo -en '\E[31;40m'"GPT version:  $gptVer";echo -en '\E[0m'
}
getGptBackupHeaderLocation()
{
	bakGptHead=`hexdump -C $path_of -s544 -n8`
	gptVerLine=${bakGptHead:10:32}
	for i in {8..1}
	do
        	verLine=$verLine$(echo $gptVerLine |cut -d' ' -f$i)
	done
	vHex=`echo ${verLine^^}`
	nzHex=$(echo $vHex | sed 's/^0*//')
	echo -n "GPT header backup location: $nzHex $h, "
	decGptVer=`echo "ibase=16; $vHex"|bc`
	echo -n "$decGptVer dec, "
	headLoc=$((decGptVer*512))
	echo "absolute byte pos: $headLoc"
}
getStartingLba()
{
	lbaLine=""
	sP=$1
	startLba=`hexdump -C $path_of -s$sP -n8`
	sLbaLine=${startLba:10:32}
	for i in {8..1}
	do
        	lbaLine=$lbaLine$(echo $sLbaLine |cut -d' ' -f$i)
	done
	lHex=`echo ${lbaLine^^}`
	nzHex=$(echo $lHex | sed 's/^0*//')
	echo -n "Start LBA: $nzHex $h, "
	decSLba=`echo "ibase=16; $lHex"|bc`
	sLbaVal=$((decSLba*512))
	echo -n "absolute byte pos: $sLbaVal"
}
getEndingLba()
{
	eLine=""
	sP=$1
	endLba=`hexdump -C $path_of -s$sP -n8`
	eLbaLine=${endLba:10:32}
	for i in {8..1}
	do
        	eLine=$eLine$(echo $eLbaLine |cut -d' ' -f$i)
	done
	eHex=`echo ${eLine^^}`
	nzHex=$(echo $eHex | sed 's/^0*//')
	echo -n ", End LBA: $nzHex $h, "
	decELba=`echo "ibase=16; $eHex"|bc`
	eLbaVal=$((decELba*512))
	echo "absolute byte pos: $eLbaVal"
}
calculateGptSize()
{
	seSize=$((decELba-decSLba+1))
	gptSize=$((seSize*512))
	gb=`echo "scale=3; $gptSize / 1024^3"|bc`
	if (( `echo "scale=3; $gb<1"|bc` == 1 ));then
		gbb=`echo "scale=3; $gptSize / 1024^2"|bc`
		echo -en '\E[32;40m'"size: $gbb MB "; echo -e '\E[0m'
    	else
		echo -en '\E[32;40m'"size: $gb GB "; echo -e '\E[0m'
	fi
}
readUuidEntry()
{
	gptPartitionCounter=$((gptPartitionCounter+1))
	getUuidDisk "$firstEntry"
	if [ "$xUUID" == "00000000-0000-0000-0000-000000000000" ];then
		printf "*"
		c=$((c+1))
		if [ "$c" == "104" ];then
			echo
		fi
	else
		while read uuidLine
		do
			guidLine=$(echo $uuidLine | cut -d, -f3)
			if [ "$xUUID" == "$guidLine" ];then
				partitionTypeGUID=$uuidLine
				break
			fi
		done<partitionTypesGUID
		echo "--------------------------------------------------------------------------------------------------------"
		echo -en '\E[31;40m'"GPT partition $gptPartitionCounter ID: $partitionTypeGUID"; echo -e '\E[0m'

		uQ=$((firstEntry+16))
		getUuidDisk "$uQ"
		if [ "xUUID" != "00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00" ];then
			echo -n "Uniq partition GUID is: ";echo -en '\E[32;40m'"$xUUID"; echo -e '\E[0m'
		fi

		sLBA=$((firstEntry+32))
		getStartingLba "$sLBA"
		eLBA=$((firstEntry+40))
		getEndingLba "$eLBA"
		calculateGptSize
	fi
	firstEntry=$((firstEntry+128))
}

#_____________________________________EBR PARTITION_________________________________________
#___________________________________________________________________________________________

getEbrSizeStartingSector()
{
	cel=$1
        ebrSize=""
	ebrSS=""
	for t in {16..13}
        do
                ebrSize=$ebrSize$(echo $cel | cut -d' ' -f$t)
        done
        for r in {12..9}
        do
                ebrSS=$ebrSS$(echo $cel | cut -d' ' -f$r)
        done

	SSHex=`echo ${ebrSS^^}`
        nzHex=$(echo $SSHex | sed 's/^0*//')
	decEbrSS=`echo "ibase=16; $nzHex"|bc`
}

getEBRLines()
{
	aBytePos=$1
	ebrLinePos=$((aBytePos+446))

	ebrLine=`hexdump -C $path_of -s$ebrLinePos -n16`
	cleanEbrLine=${ebrLine:10:49}
	isPartitionBootable "$cleanEbrLine"
	echo -en '\E[32;40m'"$path_of$pc logical vol:$vol  $cleanEbrLine"; echo -en '\E[0m';echo -e '\E[31;40m'" is $boot"; echo -en '\E[0m'

	getEbrSizeStartingSector "$cleanEbrLine"
	calculateSizeSector "$ebrSize" "$ebrSS"

	startlogicalSec=$((decStartingSector+mExtSS))
	endLogicalSec=$endSector

	readPartitionType "$cleanEbrLine"
	echo -en "ID: ";echo -e '\E[32;40m'"$partitionTypeIs"; echo -en '\E[0m'
	echo "--------------------------------------------------------------------------------------------------------"
	pc=$((pc+1))

	ebrEntryPos=$((aBytePos+462))
	ebrLine=""
	cleanEbrLine=""
	ebrLine=`hexdump -C $path_of -s $ebrEntryPos -n 16`
	cleanEbrLine=${ebrLine:10:49}

	noSpaceLine=`echo $cleanEbrLine | tr -d ' '`
#	echo "na space line is:$noSpaceLine"
	if [ "$noSpaceLine" == "00000000000000000000000000000000" ];then
                echo -en '\E[31;40m'"End of extended partition ------------------------------------------------------------------------------"; echo -e '\E[0m'
		noExtend="no"
	else
		getEbrSizeStartingSector "$cleanEbrLine"
		mExtSSb=$(((mExtSS+decEbrSS)*512))
        fi
	let "vol=vol+1"
}



#_____________________________________SCRIPT BEGIN__________________________________________
#___________________________________________________________________________________________

start
read4PartitionsLines
getHardDiskSignature
HexSig=`echo "${sigLine^^}"`
echo -en "Hard disk signature is: ";echo -en '\E[32;40m'"$HexSig"; echo -e '\E[0m'
echo "--------------------------------------------------------------------------------------------------------"

for q in {0..3}
do
	partitionSize=""
	startingSector=""
	getPartitionLine $q
	readPartitionType "$cleanPartitionLine"
	isPartitionBootable "$cleanPartitionLine"
	pc=$(($partitionCount+1))

	case $partitionType in
	05 | 0f | 85)
		echo -e '\E[31;40m'"Extended partition"
		echo "------------------";echo -en '\E[0m'
		getPartitionSizeSector
                calculateSizeSector "$partitionSize" "$startingSector"
		echo
		echo "--------------------------------------------------------------------------------------------------------"
		mExtSS=$decStartingSector
		while [ $noExtend == "yes" ]
		do
			getEBRLines "$mExtSSb"
		done
	;;
	ee)
		echo "GPT partition"
		echo "-------------"
		#readGptHeader
		getGptVer
		getUuidDisk 568
		echo -en '\E[32;40m'"disk uuid: $xUUID";echo -e '\E[0m'
	        echo "--------------------------------------------------------------------------------------------------------"
		getGptBackupHeaderLocation
		getStartingLba 552
		getEndingLba 560
		calculateGptSize
		for f in {1..128}
		do
			readUuidEntry
		done
	;;
	00)
		echo
		if [ "$pc" == "4" ];then
			printf "MBR partition $pc is empty..."
			echo
		else
			printf "MBR partition $pc is empty..."
		fi
	;;
	*)
		echo -en '\E[32;40m'"Partition:$pc $path_of$pc $cleanPartitionLine"; echo -en '\E[0m';echo -e '\E[31;40m'" is $boot"; echo -en '\E[0m'
		getPartitionSizeSector
		calculateSizeSector "$partitionSize" "$startingSector"
		echo -en "ID: ";echo -e '\E[32;40m'"$partitionTypeIs"; echo -en '\E[0m'
		echo "--------------------------------------------------------------------------------------------------------"
	;;
	esac
	let "partitionCount=partitionCount+1"
done

#_____________________________________END SCRIPT____________________________________________
#___________________________________________________________________________________________

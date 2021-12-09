#!/bin/bash

export PATH=$PATH:/cygdrive/d/Program/cygwin64/bin

MSR_CMD=/cygdrive/d/Program/msr-watchdog/msr-cmd.exe

# set -x

# exec >> /cygdrive/r/v3_turbo_`date '+%Y-%m-%d_%H_%M_%S'`.log 2>&1

#
# HOW TO USE
#
# 1 remove microcode update in BIOS file and flash it to board
#   o v3x4 module is not required to inserted into BIOS
#
# 2 disable any package and cpu c-state in BIOS which may prevent booting into OS
# o some ucode removed motherboards may fail to boot into OS with c-state enabled
#
# 3 rename or delete microcode update provided by Windows
# C:\Windows\System32\mcupdate_GenuineIntel.dll
#
# 4 get microcode.dat and install vmware cpumcupdate kernel driver
# o vmware cpumcupdate
#   https://labs.vmware.com/flings/vmware-cpu-microcode-update-driver
# o dummy amd mc bin 
#   https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/tree/amd-ucode
# o get some microcode.dat
#   https://1drv.ms/f/s!AgP0NBEuAPQRpdoWT_3G3XCdotPmWQ
#   https://github.com/platomav/CPUMicrocodes
# o more info about microcode.dat
#   https://onedrive.live.com/?authkey=%21AIlV3zL6AzTkzGk&cid=11F4002E1134F403&id=11F4002E1134F403%21643183&parId=11F4002E1134F403%21643182&o=OneUp
# 
# 5 set cpumcupdate to manually start (IMPORTANT!)
# o regedit, goto [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\cpumcupdate]
#   o change value of [Start] to [0x03] which means manually
#
# 6 install cygwin64 and execute this script with 
#   windows task scheduler on startup and S3/S4 resume
# o event to detect S3/S4 resume in task scheduler:
#   o log:    [SYSTEM]
#   o source  [Power-Troubleshooter]
#   o ID:     [1]
#   what this script does:
# o set turbo bin with bugged ucode version
# o start vmware cpumcupdate to load new ucode
#
# NOTE: new ucode may improve some performace in some cases that's
# why this script is struggling to make new ucode works with turbo bin bug.
# but some motherbaords may fail to resume from S4 (hibernate) state
# with ucode REMOVED in BIOS and NEWER ucode LOADED in OS. if so,
# you may be out of luck, just set turbo bin and run without new ucode.
#

msr_write()
{
  local pkg=$1
  local cpu=$2
  local reg=$3
  local edx=$4
  local eax=$5

  if [ $# -ne 5 ]; then
    echo "invalid parameters: $@"
    echo "press any key to exit..."
    read
    exit -1
  fi

  echo "msr write: $@"

  if [ "$cpu" = "A" -o "$cpu" = "ALL" ]; then
    ${MSR_CMD} -g $pkg -a -s write $reg $edx $eax
  else
    ${MSR_CMD} -g $pkg -p $cpu -s write $reg $edx $eax
  fi

  if [ $? -ne 0 ]; then
    echo "write msr failed: $@"
    echo "press any key to exit..."
    read
    exit -1
  fi
}

echo "V3 TURBO"

# sleep 3

sc query cpumcupdate 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "cpumcupdate service is not installed"
  exit 1
fi

echo "cpumcupdate service is installed"

sc query cpumcupdate | grep STATE | grep -q STOPPED
if [ $? -ne 0 ]; then
  echo "cpumcupdate service is not stopped"
  exit 1
fi

echo "cpumcupdate service is stopped"

# UNCORE RATIO
# msr_write 0 0 0x00000620 0x00000000 0x00000c1e
# LOCK TO MAX TO REDUCE LAG
# msr_write 0 0 0x00000620 0x00000000 0x00001e1e

#
# NOTE: set voltage after loading NEWER ucode will RESET turbo bin
#

# IA CORE -50mV
msr_write 0 0 0x00000150 0x80000011 0xf9c00000

# UNCORE -50mV
msr_write 0 0 0x00000150 0x80000211 0xf9c00000

# SYSTEM AGENT -50mV
msr_write 0 0 0x00000150 0x80000311 0xf9c00000

# UNLOCK TURBO BIN
msr_write 0 0 0x000001ad 0x1f1f1f1f 0x1f1f1f1f
msr_write 0 0 0x000001ae 0x1f1f1f1f 0x1f1f1f1f
msr_write 0 0 0x000001af 0x80000000 0x00001f1f

echo "cpumcupdate service is starting"

sc start cpumcupdate
sc query cpumcupdate | grep STATE | grep -q RUNNING
if [ $? -ne 0 ]; then
  echo "failed to start cpumcupdate"
  exit 1
fi

sc stop cpumcupdate
sc query cpumcupdate | grep STATE | grep -q STOPPED
if [ $? -ne 0 ]; then
  echo "failed to stop cpumcupdate"
  exit 1
fi

# C-STATE
# msr_write 0 A 0x000000e2 0x00000000 0x1e000400

echo "done"

exit 0
#!/bin/bash

# stevezhengshiqi 创建于2019年2月8日。
# 暂时只支持大部分5代-8代U, 更老的CPU不使用X86PlatformPlugin.kext。
# 此脚本很依赖于 CPUFriend(https://github.com/acidanthera/CPUFriend), 感谢PMHeart。

# 当前的board-id
BOARD_ID="$(ioreg -lw0 | grep -i "board-id" | sed -e '/[^<]*</s///; s/\"//g; s/\>//')"

# 对应的plist
X86_PLIST="/System/Library/Extensions/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/${BOARD_ID}.plist"

# 支持的型号
EPP_SUPPORTED_MODELS=(
  'Mac-9AE82516C7C6B903' # MacBook9,1
  'Mac-EE2EBD4B90B839A8' # MacBook10,1
  'Mac-827FAC58A8FDFA22' # MacBookAir8,1
  'Mac-473D31EABEB93F9B' # MacBookPro13,1
  'Mac-66E35819EE2D0D05' # MacBookPro13,2
  'Mac-A5C67F76ED83108C' # MacBookPro13,3
  'Mac-B4831CEBD52A0C4C' # MacBookPro14,1
  'Mac-CAD6701F7CEA0921' # MacBookPro14,2
  'Mac-551B86E5744E2388' # MacBookPro14,3
  'Mac-937A206F2EE63C01' # MacBookPro15,1
  'Mac-827FB448E656EC26' # MacBookPro15,2
)

EPP_SUPPORTED_MODELS_SPECIAL=(
'Mac-7BA5B2DFE22DDD8C' # Macmini8,1
)

LFM_SUPPORTED_MODELS=(
  'Mac-BE0E8AC46FE800CC' # MacBook8,1
  'Mac-9F18E312C5C2BF0B' # MacBookAir7,1
  'Mac-937CB26E2E02BB01' # MacBookAir7,2
  'Mac-E43C1C25D4880AD6' # MacBookPro12,1
  'Mac-A369DDC4E67F1C45' # iMac16,1
  'Mac-FFE5EF870D7BA81A' # iMac16,2
  'Mac-4B682C642B45593E' # iMac18,1
  'Mac-77F17D7DA9285301' # iMac18,2
)

function printHeader() {
  printf '\e[8;40;110t'

  # 界面 (参考: http://patorjk.com/software/taag/#p=display&f=Ivrit&t=C%20P%20U%20F%20R%20I%20E%20N%20D)
  echo '  ____   ____    _   _   _____   ____    ___   _____   _   _   ____ '
  echo ' / ___| |  _ \  | | | | |  ___| |  _ \  |_ _| | ____| | \ | | |  _ \ '
  echo '| |     | |_) | | | | | | |_    | |_) |  | |  |  _|   |  \| | | | | | '
  echo '| |___  |  __/  | |_| | |  _|   |  _ <   | |  | |___  | |\  | | |_| | '
  echo ' \____| |_|      \___/  |_|     |_| \_\ |___| |_____| |_| \_| |____/ '
  echo
  echo "你的board-id是 ${BOARD_ID}"
  echo '====================================================================='
}

# 检查board-id
function checkBoardID() {
  if echo "${EPP_SUPPORTED_MODELS[@]}" | grep -w "${BOARD_ID}" &> /dev/null; then
    support=2
  elif echo "${EPP_SUPPORTED_MODELS_SPECIAL[@]}" | grep -w "${BOARD_ID}" &> /dev/null; then
    support=3
  elif echo "${LFM_SUPPORTED_MODELS[@]}" | grep -w "${BOARD_ID}" &> /dev/null; then
    support=1
  else
    echo 'ERROR: 抱歉，你的board-id暂不被支持!'
    exit 1
  fi
}

function getGitHubLatestRelease() {
  local repoURL='https://api.github.com/repos/acidanthera/CPUFriend/releases/latest'
  ver="$(curl --silent "${repoURL}" | grep 'tag_name' | head -n 1 | awk -F ":" '{print $2}' | tr -d '"' | tr -d ',' | tr -d ' ')"

  if [[ -z "${ver}" ]]; then
    echo "WARNING: 无法从${repoURL}获取最新release。"
    exit 1
  fi
}

# 如果网络异常，退出
function networkWarn() {
  echo "ERROR: 下载CPUFriend失败, 请检查网络状态!"
  exit 1
}

# 下载CPUFriend仓库并解压最新release
function downloadKext() {
  WORK_DIR="/Users/`users`/Desktop/one-key-cpufriend"
  [[ -d "${WORK_DIR}" ]] && sudo rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}" && cd "${WORK_DIR}"

  echo
  echo '----------------------------------------------------------------------'
  echo '|* 正在下载CPUFriend，源自github.com/acidanthera/CPUFriend @PMHeart *|'
  echo '----------------------------------------------------------------------'

  # 下载ResourceConverter.sh
  local rcURL='https://raw.githubusercontent.com/acidanthera/CPUFriend/master/ResourceConverter/ResourceConverter.sh'
  curl --silent -O "${rcURL}" && chmod +x ./ResourceConverter.sh || networkWarn

  # 下载CPUFriend.kext
  local cfVER="${ver}"
  local cfFileName="${cfVER}.RELEASE.zip"
  local cfURL="https://github.com/acidanthera/CPUFriend/releases/download/${cfVER}/${cfFileName}"
  # GitHub的CDN是被Amazon所拥有, 所以我们在这添加 -L 来支持重置链接
  curl --silent -L -O "${cfURL}" || networkWarn
  # 解压
  unzip -qu "${cfFileName}"
  # 移除不需要的文件
  rm -rf "${cfFileName}" 'CPUFriend.kext.dSYM'
  echo '下载完成'
  echo
}

# 拷贝目标plist
function copyPlist() {
  if [[ ! -f "${X86_PLIST}" ]]; then
    echo "ERROR: 未找到${X86_PLIST}!"
    exit 1
  fi

  cp "${X86_PLIST}" .
}

# 修改LFM值来调整最低频率
# 重新考虑这个方法是否必要, 因为LFM看起来不会影响性能表现
function changeLFM(){
  echo "------------------------------"
  echo "|****** 选择低频率模式 ******|"
  echo "------------------------------"
  echo "(1) 保持不变 (1200/1300mhz)"
  echo "(2) 800mhz (低负载下更省电)"
  read -p "你想选择哪个选项? (1/2):" lfm_selection
  case "${lfm_selection}" in
  1)
  # 保持不变
  ;;

  2)
  # 把 1200/1300 改成 800

  # 修改 020000000d000000 成 0200000008000000
  /usr/bin/sed -i "" "s:AgAAAA0AAAA:AgAAAAgAAAA:g" $BOARD_ID.plist

  # 修改 020000000c000000 成 0200000008000000
  /usr/bin/sed -i "" "s:AgAAAAwAAAA:AgAAAAgAAAA:g" $BOARD_ID.plist
  ;;

  *)
  echo "ERROR: 输入有误, 脚本将退出"
  exit 1
  ;;
 esac
}

# 修改EPP值来调节性能模式 (参考: https://www.tonymacx86.com/threads/skylake-hwp-enable.214915/page-7)
# TO DO: 用更好的方式来修改变频参数, 见 https://github.com/Piker-Alpha/freqVectorsEdit.sh
function changeEPP(){
  echo "----------------------------"
  echo "|****** 选择性能模式 ******|"
  echo "----------------------------"
  echo "(1) 最省电模式"

  # 处理EPP_SUPPORTED_MODELS_SPECIAL
  if [ "${support}" == 2 ]; then
    echo "(2) 平衡电量模式 (默认)"
    echo "(3) 平衡性能模式"
  elif [ "${support}" == 3 ]; then
    echo "(2) 平衡电量模式"
    echo "(3) 平衡性能模式 (默认)"
  fi

  echo "(4) 高性能模式"
  read -p "你想选择哪个模式? (1/2/3/4):" epp_selection
  case "${epp_selection}" in
    1)
    # 把 80/90/92 改成 C0, 最省电模式

    # 修改 657070000000000000000000000000000000000080 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAc:DAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000080 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAd:DAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000092 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:CSAAAAAAAAAAAAAAAAAAAAc:DAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000090 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:CQAAAAAAAAAAAAAAAAAAAAc:DAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000092 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACS:ZXBwAAAAAAAAAAAAAAAAAAAAAADA:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000080 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACA:ZXBwAAAAAAAAAAAAAAAAAAAAAADA:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000020 成 6570700000000000000000000000000000000000c0
    /usr/bin/sed -i "" "s:AgAAAAAAAAAAAAAAAAAAAAd:DAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist
    ;;

    2)
    if [ "${support}" == 2 ] && [ "${lfm_selection}" == 1 ]; then
      # 保持默认值 80/90/92, 平衡电量模式
      # 如果LFM也没有改变, 退出脚本
      echo "不忘初心，方得始终。下次再见。"
      echo
      clean
      exit 0

    # 处理 EPP_SUPPORTED_MODELS_SPECIAL
    elif [ "${support}" == 3 ]; then
      # 把 20 改成 80, 平衡电量模式

      # 修改 657070000000000000000000000000000000000020 成 657070000000000000000000000000000000000080
      /usr/bin/sed -i "" "s:AgAAAAAAAAAAAAAAAAAAAAd:CAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist
    fi
    ;;

    3)
    if [ "${support}" == 2 ]; then
      # 把 80/90/92 改成 40, 平衡性能模式

      # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAc:BAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

      # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAd:BAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist

      # 修改 657070000000000000000000000000000000000092 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:CSAAAAAAAAAAAAAAAAAAAAc:BAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

      # 修改 657070000000000000000000000000000000000090 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:CQAAAAAAAAAAAAAAAAAAAAc:BAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

      # 修改 657070000000000000000000000000000000000092 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACS:ZXBwAAAAAAAAAAAAAAAAAAAAAABA:g" $BOARD_ID.plist

      # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000040
      /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACA:ZXBwAAAAAAAAAAAAAAAAAAAAAABA:g" $BOARD_ID.plist

    elif [ "${support}" == 3 ] && [ "${lfm_selection}" == 1 ]; then
      # 保持默认值 20, 平衡性能模式
      # 如果LFM也没有改变, 退出脚本
      echo "不忘初心，方得始终。下次再见。"
      echo
      clean
      exit 0
    fi
    ;;

    4)
    # 把 80/90/92 改成 00, 高性能模式

    # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAc:AAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:CAAAAAAAAAAAAAAAAAAAAAd:AAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000092 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:CSAAAAAAAAAAAAAAAAAAAAc:AAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000090 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:CQAAAAAAAAAAAAAAAAAAAAc:AAAAAAAAAAAAAAAAAAAAAAc:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000092 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACS:ZXBwAAAAAAAAAAAAAAAAAAAAAAAA:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000080 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:ZXBwAAAAAAAAAAAAAAAAAAAAAACA:ZXBwAAAAAAAAAAAAAAAAAAAAAAAA:g" $BOARD_ID.plist

    # 修改 657070000000000000000000000000000000000020 成 657070000000000000000000000000000000000000
    /usr/bin/sed -i "" "s:AgAAAAAAAAAAAAAAAAAAAAd:AAAAAAAAAAAAAAAAAAAAAAd:g" $BOARD_ID.plist
    ;;

    *)
    echo "ERROR: 输入有误, 脚本将退出"
    exit 1
    ;;
  esac
}

# 生成 CPUFriendDataProvider.kext 并复制到桌面
function generateKext(){
  echo "正在生成CPUFriendDataProvider.kext"
  ./ResourceConverter.sh --kext $BOARD_ID.plist
  cp -r CPUFriendDataProvider.kext /Users/`users`/Desktop/

  # 拷贝CPUFriend.kext到桌面
  cp -r CPUFriend.kext /Users/`users`/Desktop/

  echo "生成完成"
  echo
}

# 清理临时文件夹文件夹并结束
function clean(){
  echo "正在清理临时文件"
  sudo rm -rf "${WORK_DIR}"
  echo "清理完成"
  echo
}

# 主程序
function main(){
  printHeader
  checkBoardID
  getGitHubLatestRelease
  downloadKext
  if [ "${support}" == 1 ]; then
    copyPlist
    changeLFM
  elif [ "${support}" == 2 ] || [ "${support}" == 3 ]; then
    copyPlist
    changeLFM
    echo
    changeEPP
  fi
  echo
  generateKext
  clean
  echo "很棒！脚本运行结束, 请把桌面上的CPUFriend和CPUFriendDataProvider放入/CLOVER/kexts/Other/(或者L/E/)下"
  exit 0
}

main

# Contributing

Contributions to the TorBox project are more than welcome. Fixes, clean-ups and improvements of existing code are much appreciated, as are completion functions for new commands.

However, it may well be that certain features were not implemented on purpose or were implemented in the manner found. It is, therefore, worth submitting a suggestion under [Issues](https://github.com/radio24/TorBox/issues) before starting work. The central question that should be answered is what added value will be generated with the contribution.

## Coding Guidelines
Please bear the following coding guidelines in mind:
- Whenever, shell script should be used. Because sh is too limited, the shell script should be compatible with bash >= 4.2.

- If a feature can not be implemented with shell script - for example, because of complexity - alternatively, Python >= 3 should be used.

- Currently, all added features should run under Raspberry Pi OS (priority 1), Debian (priority 2) and Ubuntu (priority 3) and should be independent of the used hardware. If your code was written for a particular platform, try to make it portable to other platforms so that everyone may enjoy it. If your code works only with the version of a binary on a particular platform, ensure that it will not be loaded on other platforms that have a command with the same name.

  **Identify the Operation System**
  ```shell
  CHECK_OS="$(lsb_release -si)"
  ```

  **Check if it is a Raspberry Pi**
  ```shell
  if grep -q --text 'Raspberry Pi' /proc/device-tree/model; then CHECK_HD1="Raspberry Pi"; fi
  if grep -q "Raspberry Pi" /proc/cpuinfo; then CHECK_HD2="Raspberry Pi"; fi
  ```

  (...and for the version of Raspberry Pi, see [here](https://gist.github.com/jperkin/c37a574379ef71e339361954be96be12))
  ```shell
  if grep -q --text 'Raspberry Pi 3 Model B Rev' /proc/device-tree/model; then CHECK_HD1="Raspberry Pi 3 Model B Rev"; fi
  if grep -q "Raspberry Pi 3 Model B Rev" /proc/cpuinfo; then CHECK_HD2="Raspberry Pi 3 Model B Rev"; fi
  ```

  **Check if the OS is 64bit**
  ```shell
  CHECK_64="32bit"
  if uname -m | grep -q -E "arm64|aarch64"; then CHECK_64="32bit"; fi
  ```

- All menus should start with a one-digit number with a leading space or a two-digit number. The menu selection should be implemented with `case` for clarity and not, for example, with `elif` (this guideline is currently being implemented).

  **Example for a short menu**
  ```shell
  clear
  CHOICE=$(whiptail --cancel-button "Back" --title "TorBox v.0.5.1 - ADD BRIDGES MENU" --menu "Choose an option (ESC -> back to the main menu)" $MENU_HEIGHT $MENU_WIDTH $MENU_LIST_HEIGHT \
  "==" "===============================================================" \
  " 1" "Add one OBFS4 bridge automatically (one bridge every 24 hours)"  \
  " 2" "Add OBFS4 bridges manually"  \
  "==" "===============================================================" \
  3>&1 1>&2 2>&3)
  CHOICE=$(echo "$CHOICE" | tr -d ' ')
  case "$CHOICE" in

    # Add bridges automatically
    1)
      ......
    ;;

    # Add bridges manually
    2)
      ......
    ;;

    *)
      clear
      exit 0
  esac
  ```

- Writing URLs to a file, use `|` as a delimiter (this guideline is currently being implemented):
  `sed "s|GO_DL_PATH=.*|GO_DL_PATH=${GO_DL_PATH}|" torbox.run`

  Depreciated and should be replaced:
  ```shell
  REPLACEMENT_STR="$(<<< "$GO_DL_PATH" sed -e 's`[][\\/.*^$]`\\&`g')"
  sudo sed -i "s/^GO_DL_PATH=.*/GO_DL_PATH=${REPLACEMENT_STR}/g" torbox.run
  ```

- To suppress undesired terminal outputs, '&>/dev/null' or '2> /dev/null' should be used at the end of a command, as in the example below (this guideline is currently being implemented):

  ```shell
  (printf "[$DATE] - Log file created!\n" | sudo -u debian-tor tee $LOG) &>/dev/null
  ```

- `! -z` for non zero/not null and `-z` for zero/null. ATTENTION: zero/null means `""` or `0`, but not `"0"` because this is a string!

  **Examples for a short menu**
  ```shell
  [ -z "${BRIDGESTRING}" ] && BRIDGESTRING="Bridge mode OFF!"

  if [ ! -z "$IINTERFACE" ] ; then
    VPN_STATUS="VPN is up"
  else
    VPN_STATUS=""
  fi
  ```

  **Examples for "0" is not `0`**
  If `CLEARNET_ONLY=0` then `if [ -z "$CLEARNET_ONLY" ]; then` will be `false`, but `if [ "$CLEARNET_ONLY" == "0" ]; then` will be true.


- Check exit code directly with e.g. 'if mycmd;', not indirectly with '$?' (for more information, see [Shellcheck #SC2181](https://github.com/koalaman/shellcheck/wiki/SC2181); this guideline is currently being implemented)

- In general, variable names should be short and in upper case. However, there are exceptions; if the complexity needs longer, self-explaining variable names, then they can also be in lower case.

  Variable with the same purpose (for example, CHECK_OS) should have the same name independently where they are used.

- Comment lines should explain what the code is doing. In the case of a menu, every menu entry has to have a description at the beginning (see example above). Comment lines are critical with functions:

  **Eplaining a function in a script file or in torbox.lib**
  ```shell
  # This function is used for check_fresh_install() as a trap for CTRL-C
  # Syntax finish_default_obfs4
  # Used predefined variables: DEFAULT_OBFS4_SUPPORT, RED, NOCOLOR, RUNFILE
  ```

- It has to be noted if the function expects predefined variables and also if the function returns something specific. The same is also essential with executable files:

  **Eplaining a executable file**
  ```shell
  # DESCRIPTION
  # This file does ......
  #
  # SYNTAX
  # nohup ./hostapd_fallback_komplex <interface 1> <interface 2>
  #
  # <interface 1>: Is the interface with the AP: wlan0 or wlan1.
  # <interface 2>: Is the interface with the connected cable client: eth0 or eth1
  #
  # IMPORTANT
  # There is no failsave configuration in this procedure, because it interfered
  # with the rest. The failsave is part of the rc.local script.
  ```

- The TorBox Library ([torbox.lib](https://github.com/radio24/TorBox/blob/master/lib/torbox.lib)) comprises only functions. Paths and configuration values are stored in the run-file ([torbox.run](https://github.com/radio24/TorBox/blob/master/run/torbox.run)).

- Make small, incremental commits that do one thing. Don't cram unrelated changes into a single commit.

- Use an editor that supports [EditorConfig](https://editorconfig.org/) (for example [Atom](https://atom.io)), and format source code according to [our settings](https://editorconfig.org/).

- Please test your code thoroughly before creating a pull-request! With shell scripts, it is recommended to use [shellcheck](https://github.com/koalaman/shellcheck). If your code is accepted into the distribution, a lot of people will try it out, so try to do a thorough job of eradicating all the bugs before you send it to us.

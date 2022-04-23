#!/usr/bin/env bash

# define color function
if [[ "$BASH_SOURCE" == "$0" ]]; then
    is_script=true
    set -eu -o pipefail
else
    is_script=false
fi
CLR_ESC="\033["

# All these variables has a function with the same name, but in lower case.
#
CLR_RESET=0             # reset all attributes to their defaults
CLR_RESET_UNDERLINE=24  # underline off
CLR_RESET_REVERSE=27    # reverse off
CLR_DEFAULT=39          # set underscore off, set default foreground color
CLR_DEFAULTB=49         # set default background color

CLR_BOLD=1              # set bold
CLR_BRIGHT=2            # set half-bright (simulated with color on a color display)
CLR_UNDERSCORE=4        # set underscore (simulated with color on a color display)
CLR_REVERSE=7           # set reverse video

CLR_BLACK=30            # set black foreground
CLR_RED=31              # set red foreground
CLR_GREEN=32            # set green foreground
CLR_BROWN=33            # set brown foreground
CLR_BLUE=34             # set blue foreground
CLR_MAGENTA=35          # set magenta foreground
CLR_CYAN=36             # set cyan foreground
CLR_WHITE=37            # set white foreground

CLR_BLACKB=40           # set black background
CLR_REDB=41             # set red background
CLR_GREENB=42           # set green background
CLR_BROWNB=43           # set brown background
CLR_BLUEB=44            # set blue background
CLR_MAGENTAB=45         # set magenta background
CLR_CYANB=46            # set cyan background
CLR_WHITEB=47           # set white background


# check if string exists as function
# usage: if fn_exists "sometext"; then ... fi
function fn_exists
{
    type -t "$1" | grep -q 'function'
}

# iterate through command arguments, o allow for iterative color application
function clr_layer
{
    # default echo setting
    CLR_ECHOSWITCHES="-e"
    CLR_STACK=""
    CLR_SWITCHES=""
    ARGS=("$@")

    # iterate over arguments in reverse
    for ((i=$#-1; i>=0; i--)); do
        ARG=${ARGS[$i]}
        # echo $ARG
        # set CLR_VAR as last argtype
        firstletter=${ARG:0:1}

        # check if argument is a switch
        if [ "$firstletter" = "-" ] ; then
            # if -n is passed, set switch for echo in clr_escape
            if [[ $ARG == *"n"* ]]; then
                CLR_ECHOSWITCHES="-en"
                CLR_SWITCHES=$ARG
            fi
        else
            # last arg is the incoming string
            if [ -z "$CLR_STACK" ]; then
                CLR_STACK=$ARG
            else
                # if the argument is function, apply it
                if [ -n "$ARG" ] && fn_exists $ARG; then
                    #continue to pass switches through recursion
                    CLR_STACK=$($ARG "$CLR_STACK" $CLR_SWITCHES)
                fi
            fi
        fi
    done

    # pass stack and color var to escape function
    clr_escape "$CLR_STACK" $1;
}

# General function to wrap string with escape sequence(s).
# Ex: clr_escape foobar $CLR_RED $CLR_BOLD
function clr_escape
{
    local result="$1"
    until [ -z "${2:-}" ]; do
	if ! [ $2 -ge 0 -a $2 -le 47 ] 2>/dev/null; then
	    echo "clr_escape: argument \"$2\" is out of range" >&2 && return 1
	fi
        result="${CLR_ESC}${2}m${result}${CLR_ESC}${CLR_RESET}m"
	shift || break
    done

    echo "$CLR_ECHOSWITCHES" "$result"
}

function clr_reset           { clr_layer $CLR_RESET "$@";           }
function clr_reset_underline { clr_layer $CLR_RESET_UNDERLINE "$@"; }
function clr_reset_reverse   { clr_layer $CLR_RESET_REVERSE "$@";   }
function clr_default         { clr_layer $CLR_DEFAULT "$@";         }
function clr_defaultb        { clr_layer $CLR_DEFAULTB "$@";        }
function clr_bold            { clr_layer $CLR_BOLD "$@";            }
function clr_bright          { clr_layer $CLR_BRIGHT "$@";          }
function clr_underscore      { clr_layer $CLR_UNDERSCORE "$@";      }
function clr_reverse         { clr_layer $CLR_REVERSE "$@";         }
function clr_black           { clr_layer $CLR_BLACK "$@";           }
function clr_red             { clr_layer $CLR_RED "$@";             }
function clr_green           { clr_layer $CLR_GREEN "$@";           }
function clr_brown           { clr_layer $CLR_BROWN "$@";           }
function clr_blue            { clr_layer $CLR_BLUE "$@";            }
function clr_magenta         { clr_layer $CLR_MAGENTA "$@";         }
function clr_cyan            { clr_layer $CLR_CYAN "$@";            }
function clr_white           { clr_layer $CLR_WHITE "$@";           }
function clr_blackb          { clr_layer $CLR_BLACKB "$@";          }
function clr_redb            { clr_layer $CLR_REDB "$@";            }
function clr_greenb          { clr_layer $CLR_GREENB "$@";          }
function clr_brownb          { clr_layer $CLR_BROWNB "$@";          }
function clr_blueb           { clr_layer $CLR_BLUEB "$@";           }
function clr_magentab        { clr_layer $CLR_MAGENTAB "$@";        }
function clr_cyanb           { clr_layer $CLR_CYANB "$@";           }
function clr_whiteb          { clr_layer $CLR_WHITEB "$@";          }

if [[ "$OSTYPE" != "darwin"* ]]; then
    clr_red "ERROR! Your OS is ${OSTYPE}. Only macOS supported!"    
    exit 1
fi

GO_PROXY_BIN=proxy-for-aws-client-vpn
PROFILE_NAME=aws-vpn

# find .ovpn path
function download_url() {
    url=$1
    default_download_dir=$HOME/Downloads
    if [ -z $1 ]; then 
        clr_red "download_url [URL] [TARGET_DIR]"
        return 1
    fi
    if [ -z $2 ];then
        clr_blue "Use default download directory: ${default_download_dir}"
        mkdir -p 
        download_dir=${default_download_dir}
    else
        download_dir=${2}
    fi

    if command -v curl &> /dev/null; then
        clr_blue "Downloading ..."
        curl -o ${download_dir}/${1##*/} --progress-bar -L $url
    elif [ command -v wget ]; then
        clr_blue "Downloading ..."
        wget -O ${download_dir}/${1##*/} $url
    else
        clr_red "Neither curl or wget command found, cannot download."
        return 1
    fi
}

function find_ovpn_config_path() {
    ls -t ~/Downloads/*.ovpn | head -1
}

function setup_client_vpn() {
    if grep ${PROFILE_NAME} $HOME/.config/AWSVPNClient/ConnectionProfiles > /dev/null; then
        echo; clr_bold clr_brown "Profile ${PROFILE_NAME} configured, skip. Want to re-configure it? Delete this profile from AWS Client VPN."
        return 0
    fi

    ## Prepare the .ovpn config
    file=$(find_ovpn_config_path)
    if [ -z $file ]; then
        clr_red "ERROR! Can't find .ovpn config file from $HOME/Downloads. Please download the VPN configuration following the AWS docs"
    fi
    aws_client_vpn_conf_dir="$HOME/.config/AWSVPNClient/OpenVpnConfigs"
    if [ ! -d ${aws_client_vpn_conf_dir} ]; then
        mkdir -p ${aws_client_vpn_conf_dir}
    fi
    target_path=${aws_client_vpn_conf_dir}/${PROFILE_NAME}
    clr_blue "$file found. Copying to ${target_path}"
    cp $file ${target_path}
    sed -i "" 's/^remote \(.*cvpn-endpoint.*\)/#remote \1/g' $target_path
    sed -i "" 's/remote-random-hostname/#remote-random-hostname/g' $target_path
    sed -i "" '/auth-federate/d' $target_path
    if ! grep "remote 127.0.0.1 33443" $target_path >/dev/null; then
        sed -i '' -e '/remote .*cvpn-endpoint.*/a\
remote 127.0.0.1 33443' $target_path
    fi

    ## Prepare the connectionProfiles config
    JQ_BIN=jq
    if ! command -v $JQ_BIN > /dev/null; then
        JQ_BIN=/tmp/jq
        if ! command -v $JQ_BIN > /dev/null; then
        clr_blue "jq command not found, download to ${JQ_BIN} for temporary usage"
        download_url \
            https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 \
            /tmp/
        mv /tmp/jq-osx-amd64 /tmp/jq && chmod +x /tmp/jq
        fi
    fi
    connection_profiles_path=$HOME/.config/AWSVPNClient/ConnectionProfiles
    cvpn_endpoint_id=$(cat ${target_path} | egrep -o 'cvpn-endpoint-[0-9a-zA-Z]+')
    if [ -f ${connection_profiles_path} ]; then 
        clr_blue "${connection_profiles_path} exist. Append new profile ${PROFILE_NAME}"
        # insert json
        # if ! grep ${PROFILE_NAME} ${connection_profiles_path} > /dev/null; then
        #     clr_blue "Delete old profile ${PROFILE_NAME}"
        #     cat <<< $(jq 'del(.ConnectionProfiles[] | select(.ProfileName == '${PROFILE_NAME}'))' \
        #         ${connection_profiles_path}) > ${connection_profiles_path}
        # fi

        # cat <<< $(jq '.ConnectionProfiles += [{
        #         "ProfileName": "'${PROFILE_NAME}'",
        #         "OvpnConfigFilePath": "'${target_path}'",
        #         "CvpnEndpointId": "'${cvpn_endpoint_id}'",
        #         "CvpnEndpointRegion": "ap-southeast-1",
        #         "CompatibilityVersion": "2",
        #         "FederatedAuthType": 1
        #     }]' ${connection_profiles_path}) > ${connection_profiles_path}
        jq '.ConnectionProfiles += [{
                "ProfileName": "'${PROFILE_NAME}'",
                "OvpnConfigFilePath": "'${target_path}'",
                "CvpnEndpointId": "'${cvpn_endpoint_id}'",
                "CvpnEndpointRegion": "ap-southeast-1",
                "CompatibilityVersion": "2",
                "FederatedAuthType": 1
            }]' ${connection_profiles_path} > ${connection_profiles_path}.tmp \
            && mv ${connection_profiles_path}.tmp ${connection_profiles_path}
    else
        clr_blue "${connection_profiles_path} not exist. Create"
        # create json
        echo '
        {
            "Version": "1",
            "LastSelectedProfileIndex": 0,
            "ConnectionProfiles": [
              {
                "ProfileName": "'${PROFILE_NAME}'",
                "OvpnConfigFilePath": "'${target_path}'",
                "CvpnEndpointId": "'${cvpn_endpoint_id}'",
                "CvpnEndpointRegion": "ap-southeast-1",
                "CompatibilityVersion": "2",
                "FederatedAuthType": 1
              },
        }' > ${connection_profiles_path}
    fi
}

function find_proxy_port() {
    ss_pid=$(ps aux | grep -i 'ss-local' | grep -v grep | awk '{print $2}')
    if [ -z $ss_pid ]; then
        clr_red "ERROR: Cannot find your shadwoscoks proxy(socks5 port), please check if your shadwoscoks started. Exit."
    fi
    socks5_port=$(netstat -anv -p tcp | grep $ss_pid | awk '{print $4}' | grep 127.0.0.1 | awk -F. '{print $NF}' | head -1)
    echo $socks5_port
}

function setup_goproxy() {
    if [ -e /usr/local/bin/${GO_PROXY_BIN} ]; then
        clr_blue "Detected goproxy installed. Skip."
        return 0
    fi
    clr_blue "Start install goproxy to /usr/local/bin/${GO_PROXY_BIN} ..."
    # download goproxy
    download_url \
        https://github.com/snail007/goproxy/releases/download/v11.7/proxy-darwin-amd64.tar.gz \
        /tmp/
    mkdir -p /tmp/goproxy
    tar xzf /tmp/proxy-darwin-amd64.tar.gz -C /tmp/goproxy 
    chmod +x /tmp/goproxy/proxy
    mv /tmp/goproxy/proxy /usr/local/bin/${GO_PROXY_BIN}
    clr_blue "/usr/local/bin/${GO_PROXY_BIN} installed."
    rm -rf /tmp/proxy*
}

function start_goproxy() {
    setup_goproxy
    proxy_port=$(find_proxy_port)
    ovpn_path=$(find_ovpn_config_path)
    cvpn_endpoint=$(grep cvpn-endpoint ${ovpn_path} | awk '{print $2}')
    if [ -z ${proxy_port} ]; then
        clr_red "Cannot find your shadouscoks proxy(socks5 port), please check if your shadwoscoks started. Exit."
        exit 1
    fi
    clr_bold clr_blue "Found socks5 proxy listening on port ${proxy_port}. Starting goproxy..."; echo
    clr_bold clr_brown "DONOT close the terminal window and keep it OPENING."; echo
    clr_bold clr_brown "Now open your AWS Client VPN, select profile ${PROFILE_NAME} and click Connect button."
    cmd="/usr/local/bin/${GO_PROXY_BIN} tcp -p :33443 -T tcp -P a.${cvpn_endpoint}:443 -J socks5://127.0.0.1:${proxy_port}"
    echo; clr_bold clr_green ">>> $cmd"; $cmd
}

function help() {
    clr_green "Usage:"; echo
    clr_green "  $0 configure"
    clr_green "  $0 start"
}

socks5_port=$(find_proxy_port)
export http_proxy=http://127.0.0.1:1080 
export https_proxy=http://127.0.0.1:1080
export no_proxy=10.0.0.0/8,127.0.0.0/8,localhost

setup_client_vpn
start_goproxy

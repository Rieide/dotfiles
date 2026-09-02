# Synchronize multiplexer zsh panes with GNOME's current system proxy.
# Set MULTIPLEXER_SYSTEM_PROXY_SYNC=0 in ~/.zshrc.local to opt out.

[[ -n "${TMUX:-}" || -n "${ZELLIJ:-}" ]] || return 0
[[ "${MULTIPLEXER_SYSTEM_PROXY_SYNC:-${TMUX_SYSTEM_PROXY_SYNC:-1}}" != 0 ]] || return 0
command -v gsettings >/dev/null 2>&1 || return 0

autoload -Uz add-zsh-hook

typeset -gi _MULTIPLEXER_SYSTEM_PROXY_LAST_SYNC=-1
typeset -gi _MULTIPLEXER_SYSTEM_PROXY_MANAGED=0

_multiplexer_system_proxy_unquote() {
  REPLY="${1#\'}"
  REPLY="${REPLY%\'}"
}

_multiplexer_system_proxy_clear() {
  unset http_proxy https_proxy all_proxy no_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
  _MULTIPLEXER_SYSTEM_PROXY_MANAGED=0
}

_multiplexer_system_proxy_sync() {
  emulate -L zsh

  # precmd and preexec normally run back-to-back. One lookup per second keeps
  # commands responsive while still noticing a reconnect before the next run.
  (( _MULTIPLEXER_SYSTEM_PROXY_LAST_SYNC == SECONDS )) && return 0

  local mode http_host http_port socks_host socks_port ignore_hosts
  local http_url all_url url_host

  mode="$(gsettings get org.gnome.system.proxy mode 2>/dev/null)" || return 0
  _MULTIPLEXER_SYSTEM_PROXY_LAST_SYNC=$SECONDS

  if [[ "$mode" == "'none'" ]]; then
    _multiplexer_system_proxy_clear
    return 0
  fi

  # PAC files cannot be represented by the standard shell proxy variables.
  # Clear values previously managed here, but preserve unrelated user values.
  if [[ "$mode" != "'manual'" ]]; then
    (( _MULTIPLEXER_SYSTEM_PROXY_MANAGED )) && _multiplexer_system_proxy_clear
    return 0
  fi

  http_host="$(gsettings get org.gnome.system.proxy.http host 2>/dev/null)" || return 0
  http_port="$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)" || return 0
  _multiplexer_system_proxy_unquote "$http_host"
  http_host="$REPLY"

  if [[ -z "$http_host" || "$http_host" == *[^A-Za-z0-9._:-]* || "$http_port" != <1-65535> ]]; then
    _multiplexer_system_proxy_clear
    return 0
  fi

  url_host="$http_host"
  [[ "$url_host" == *:* && "$url_host" != \[*\] ]] && url_host="[$url_host]"
  http_url="http://${url_host}:${http_port}"
  all_url="$http_url"

  socks_host="$(gsettings get org.gnome.system.proxy.socks host 2>/dev/null)" || socks_host=""
  socks_port="$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)" || socks_port=0
  _multiplexer_system_proxy_unquote "$socks_host"
  socks_host="$REPLY"
  if [[ -n "$socks_host" && "$socks_host" != *[^A-Za-z0-9._:-]* && "$socks_port" == <1-65535> ]]; then
    url_host="$socks_host"
    [[ "$url_host" == *:* && "$url_host" != \[*\] ]] && url_host="[$url_host]"
    all_url="socks5h://${url_host}:${socks_port}"
  fi

  export http_proxy="$http_url" https_proxy="$http_url" all_proxy="$all_url"
  export HTTP_PROXY="$http_url" HTTPS_PROXY="$http_url" ALL_PROXY="$all_url"
  _MULTIPLEXER_SYSTEM_PROXY_MANAGED=1

  ignore_hosts="$(gsettings get org.gnome.system.proxy ignore-hosts 2>/dev/null)" || ignore_hosts=""
  ignore_hosts="${ignore_hosts#\[}"
  ignore_hosts="${ignore_hosts%\]}"
  ignore_hosts="${ignore_hosts//\', \'/,}"
  ignore_hosts="${ignore_hosts//\'/}"
  if [[ -n "$ignore_hosts" && "$ignore_hosts" != *[^A-Za-z0-9.,:_\/*-]* ]]; then
    export no_proxy="$ignore_hosts" NO_PROXY="$ignore_hosts"
  else
    unset no_proxy NO_PROXY
  fi
}

add-zsh-hook precmd _multiplexer_system_proxy_sync
add-zsh-hook preexec _multiplexer_system_proxy_sync
_multiplexer_system_proxy_sync

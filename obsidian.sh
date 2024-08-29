# !/usr/bin/env bash

OP='CREATE'
for i in $@; do
  [[ $i == '-h' ]] && echo "
  统一管理Obsidian配置
  \x1b[31m向指定Obsidian项目（Valut）创建.obsidian目录的硬链接: \x1b[32m$(basename $0) <ObsidianVault>\x1b[0m
  \x1b[31m由\x1b[2menv.local\x1b[22m文件指定Obsidian项目（Valut），从项目中获取（如果有）新插件，并同步给所有项目: \x1b[32m$(basename $0)\x1b[0m" && exit 0;
  [[ $i == '-s' ]] && OP='SYNC'
done

SOURCE=$(dirname $0 | realpath)
SNIPPETS="$SOURCE/SNIPPETS"
THEMES="$SOURCE/THEMES"
PLUGINS="$SOURCE/PLUGINS"

function red() {
  echo "\x1b[31m$*\x1b[0m"
}
function green() {
  echo "\x1b[32m$*\x1b[0m"
}
function dim() {
  echo "\x1b[2m$*\x1b[22m"
}

CONFIRM=''

function confirm() {
  local message="$1"
  [[ "$CONFIRM" == 'N' ]] && return 1
  [[ "$CONFIRM" == 'A' ]] && return 0
  read -p $'\x1b[32m'"$message 是(Y)，全是(A)，全否(N):"$'\x1b[0m' -a CONFIRM
  [[ "$CONFIRM" == 'A' || "$CONFIRM" == 'Y' ]] && return 0
  return 1
}

function ensureFolder() {
  [[ ! -e "$1" ]] && mkdir -p "$1"
}

# 1: Source, 2: Target
function linkFolder() {
  local sourceFolder="$1"
  local targetFolder="$2"

  CONFIRM=''
  local OLD_IFS="$IFS"
  IFS=$'\n'
  for i in `ls -1 "$sourceFolder"`; do
    sourceFile="$sourceFolder/$i"
    targetFile="$targetFolder/$i"
    if [[ -d "$sourceFile" ]]; then
      [[ -e "$targetFile" && ! -d "$targetFile" ]] && red "源文件 $sourceFile 是目录，目标文件 $targetFile 已存在但不是目录，跳过执行。" && continue
      [[ ! -e "$targetFile" ]] && mkdir "$targetFile"
      linkFolder "$sourceFile" "$targetFile"
    elif [[ -f "$sourceFile" ]]; then
      linkFile "$sourceFile" "$targetFile"
    else
      red "跳过源文件 $sourceFile"
    fi
  done
  IFS="$OLD_IFS"
}

function linkFile() {
  local sourceFile="$1"
  local targetFile="$2"
  [[ "$sourceFile" -ef "$targetFile" ]] && dim "硬链接已存在: \x1b[4m$targetFile\x1b[24m" && return 0
  [[ -f "$targetFile" ]] && confirm "目标文件 $targetFile 已存在，是否删除？" && rm "$targetFile"
  echo "\x1b[32m创建 \x1b[4m$sourceFile\x1b[24m 的硬链接: \x1b[33;4;2m$targetFile \x1b[32m\x1b[0m"
  [[ ! -e "$targetFile" ]] && ln "$sourceFile" "$targetFile" && green '创建成功' || red '创建失败'
}

function createVaultHardLinks() {
  local dest=$(realpath "$1")
  local folder
  [[ -f $dest ]] && folder=$(dirname "$dest") || folder="$dest"

  while [[ -d "$folder" ]]; do
    local obsidian="$folder/.obsidian"
    if [[ -d "$obsidian" ]]; then
      local answer
      echo "Vault目录：\x1b[2m$folder\x1b[0m"
      read -p $'\x1b[31m是否继续(Y):\x1b[0m' -a answer;

      [[ $answer != 'Y' ]] && echo '退出' && return

      CONFIRM=''
      local OLD_IFS="$IFS"
      IFS=$'\n'
      for i in `ls -1 *.json`; do
        linkFile "$SOURCE/$i" "$obsidian/$i"
      done
      IFS="$OLD_IFS"

      # SNIPPETS
      local obsidianSnippets="$obsidian/SNIPPETS"
      ensureFolder "$obsidianSnippets"
      linkFolder "$SNIPPETS" "$obsidianSnippets"
      # THEMES
      local obsidianThemes="$obsidian/THEMES"
      ensureFolder "$obsidianThemes"
      linkFolder "$THEMES" "$obsidianThemes"
      # PLUGINS
      local obsidianPlugins="$obsidian/PLUGINS"
      ensureFolder "$obsidianPlugins"
      linkFolder "$PLUGINS" "$obsidianPlugins"

      return
    fi

    folder=$(dirname $folder)
  done
}

function syncVaults() {
  local OLD_IFS="$IFS"
  IFS=$'\n'
  local VAULTS=(`cat env.local`)
  IFS="$OLD_IFS"
  for i in "${VAULTS[@]}"; do
    local willPlugins="$i/.obsidian/plugins"
    local willPlugin
    for willPlugin in `ls "$willPlugins"`; do
      ls "$SOURCE/$willPlugin" 1>/dev/null 2>&1 && cp -R "$willPlugins/$willPlugin" "$PLUGINS"
    done
  done
  for i in "${VAULTS[@]}"; do
    createVaultHardLinks "$i"
  done
}

[[ $OP == 'CREATE' && $1 ]] && createVaultHardLinks "$1"
[[ $OP == 'SYNC' ]] && syncVaults

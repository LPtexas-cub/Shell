#!/bin/bash
#一键部署Hexo环境以及恢复Blog数据
####
#    使用步骤
#    1.cd切换至需要恢复到的目录下
#    2.准备好从github中下载的源码(.zip)，或者直接git clone(推荐)
#    3.准备脚本r.sh，赋予可执行权限，注意修改nodejs的版本
#    4.执行./r.sh start <指定压缩文件>，不指定时只配置基本环境
#    5.将远程仓库的私钥放置.ssh目录下，确保权限为600，且密钥能被识别。
#    6.执行./r.sh ri 修复npm module 以及对接远程仓库
####
blog="myblog"              #博客数据包解压后的文件夹名
currentPath=$PWD           #博客所在目录
dataFile='BlogSourceCode-main.zip' #可定义数据文件名
nodeVersion="v16.16.0"
####用于git配置
email=asucanyh@outlook.com
username=asucanyh-cn
remoteRepo=blog-source
####检查备份的数据文件名称
function checkFileName() {
  if [ $# -eq 2 ]; then
    echo "[Info]Checking filename..."
    if [ ${#2} -lt 3 ]; then
      echo "[Error]Please check your name of data file!"
      exit 17
    fi
    dataFile=$2
    if [ ${dataFile:0-3} == ".gz" -o ${dataFile:0-3} == "zip" ]; then
      if [ $# -eq 1 -a $1 == "start" ]; then
        echo -e "[Note]You are running without data file, you'd better specify it!"
      elif [ $# -eq 1 -a $1 == "restart" ]; then
        echo -e "[Note]You are running without data file, you'd better specify it!"
      fi
    else
      echo "[Error]Wrong type of compressed file. Please check your file name parameter!"
      exit 32
    fi
    echo "[Info]$dataFile passed."
  fi
}
function cleanFiles() {
  echo -e "[Info]Cleaning nodejs & $blog..."
  nohup rm -rf /usr/local/nodejs &>/dev/null
  nohup rm -rf $currentPath/$blog &>/dev/null
  sleep 1
}
function clean() {
  #清除所有无用的文件
  echo "Cleaning Starting..."
  if [ ! -e $currentPath/nodejs.tar.xz -a ! -e $currentPath/$dataFile ]; then
    echo "[Note]Files not exist."
  fi
  if [ -e $currentPath/nodejs.tar.xz -a -e $currentPath/$dataFile ]; then
    nohup rm -f $currentPath/nodejs.tar.xz &>/dev/null
    nohup rm -f $currentPath/$dataFile &>/dev/null
    echo -e "[Info]Compressed files was cleaned."
  fi
  if [ -e $currentPath/nodejs.tar.xz ]; then
    nohup rm -f $currentPath/nodejs.tar.xz &>/dev/null
    echo -e "[Info]nodejs.tar.xz was cleaned."
  fi
  if [ -e $currentPath/$dataFile ]; then
    nohup rm -f $currentPath/$dataFile &>/dev/null
    echo -e "[Info]$dataFile was cleaned."
  fi

}
function checkOS() {
  ####检查发行版本
  echo -e "[Note]Recovery starting..."
  OS=$(cat /etc/os-release | grep ^NAME=".*" | awk -F "\"" '{print $2}')
  if [ "$OS" == "CentOS Linux" -o "$OS" == "CentOS" ]; then
    pkgm="yum"
  elif [ "$OS" == "Ubuntu" ]; then
    pkgm="apt-get"
  fi
  echo [Info]Current release os: $OS. 
  nohup sudo $pkgm update -y --skip-broken &>/dev/null
  #####检查系统架构
  if [ "$(dpkg --print-architecture)" == "arm64" ]; then
    arch="arm64"
  else
    arch="x64"
  fi
  echo [Info]Current architecture: $arch.
}
#检查系统环境
#安装必要应用
#git,wget,nodejs,npm,hexo
function env() {
  ## 安装git
  nohup $pkgm install -y git &>/dev/null
  if [ "$?" -eq 0 ]; then
    echo -e "[Info]'git' installed successfully!"
  else
    echo -e "\n[Error]Please check 'git'\n"
    exit 19
  fi

  ## 安装wget
  nohup $pkgm install -y wget &>/dev/null
  if [ "$?" -eq 0 ]; then
    echo -e "[Info]'wget' installed successfully!"
  else
    echo -e "\n[Error]Please check 'wget'\n"
    exit 28
  fi
  ## 安装nodejs
  if [ ! -e "nodejs" -a ! -e "nodejs.tar.xz" ]; then
    nodeurl="https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-linux-$arch.tar.xz"
    wget $nodeurl -O nodejs.tar.xz
  fi
  if [ ! -e "nodejs" -a -e "nodejs.tar.xz" ]; then
    tar -xf $currentPath/nodejs.tar.xz
    mv $(find $currentPath -name node-v[0-9]*) $currentPath/nodejs
  fi
  # 重新创建nodejs软链接
  ###
  rm -rf /usr/local/nodejs
  mv $currentPath/nodejs /usr/local
  ###
  rm -f /usr/local/bin/node
  ln -s /usr/local/nodejs/bin/node /usr/local/bin/node
  rm -f /usr/local/bin/npm
  ln -s /usr/local/nodejs/bin/npm /usr/local/bin/npm
  if [ "$?" -eq 0 ]; then
    nohup node -v &>/dev/null
  fi
  if [ "$?" == 0 ]; then
    echo -e "[Info]'nodejs' installed successfully!"
  else
    echo -e "\n[Error]Please check 'nodejs'\n"
    exit 44
  fi
  ## 安装npm
  if [ "$?" -eq 0 ]; then
    nohup npm -v &>/dev/null
  fi
  if [ "$?" == 0 ]; then
    echo -e "[Info]'npm' installed successfully!"
  else
    echo -e "\n[Error]Please check 'npm'\n"
    exit 57
  fi
  ## 安装Hexo
  nohup hexo &>/dev/null
  if [ "$?" -ne 0 ]; then
    nohup npm install --location=global hexo-cli &>/dev/null
  fi
  ### 链接hexo命令至环境变量中
  rm -f /usr/local/bin/hexo
  ln -s /usr/local/nodejs/lib/node_modules/hexo-cli/bin/hexo /usr/local/bin/hexo
}
#备份数据包解压缩
## 解压数据包 并修改文件夹为$blog
function unzip() {
  if [ $# -eq 1 ]; then
    echo -e "[Note]Please specify the datafile."
    exit 25
  fi
  echo -e "[Note]Decompressing $2..."
  if [ ! -d "$currentPath/$blog" ]; then
    if [ "${dataFile:0-3}" == ".gz" ]; then
      tar -xf $currentPath/$dataFile
      if [ $? -eq 0 ]; then
        mv $currentPath/${dataFile%*.tar.gz} $currentPath/$blog
      fi
    elif [ ${dataFile:0-3} == "zip" ]; then
      nohup $pkgm install zip -y &>/dev/null
      nohup unzip $currentPath/$dataFile &>/dev/null
      if [ $? -eq 0 ]; then
        mv $currentPath/${dataFile%*.zip} $currentPath/$blog
      fi
    fi
  fi
  if [ -d $currentPath/$blog ]; then
    echo -e "[Info]Unpack done."
    echo -e "[Info]Now,you can switch to '$blog' and use 'hexo server' to preview your site!\n[Note]Done"
  else
    if [ "$1" == "start" -a ! "$#" -eq 1 ]; then
      echo -e "\n[Error]Please check 'tar -xf $dataFile or 'unzip $dataFile.'\n"
      exit 80
    elif [ "$1" == "restart" -a ! "$#" -eq 1 ]; then
      echo -e "\n[Error]Please check 'tar -xf $dataFile or 'unzip $dataFile.'\n"
      exit 80
    fi
  fi
}
# 配置Git的默认设置
function gitConfig() {
  git config --global user.email "$email"
  git config --global user.name "$username"
  git config --global credential.helper store
  git config --global http.sslVerify false
  git config --global init.defaultBranch main
}

# 修复NPM遇到的错误
function repairNPM() {
  cd $blog
  echo -e "[Info]Repairing the errors, it may take a long time, please be patient!"
  rm -rf node_modules && nohup npm install --force &>/dev/null
  rm -rf .deploy_git/
  # git config --global core.autocrlf false
  cd ../
  echo -e "[Info]Errors repaired."
}
# 初始化Git
function initGit() {
  cd $blog
  git init
  git add .
  git remote add origin https://github.com/$username/$remoteRepo.git
  git remote update
  git checkout main
  cd ../
}

##main
checkFileName $1 $2
case $1 in
"start")
  checkOS
  env
  gitConfig
  unzip $1 $2
  ;;
"env")
  checkOS
  env
  ;;
"restart")
  checkOS
  cleanFiles
  env
  gitConfig
  unzip $1 $2
  ;;
"unzip")
  unzip
  ;;
"repair")
  repairNPM
  ;;
"init")
  initGit
  ;;
  "ri")
  repairNPM
  initGit
  ;;
"clean")
  clean
  ;;
"help")
  echo -e "Usage: <Command> [OPTION] [FILE]"
  echo -e "    env:     Only install the necessary utils."
  echo -e "    repair:  Repair npm module errors."
  echo -e "    init:    Link the remote reposity with local reposity."
  echo -e "    ri:      Repair and init."
  echo -e "    unzip:   Only unpack the datafile."
  echo -e "    clean:   Clean the necessary files."
  echo -e "    start:   Start recovery nomarlly."
  echo -e "    restart: Reinstall nodejs and re-unzip your blog.\n"
  ;;
*)
  echo "[!] invalid input"
  echo "[Note]Use option: 'start' to begin recovery."
  echo "[Note]Try 'help' for more information."
  ;;
esac

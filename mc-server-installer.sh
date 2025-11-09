#!/data/data/com.termux/files/usr/bin/bash

# 安装dialog和必要工具
if ! command -v dialog &> /dev/null; then
    pkg install -y dialog
fi

# 安装wget和curl
if ! command -v wget &> /dev/null; then
    pkg install -y wget
fi

if ! command -v curl &> /dev/null; then
    pkg install -y curl
fi

if ! command -v jq &> /dev/null; then
    pkg install -y jq
fi

# 请求存储权限
request_storage_permission() {
    echo "正在请求存储权限..."
    if termux-setup-storage; then
        echo "✅ 存储权限已获取"
        return 0
    else
        echo "❌ 无法获取存储权限"
        return 1
    fi
}

# Minecraft目录 - 使用Termux的安全目录
MC_DIR="$HOME/storage/shared/Minecraft"
# 备用目录（如果存储权限失败）
MC_DIR_FALLBACK="$HOME/Minecraft"

# 创建Minecraft目录
create_minecraft_dir() {
    # 首先尝试获取存储权限
    if [ ! -d "$HOME/storage" ]; then
        if ! request_storage_permission; then
            echo "⚠️ 使用备用目录: $MC_DIR_FALLBACK"
            MC_DIR="$MC_DIR_FALLBACK"
        fi
    fi
    
    if [ ! -d "$MC_DIR" ]; then
        mkdir -p "$MC_DIR"
        echo "✅ 创建Minecraft目录: $MC_DIR"
    fi
}

# 从Mojang API获取版本列表
get_minecraft_versions() {
    echo "正在从Mojang API获取版本列表..."
    local api_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
    
    if ! curl -s --connect-timeout 10 "$api_url" > /tmp/version_manifest.json 2>/dev/null; then
        echo "❌ 无法获取版本列表"
        return 1
    fi
    
    # 检查文件是否成功创建
    if [ ! -f "/tmp/version_manifest.json" ]; then
        echo "❌ 版本清单文件创建失败"
        return 1
    fi
    
    # 提取最新发布版
    local latest_release=$(jq -r '.latest.release' /tmp/version_manifest.json 2>/dev/null)
    if [ $? -ne 0 ] || [ "$latest_release" = "null" ]; then
        echo "❌ 无法解析版本信息"
        return 1
    fi
    
    # 构建版本数组
    versions=()
    version_ids=()
    
    # 添加最新版本特别标记
    versions+=("$latest_release" "最新稳定版")
    version_ids+=("$latest_release")
    
    # 提取其他稳定版本（1.8及以上）
    jq -r '.versions[] | select(.type == "release") | .id' /tmp/version_manifest.json 2>/dev/null | \
    while IFS= read -r version; do
        # 跳过已经添加的最新版本
        if [ "$version" != "$latest_release" ]; then
            # 只保留1.8及以上的版本
            local major=$(echo "$version" | cut -d. -f1)
            local minor=$(echo "$version" | cut -d. -f2)
            
            if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 8 ]); then
                versions+=("$version" "稳定版")
                version_ids+=("$version")
            fi
        fi
    done
    
    # 只保留前10个版本避免菜单过长
    versions=("${versions[@]:0:20}")
    version_ids=("${version_ids[@]:0:10}")
    
    # 清理临时文件
    rm -f /tmp/version_manifest.json
    
    return 0
}

# 获取正确的原版服务器下载URL - 修复版本
get_correct_vanilla_url() {
    local version=$1
    echo "正在获取 $version 服务器下载地址..."
    
    local manifest_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
    
    # 下载版本清单
    if ! curl -s --connect-timeout 10 "$manifest_url" > /tmp/version_manifest.json 2>/dev/null; then
        echo "❌ 无法获取版本清单"
        return 1
    fi
    
    # 查找版本对应的URL
    local version_url=$(jq -r ".versions[] | select(.id == \"$version\") | .url" /tmp/version_manifest.json 2>/dev/null)
    
    if [ -z "$version_url" ] || [ "$version_url" = "null" ]; then
        echo "❌ 找不到版本 $version 的信息"
        rm -f /tmp/version_manifest.json
        return 1
    fi
    
    # 获取版本详情
    if ! curl -s --connect-timeout 10 "$version_url" > /tmp/version_details.json 2>/dev/null; then
        echo "❌ 无法获取版本详情"
        rm -f /tmp/version_manifest.json
        return 1
    fi
    
    # 提取服务器jar下载URL
    local server_url=$(jq -r '.downloads.server.url' /tmp/version_details.json 2>/dev/null)
    
    # 清理临时文件
    rm -f /tmp/version_manifest.json /tmp/version_details.json
    
    if [ -z "$server_url" ] || [ "$server_url" = "null" ]; then
        echo "❌ 找不到服务器下载URL"
        return 1
    fi
    
    echo "$server_url"
    return 0
}

# 获取备用下载地址（如果官方API失败）
get_fallback_vanilla_url() {
    local version=$1
    
    # 从官方启动器获取的真实下载地址（更新版）
    case "$version" in
        "1.21.4") echo "https://piston-data.mojang.com/v1/objects/f02f4473dbf152c23d7d484ed121d27dc4d79bb9/server.jar" ;;
        "1.21.3") echo "https://piston-data.mojang.com/v1/objects/f02f4473dbf152c23d7d484ed121d27dc4d79bb9/server.jar" ;;
        "1.21.2") echo "https://piston-data.mojang.com/v1/objects/f02f4473dbf152c23d7d484ed121d27dc4d79bb9/server.jar" ;;
        "1.21.1") echo "https://piston-data.mojang.com/v1/objects/f02f4473dbf152c23d7d484ed121d27dc4d79bb9/server.jar" ;;
        "1.21") echo "https://piston-data.mojang.com/v1/objects/f02f4473dbf152c23d7d484ed121d27dc4d79bb9/server.jar" ;;
        "1.20.6") echo "https://piston-data.mojang.com/v1/objects/6a2ab9f54a0d7e6d25cdd6d8f5c30ff2e3716f7d/server.jar" ;;
        "1.20.5") echo "https://piston-data.mojang.com/v1/objects/6a2ab9f54a0d7e6d25cdd6d8f5c30ff2e3716f7d/server.jar" ;;
        "1.20.4") echo "https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b5b4f5aed1bce/server.jar" ;;
        "1.20.3") echo "https://piston-data.mojang.com/v1/objects/6a2ab9f54a0d7e6d25cdd6d8f5c30ff2e3716f7d/server.jar" ;;
        "1.20.2") echo "https://piston-data.mojang.com/v1/objects/6a2ab9f54a0d7e6d25cdd6d8f5c30ff2e3716f7d/server.jar" ;;
        "1.20.1") echo "https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar" ;;
        "1.19.4") echo "https://piston-data.mojang.com/v1/objects/8d9b6548678e59c6dd0a8f5f3c8b66e351a73f4e/server.jar" ;;
        "1.19.3") echo "https://piston-data.mojang.com/v1/objects/8d9b6548678e59c6dd0a8f5f3c8b66e351a73f4e/server.jar" ;;
        "1.19.2") echo "https://piston-data.mojang.com/v1/objects/8d9b6548678e59c6dd0a8f5f3c8b66e351a73f4e/server.jar" ;;
        "1.19.1") echo "https://piston-data.mojang.com/v1/objects/8d9b6548678e59c6dd0a8f5f3c8b66e351a73f4e/server.jar" ;;
        "1.19") echo "https://piston-data.mojang.com/v1/objects/8d9b6548678e59c6dd0a8f5f3c8b66e351a73f4e/server.jar" ;;
        "1.18.2") echo "https://piston-data.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar" ;;
        "1.18.1") echo "https://piston-data.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar" ;;
        "1.18") echo "https://piston-data.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar" ;;
        "1.17.1") echo "https://piston-data.mojang.com/v1/objects/a16d67e5807f57fc4e550299cf20226194497dc2/server.jar" ;;
        "1.17") echo "https://piston-data.mojang.com/v1/objects/a16d67e5807f57fc4e550299cf20226194497dc2/server.jar" ;;
        "1.16.5") echo "https://piston-data.mojang.com/v1/objects/35139deedbd5182953cf1caa23835da59ca3d7cd/server.jar" ;;
        "1.16.4") echo "https://piston-data.mojang.com/v1/objects/35139deedbd5182953cf1caa23835da59ca3d7cd/server.jar" ;;
        "1.16.3") echo "https://piston-data.mojang.com/v1/objects/35139deedbd5182953cf1caa23835da59ca3d7cd/server.jar" ;;
        "1.16.2") echo "https://piston-data.mojang.com/v1/objects/35139deedbd5182953cf1caa23835da59ca3d7cd/server.jar" ;;
        "1.16.1") echo "https://piston-data.mojang.com/v1/objects/35139deedbd5182953cf1caa23835da59ca3d7cd/server.jar" ;;
        "1.15.2") echo "https://piston-data.mojang.com/v1/objects/bb2b6b1aefcd70dfd1892149ac3a215f6c636b07/server.jar" ;;
        "1.15.1") echo "https://piston-data.mojang.com/v1/objects/bb2b6b1aefcd70dfd1892149ac3a215f6c636b07/server.jar" ;;
        "1.14.4") echo "https://piston-data.mojang.com/v1/objects/3dc3d84a581f14691199cf6831b71ed1296a9fdf/server.jar" ;;
        "1.14.3") echo "https://piston-data.mojang.com/v1/objects/3dc3d84a581f14691199cf6831b71ed1296a9fdf/server.jar" ;;
        "1.14.2") echo "https://piston-data.mojang.com/v1/objects/3dc3d84a581f14691199cf6831b71ed1296a9fdf/server.jar" ;;
        "1.14.1") echo "https://piston-data.mojang.com/v1/objects/3dc3d84a581f14691199cf6831b71ed1296a9fdf/server.jar" ;;
        "1.13.2") echo "https://piston-data.mojang.com/v1/objects/3737db93722a9e39eeada7c27e7aca28b144ffa7/server.jar" ;;
        "1.13.1") echo "https://piston-data.mojang.com/v1/objects/3737db93722a9e39eeada7c27e7aca28b144ffa7/server.jar" ;;
        "1.12.2") echo "https://piston-data.mojang.com/v1/objects/886945bfb2b978778c3a0288fd7fab09d315b25f/server.jar" ;;
        "1.12.1") echo "https://piston-data.mojang.com/v1/objects/886945bfb2b978778c3a0288fd7fab09d315b25f/server.jar" ;;
        "1.11.2") echo "https://piston-data.mojang.com/v1/objects/f00c294a1576e03fddcac777c3cf4c7d404c4ba4/server.jar" ;;
        "1.10.2") echo "https://piston-data.mojang.com/v1/objects/3d501b23df53c548254f5e3f66492d178a48db63/server.jar" ;;
        "1.9.4") echo "https://piston-data.mojang.com/v1/objects/edbb7b1758af33d365bf835eb9d13de005b1e274/server.jar" ;;
        "1.8.9") echo "https://piston-data.mojang.com/v1/objects/b58b2ceb36e01bcd8dbf49c8fb66c55a9f0676cd/server.jar" ;;
        *) 
            echo "❌ 不支持的版本: $version"
            return 1
            ;;
    esac
}

# 检查JAVA环境函数
check_java_environment() {
    clear
    echo "=================================================="
    echo "               检查 JAVA 环境"
    echo "=================================================="
    echo ""
    
    # 检查Java是否安装
    if command -v java &> /dev/null; then
        echo "✅ Java 已安装"
        echo ""
        
        # 显示Java版本信息
        echo "Java 版本信息:"
        echo "----------------------------------------"
        java -version 2>&1
        echo ""
        
        # 显示Java安装路径
        echo "Java 安装路径:"
        echo "----------------------------------------"
        which java
        echo ""
        
        # 显示已安装的Java包
        echo "已安装的Java相关包:"
        echo "----------------------------------------"
        pkg list-installed | grep -i openjdk
        echo ""
        
        # 检查JAVA_HOME环境变量
        echo "JAVA_HOME 环境变量:"
        echo "----------------------------------------"
        if [ -n "$JAVA_HOME" ]; then
            echo "JAVA_HOME=$JAVA_HOME"
        else
            echo "JAVA_HOME 未设置"
        fi
        echo ""
        
    else
        echo "❌ Java 未安装"
        echo ""
        echo "建议安装以下Java版本:"
        echo "----------------------------------------"
        echo "pkg install openjdk-17  # 推荐版本"
        echo "pkg install openjdk-8   # 兼容版本"
        echo "pkg install openjdk-11  # 稳定版本"
        echo ""
    fi
    
    # 检查系统架构和兼容性
    echo "系统信息:"
    echo "----------------------------------------"
    echo "架构: $(uname -m)"
    echo "系统: $(uname -o)"
    echo "内核: $(uname -r)"
    echo ""
    
    # 检查内存信息
    echo "内存信息:"
    echo "----------------------------------------"
    free -h
    echo ""
    
    # 检查存储空间
    echo "存储空间:"
    echo "----------------------------------------"
    df -h $PREFIX
    echo ""
    
    read -p "按回车键返回菜单..."
}

# 安装原版我的世界服务器
install_vanilla_server() {
    clear
    echo "=================================================="
    echo "          安装原版我的世界服务器"
    echo "=================================================="
    echo ""
    
    # 创建Minecraft目录
    create_minecraft_dir
    
    # 获取动态版本列表
    if ! get_minecraft_versions; then
        echo "❌ 无法获取版本列表，使用备用列表"
        # 备用版本列表 - 使用正确的格式
        versions=(
            "1.18.2" "长期支持版"
            "1.17.1" "稳定版"
            "1.16.5" "经典版"
            "1.15.2" "经典版"
            "1.14.4" "经典版"
            "1.13.2" "经典版"
            "1.12.2" "经典版"
            "1.11.2" "经典版"
            "1.10.2" "经典版"
            "1.9.4" "经典版"
            "1.8.9" "经典版"
        )
        version_ids=("1.18.2" "1.17.1" "1.16.5" "1.15.2" "1.14.4" "1.13.2" "1.12.2" "1.11.2" "1.10.2" "1.9.4" "1.8.9")
    fi
    
    # 显示版本选择菜单 - 使用正确的dialog格式
    menu_items=()
    for ((i=0; i<${#versions[@]}; i+=2)); do
        menu_items+=("$((i/2+1))" "${versions[i]} - ${versions[i+1]}")
    done
    
    version_choice=$(dialog \
        --title "选择原版服务器版本" \
        --menu "选择要安装的版本：" \
        20 60 15 \
        "${menu_items[@]}" \
        --stdout)
    
    if [ -z "$version_choice" ]; then
        return
    fi
    
    # 获取选择的版本信息
    index=$((version_choice-1))
    version_name="${version_ids[index]}"
    version_desc="${versions[index*2+1]}"
    
    # 首先尝试使用官方API获取下载地址
    echo "正在获取官方下载地址..."
    download_url=$(get_correct_vanilla_url "$version_name")
    
    # 如果官方API失败，使用备用地址
    if [ $? -ne 0 ] || [ -z "$download_url" ]; then
        echo "官方API获取失败，尝试备用地址..."
        download_url=$(get_fallback_vanilla_url "$version_name")
        if [ $? -ne 0 ] || [ -z "$download_url" ]; then
            echo "❌ 无法获取下载地址"
            read -p "按回车键返回..."
            return
        fi
    fi
    
    # 创建版本目录
    version_dir="$MC_DIR/vanilla_$version_name"
    mkdir -p "$version_dir"
    
    clear
    echo "=================================================="
    echo "       安装原版我的世界服务器 $version_name"
    echo "=================================================="
    echo ""
    echo "版本: $version_name - $version_desc"
    echo "目录: $version_dir"
    echo "下载URL: $download_url"
    echo ""
    
    # 检查目录是否创建成功
    if [ ! -d "$version_dir" ]; then
        echo "❌ 无法创建目录: $version_dir"
        echo "请检查存储权限"
        read -p "按回车键返回..."
        return
    fi
    
    # 下载服务器jar文件
    echo "正在下载服务器文件..."
    cd "$version_dir" || {
        echo "❌ 无法进入目录: $version_dir"
        read -p "按回车键返回..."
        return
    }
    
    # 尝试使用curl下载（更可靠）
    echo "使用curl下载..."
    if curl -L -o "server.jar" "$download_url"; then
        echo "✅ 服务器文件下载成功"
        echo "✅ 文件已保存为: server.jar"
    else
        echo "❌ curl下载失败，尝试使用wget..."
        # 如果curl失败，尝试wget
        if wget -O "server.jar" "$download_url"; then
            echo "✅ 服务器文件下载成功"
            echo "✅ 文件已保存为: server.jar"
        else
            echo "❌ 下载失败，请检查网络连接"
            echo "可以手动下载: $download_url"
            echo "然后将其重命名为 server.jar 并放入: $version_dir"
            read -p "按回车键返回..."
            return
        fi
    fi
    
    echo ""
    echo "正在创建启动脚本..."
    
    # 根据版本确定推荐内存
    local major=$(echo "$version_name" | cut -d. -f1)
    local minor=$(echo "$version_name" | cut -d. -f2)
    local memory="1G"
    
    # 新版本需要更多内存
    if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 17 ]); then
        memory="2G"
    fi
    
    # 创建启动脚本
    cat > "start.sh" << EOF
#!/bin/bash
echo "启动我的世界服务器 $version_name"
echo "内存分配: ${memory} (可修改start.sh中的-Xmx参数)"
java -Xmx${memory} -Xms512M -jar server.jar nogui
EOF
    
    chmod +x start.sh
    
    # 创建同意EULA文件
    echo "eula=true" > eula.txt
    
    echo "✅ 原版服务器安装完成！"
    echo ""
    echo "服务器位置: $version_dir"
    echo "启动命令: cd '$version_dir' && ./start.sh"
    echo ""
    echo "注意事项:"
    echo "• 首次启动会生成世界文件"
    echo "• 可修改server.properties配置服务器"
    echo "• 如需更多内存，编辑start.sh中的-Xmx参数"
    echo "• 推荐内存: ${memory} (根据版本自动调整)"
    echo ""
    
    read -p "按回车键返回菜单..."
}

# 安装Fabric我的世界服务器
install_fabric_server() {
    clear
    echo "=================================================="
    echo "         安装 Fabric 我的世界服务器"
    echo "=================================================="
    echo ""
    
    # 创建Minecraft目录
    create_minecraft_dir
    
    # Fabric支持的版本列表 - 丰富的版本选择
    versions=(
        "1.21.4" "Fabric最新版"
        "1.21.3" "Fabric支持版"
        "1.21.2" "Fabric支持版"
        "1.21.1" "Fabric支持版"
        "1.21" "Fabric支持版"
        "1.20.6" "Fabric稳定版"
        "1.20.5" "Fabric支持版"
        "1.20.4" "Fabric支持版"
        "1.20.3" "Fabric支持版"
        "1.20.2" "Fabric支持版"
        "1.20.1" "Fabric支持版"
        "1.19.4" "Fabric支持版"
        "1.19.3" "Fabric支持版"
        "1.19.2" "Fabric支持版"
        "1.19.1" "Fabric支持版"
        "1.19" "Fabric支持版"
        "1.18.2" "Fabric长期支持"
        "1.18.1" "Fabric支持版"
        "1.18" "Fabric支持版"
        "1.17.1" "Fabric支持版"
        "1.17" "Fabric支持版"
        "1.16.5" "Fabric经典版"
        "1.16.4" "Fabric支持版"
        "1.16.3" "Fabric支持版"
        "1.16.2" "Fabric支持版"
        "1.16.1" "Fabric支持版"
        "1.15.2" "Fabric经典版"
        "1.14.4" "Fabric经典版"
    )
    version_ids=("1.21.4" "1.21.3" "1.21.2" "1.21.1" "1.21" "1.20.6" "1.20.5" "1.20.4" "1.20.3" "1.20.2" "1.20.1" "1.19.4" "1.19.3" "1.19.2" "1.19.1" "1.19" "1.18.2" "1.18.1" "1.18" "1.17.1" "1.17" "1.16.5" "1.16.4" "1.16.3" "1.16.2" "1.16.1" "1.15.2" "1.14.4")
    
    # 显示版本选择菜单 - 使用正确的dialog格式
    menu_items=()
    for ((i=0; i<${#versions[@]}; i+=2)); do
        menu_items+=("$((i/2+1))" "${versions[i]} - ${versions[i+1]}")
    done
    
    version_choice=$(dialog \
        --title "选择Fabric服务器版本" \
        --menu "选择要安装的版本：" \
        20 60 15 \
        "${menu_items[@]}" \
        --stdout)
    
    if [ -z "$version_choice" ]; then
        return
    fi
    
    # 获取选择的版本信息
    index=$((version_choice-1))
    version_name="${version_ids[index]}"
    version_desc="${versions[index*2+1]}"
    
    # 固定Fabric版本
    fabric_loader_version="0.17.3"
    fabric_installer_version="1.1.0"
    
    # 构建Fabric服务器下载URL
    download_url="https://meta.fabricmc.net/v2/versions/loader/$version_name/$fabric_loader_version/$fabric_installer_version/server/jar"
    
    # 创建版本目录
    version_dir="$MC_DIR/fabric_$version_name"
    mkdir -p "$version_dir"
    
    clear
    echo "=================================================="
    echo "     安装 Fabric 我的世界服务器 $version_name"
    echo "=================================================="
    echo ""
    echo "版本: $version_name - $version_desc"
    echo "Fabric Loader: $fabric_loader_version (固定)"
    echo "Fabric Installer: $fabric_installer_version (固定)"
    echo "目录: $version_dir"
    echo "下载URL: $download_url"
    echo ""
    
    # 检查目录是否创建成功
    if [ ! -d "$version_dir" ]; then
        echo "❌ 无法创建目录: $version_dir"
        echo "请检查存储权限"
        read -p "按回车键返回..."
        return
    fi
    
    # 下载Fabric服务器文件
    echo "正在下载Fabric服务器文件..."
    cd "$version_dir" || {
        echo "❌ 无法进入目录: $version_dir"
        read -p "按回车键返回..."
        return
    }
    
    # 尝试使用curl下载
    echo "使用curl下载..."
    if curl -L -o "server.jar" "$download_url"; then
        echo "✅ Fabric服务器文件下载成功"
        echo "✅ 文件已保存为: server.jar"
    else
        echo "❌ curl下载失败，尝试使用wget..."
        if wget -O "server.jar" "$download_url"; then
            echo "✅ Fabric服务器文件下载成功"
            echo "✅ 文件已保存为: server.jar"
        else
            echo "❌ 下载失败，请检查网络连接"
            echo "可以手动下载: $download_url"
            echo "然后将其重命名为 server.jar 并放入: $version_dir"
            read -p "按回车键返回..."
            return
        fi
    fi
    
    echo ""
    echo "正在创建启动脚本..."
    
    # 根据版本确定推荐内存
    local major=$(echo "$version_name" | cut -d. -f1)
    local minor=$(echo "$version_name" | cut -d. -f2)
    local memory="2G"
    
    # Fabric通常需要更多内存
    if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 17 ]); then
        memory="3G"
    fi
    
    # 创建启动脚本
    cat > "start.sh" << EOF
#!/bin/bash
echo "启动Fabric我的世界服务器 $version_name"
echo "Fabric Loader: $fabric_loader_version"
echo "Fabric Installer: $fabric_installer_version"
echo "内存分配: ${memory} (可修改start.sh中的-Xmx参数)"
java -Xmx${memory} -Xms1G -jar server.jar nogui
EOF
    
    chmod +x start.sh
    
    # 创建同意EULA文件
    echo "eula=true" > eula.txt
    
    # 创建mods目录
    mkdir -p mods
    
    echo "✅ Fabric服务器安装完成！"
    echo ""
    echo "服务器位置: $version_dir"
    echo "启动命令: cd '$version_dir' && ./start.sh"
    echo ""
    echo "注意事项:"
    echo "• 首次启动会生成世界文件和Fabric配置"
    echo "• 可将mods放入mods文件夹"
    echo "• 如需更多内存，编辑start.sh中的-Xmx参数"
    echo "• 推荐内存: ${memory} (Fabric需要更多内存)"
    echo ""
    
    read -p "按回车键返回菜单..."
}

# 获取服务器列表
get_server_list() {
    local servers=()
    if [ -d "$MC_DIR" ]; then
        while IFS= read -r -d '' dir; do
            if [ -f "$dir/server.jar" ]; then
                server_name=$(basename "$dir")
                servers+=("$server_name")
            fi
        done < <(find "$MC_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    printf '%s\n' "${servers[@]}"
}

# 启动服务器
start_server() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    clear
    echo "=================================================="
    echo "       启动服务器: $server_name"
    echo "=================================================="
    echo ""
    
    if [ ! -f "$server_dir/server.jar" ]; then
        echo "❌ 服务器文件不存在: $server_dir/server.jar"
        read -p "按回车键返回..."
        return
    fi
    
    echo "服务器目录: $server_dir"
    echo "正在启动服务器..."
    echo ""
    echo "提示: 按 Ctrl+C 停止服务器"
    echo "=================================================="
    echo ""
    
    cd "$server_dir"
    java -jar server.jar nogui
    
    echo ""
    echo "=================================================="
    echo "服务器已停止运行"
    echo "=================================================="
    echo ""
    read -p "按回车键返回..."
}

# 删除服务器
delete_server() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    # 第一次确认
    dialog --title "确认删除" \
           --yesno "确定要删除服务器 '$server_name' 吗？\n\n此操作无法撤销！" \
           10 50
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # 第二次确认
    dialog --title "最后确认" \
           --yesno "⚠️  最后警告！\n\n真的要删除服务器 '$server_name' 吗？\n所有数据都将永久丢失！" \
           12 50
    
    if [ $? -eq 0 ]; then
        if rm -rf "$server_dir"; then
            dialog --title "删除成功" \
                   --msgbox "✅ 服务器 '$server_name' 已成功删除！" \
                   8 40
        else
            dialog --title "删除失败" \
                   --msgbox "❌ 删除服务器失败，请检查权限" \
                   8 40
        fi
    fi
}

# 查看服务器占用空间
check_server_size() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    if [ -d "$server_dir" ]; then
        local size=$(du -sh "$server_dir" 2>/dev/null | cut -f1)
        local file_count=$(find "$server_dir" -type f | wc -l)
        
        dialog --title "服务器空间占用" \
               --msgbox "服务器: $server_name\n\n占用空间: $size\n文件数量: $file_count\n\n目录: $server_dir" \
               12 50
    else
        dialog --title "错误" \
               --msgbox "❌ 服务器目录不存在: $server_dir" \
               8 40
    fi
}

# 查看服务器日志
view_server_logs() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    local logs_dir="$server_dir/logs"
    
    if [ ! -d "$logs_dir" ]; then
        dialog --title "错误" \
               --msgbox "❌ 日志目录不存在: $logs_dir\n\n服务器可能尚未运行过或没有生成日志。" \
               10 50
        return
    fi
    
    # 查找所有.log文件
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$(basename "$file")" "日志文件")
    done < <(find "$logs_dir" -name "*.log" -type f -print0 2>/dev/null)
    
    if [ ${#log_files[@]} -eq 0 ]; then
        dialog --title "错误" \
               --msgbox "❌ 没有找到任何日志文件\n\n目录: $logs_dir" \
               10 50
        return
    fi
    
    # 选择日志文件
    local log_choice=$(dialog \
        --title "选择日志文件 - $server_name" \
        --menu "选择要查看的日志文件：" \
        20 60 10 \
        "${log_files[@]}" \
        --stdout)
    
    if [ -z "$log_choice" ]; then
        return
    fi
    
    local log_file="$logs_dir/$log_choice"
    
    # 显示日志内容
    if [ -f "$log_file" ]; then
        dialog --title "日志内容 - $log_choice" \
               --textbox "$log_file" \
               25 80
    else
        dialog --title "错误" \
               --msgbox "❌ 无法读取日志文件: $log_file" \
               10 50
    fi
}

# 服务器管理菜单
manage_servers() {
    while true; do
        # 获取服务器列表
        servers=($(get_server_list))
        
        if [ ${#servers[@]} -eq 0 ]; then
            dialog --title "服务器管理" \
                   --msgbox "❌ 没有找到任何服务器\n\n请先安装服务器" \
                   8 40
            return
        fi
        
        # 构建菜单选项
        menu_items=()
        for ((i=0; i<${#servers[@]}; i++)); do
            menu_items+=("$((i+1))" "${servers[i]}")
        done
        
        server_choice=$(dialog \
            --title "选择服务器" \
            --menu "选择要管理的服务器：" \
            20 60 10 \
            "${menu_items[@]}" \
            --stdout)
        
        if [ -z "$server_choice" ]; then
            break
        fi
        
        # 获取选择的服务器
        index=$((server_choice-1))
        selected_server="${servers[index]}"
        
        # 服务器操作菜单
        action_choice=$(dialog \
            --title "服务器操作 - $selected_server" \
            --menu "选择要执行的操作：" \
            17 45 5 \
            1 "🚀 启动服务器" \
            2 "🗑️  删除服务器" \
            3 "📊 查看占用空间" \
            4 "📋 查看服务器日志" \
            0 "返回" \
            --stdout)
        
        case $action_choice in
            1)
                start_server "$selected_server"
                ;;
            2)
                delete_server "$selected_server"
                ;;
            3)
                check_server_size "$selected_server"
                ;;
            4)
                view_server_logs "$selected_server"
                ;;
            0)
                break
                ;;
        esac
    done
}

# 安装我的世界服务器主菜单
install_minecraft_server_menu() {
    while true; do
        choice=$(dialog \
            --title "安装我的世界服务器" \
            --menu "选择服务器类型：" \
            15 45 5 \
            1 "安装原版我的世界服务器" \
            2 "安装Fabric我的世界服务器" \
            0 "返回主菜单" \
            --stdout)
        
        case $choice in
            1)
                install_vanilla_server
                ;;
            2)
                install_fabric_server
                ;;
            0)
                break
                ;;
        esac
    done
}

# 使用您提供的原始安装代码
install_mc_server() {
    clear
    # 直接运行您提供的代码
    echo "=================================================="
    echo "           我的世界服务器环境自动安装"
    echo "=================================================="
    echo ""

    # 动态倒计时函数
    countdown() {
        local seconds=$1
        while [ $seconds -gt 0 ]; do
            echo -ne "等待 ${seconds}s...\033[0K\r"
            sleep 1
            ((seconds--))
        done
        echo -ne "开始执行！\033[0K\r"
        echo ""
    }

    # 进度条函数
    progress_bar() {
        local current=$1
        local total=$2
        local width=50
        local percentage=$((current * 100 / total))
        local completed=$((current * width / total))
        local remaining=$((width - completed))
        
        printf "["
        printf "%${completed}s" | tr " " "="
        printf "%${remaining}s" | tr " " " "
        printf "] %d%%" $percentage
    }

    # 总步骤数
    total_steps=4
    current_step=0

    echo "脚本将在2秒后开始执行..."
    countdown 2

    echo ""
    echo "开始执行安装流程..."
    echo ""

    # 步骤1：换源
    ((current_step++))
    echo "步骤 $current_step/$total_steps: 换源（使用清华镜像源）"
    apt --fix-broken install
    echo "执行: sed命令更新源列表..."
    sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' $PREFIX/etc/apt/sources.list && apt update && apt upgrade -y
    if [ $? -eq 0 ]; then
        echo "✅ 换源成功"
    else
        echo "❌ 换源失败"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # 步骤2：更新Termux
    ((current_step++))
    echo "步骤 $current_step/$total_steps: 检查并更新Termux"
    echo "执行: pkg update..."
    pkg update -y
    if [ $? -eq 0 ]; then
        echo "✅ Termux更新成功"
    else
        echo "❌ Termux更新失败"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # 步骤3：升级包
    ((current_step++))
    echo "步骤 $current_step/$total_steps: 升级已安装的包"
    echo "执行: pkg upgrade..."
    pkg upgrade -y
    if [ $? -eq 0 ]; then
        echo "✅ 包升级成功"
    else
        echo "❌ 包升级失败"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # 步骤4：安装OpenJDK
    ((current_step++))
    echo "步骤 $current_step/$total_steps: 下载并安装OpenJDK 17版本"
    echo "正在安装OpenJDK 17版本..."
    for version in 17; do
        echo "尝试安装 OpenJDK-$version..."
        pkg install -y openjdk-$version 2>/dev/null && echo "✅ openjdk-$version 安装成功" || echo "❌ openjdk-$version 不可用"
    done
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # 完成提示
    echo "=================================================="
    echo "✅ 我的世界服务器环境安装完成！"
    echo "=================================================="
    echo ""
    echo "已安装的Java版本:"
    pkg list-installed | grep openjdk
    echo ""
    echo "可以使用以下命令检查Java版本:"
    echo "java -version"
    
    echo ""
    read -p "按回车键返回菜单..."
}

# 主菜单
while true; do
    choice=$(dialog \
        --title "我的世界服务器管理器" \
        --menu "选择操作：" \
        17 50 8 \
        1 "安装我的世界服务器环境" \
        2 "检查JAVA环境" \
        3 "安装我的世界服务器" \
        4 "启动/管理服务器" \
        0 "退出程序" \
        --stdout)
    
    case $choice in
        1)
            install_mc_server
            ;;
        2)
            check_java_environment
            ;;
        3)
            install_minecraft_server_menu
            ;;
        4)
            manage_servers
            ;;
        0)
            clear
            exit 0
            ;;
    esac
done
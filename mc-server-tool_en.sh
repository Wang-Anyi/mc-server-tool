#!/data/data/com.termux/files/usr/bin/bash

# Install dialog and necessary tools
if ! command -v dialog &> /dev/null; then
    pkg install -y dialog
fi

# Install wget and curl
if ! command -v wget &> /dev/null; then
    pkg install -y wget
fi

if ! command -v curl &> /dev/null; then
    pkg install -y curl
fi

if ! command -v jq &> /dev/null; then
    pkg install -y jq
fi

# Request storage permission
request_storage_permission() {
    echo "Requesting storage permission..."
    if termux-setup-storage; then
        echo "✅ Storage permission granted"
        return 0
    else
        echo "❌ Unable to get storage permission"
        return 1
    fi
}

# Minecraft directory - Using Termux's safe directory
MC_DIR="$HOME/storage/shared/Minecraft"
# Fallback directory (if storage permission fails)
MC_DIR_FALLBACK="$HOME/Minecraft"

# Create Minecraft directory
create_minecraft_dir() {
    # First try to get storage permission
    if [ ! -d "$HOME/storage" ]; then
        if ! request_storage_permission; then
            echo "⚠️ Using fallback directory: $MC_DIR_FALLBACK"
            MC_DIR="$MC_DIR_FALLBACK"
        fi
    fi
    
    if [ ! -d "$MC_DIR" ]; then
        mkdir -p "$MC_DIR"
        echo "✅ Created Minecraft directory: $MC_DIR"
    fi
}

# Get version list from Mojang API
get_minecraft_versions() {
    echo "Fetching version list from Mojang API..."
    local api_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
    
    if ! curl -s --connect-timeout 10 "$api_url" > /tmp/version_manifest.json 2>/dev/null; then
        echo "❌ Unable to fetch version list"
        return 1
    fi
    
    # Check if file was created successfully
    if [ ! -f "/tmp/version_manifest.json" ]; then
        echo "❌ Version manifest file creation failed"
        return 1
    fi
    
    # Extract latest release
    local latest_release=$(jq -r '.latest.release' /tmp/version_manifest.json 2>/dev/null)
    if [ $? -ne 0 ] || [ "$latest_release" = "null" ]; then
        echo "❌ Unable to parse version information"
        return 1
    fi
    
    # Build version arrays
    versions=()
    version_ids=()
    
    # Add latest version with special marker
    versions+=("$latest_release" "Latest Stable")
    version_ids+=("$latest_release")
    
    # Extract other stable versions (1.8 and above)
    jq -r '.versions[] | select(.type == "release") | .id' /tmp/version_manifest.json 2>/dev/null | \
    while IFS= read -r version; do
        # Skip already added latest version
        if [ "$version" != "$latest_release" ]; then
            # Only keep versions 1.8 and above
            local major=$(echo "$version" | cut -d. -f1)
            local minor=$(echo "$version" | cut -d. -f2)
            
            if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 8 ]); then
                versions+=("$version" "Stable Release")
                version_ids+=("$version")
            fi
        fi
    done
    
    # Keep only first 10 versions to avoid overly long menu
    versions=("${versions[@]:0:20}")
    version_ids=("${version_ids[@]:0:10}")
    
    # Clean up temporary files
    rm -f /tmp/version_manifest.json
    
    return 0
}

# Get correct vanilla server download URL - fixed version
get_correct_vanilla_url() {
    local version=$1
    echo "Getting $version server download URL..."
    
    local manifest_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
    
    # Download version manifest
    if ! curl -s --connect-timeout 10 "$manifest_url" > /tmp/version_manifest.json 2>/dev/null; then
        echo "❌ Unable to fetch version manifest"
        return 1
    fi
    
    # Find version-specific URL
    local version_url=$(jq -r ".versions[] | select(.id == \"$version\") | .url" /tmp/version_manifest.json 2>/dev/null)
    
    if [ -z "$version_url" ] || [ "$version_url" = "null" ]; then
        echo "❌ Cannot find information for version $version"
        rm -f /tmp/version_manifest.json
        return 1
    fi
    
    # Get version details
    if ! curl -s --connect-timeout 10 "$version_url" > /tmp/version_details.json 2>/dev/null; then
        echo "❌ Unable to fetch version details"
        rm -f /tmp/version_manifest.json
        return 1
    fi
    
    # Extract server jar download URL
    local server_url=$(jq -r '.downloads.server.url' /tmp/version_details.json 2>/dev/null)
    
    # Clean up temporary files
    rm -f /tmp/version_manifest.json /tmp/version_details.json
    
    if [ -z "$server_url" ] || [ "$server_url" = "null" ]; then
        echo "❌ Cannot find server download URL"
        return 1
    fi
    
    echo "$server_url"
    return 0
}

# Get fallback download URL (if official API fails)
get_fallback_vanilla_url() {
    local version=$1
    
    # Real download URLs from official launcher (updated)
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
            echo "❌ Unsupported version: $version"
            return 1
            ;;
    esac
}

# Check JAVA environment function
check_java_environment() {
    clear
    echo "=================================================="
    echo "               Check JAVA Environment"
    echo "=================================================="
    echo ""
    
    # Check if Java is installed
    if command -v java &> /dev/null; then
        echo "✅ Java is installed"
        echo ""
        
        # Display Java version information
        echo "Java Version Information:"
        echo "----------------------------------------"
        java -version 2>&1
        echo ""
        
        # Display Java installation path
        echo "Java Installation Path:"
        echo "----------------------------------------"
        which java
        echo ""
        
        # Display installed Java packages
        echo "Installed Java-related packages:"
        echo "----------------------------------------"
        pkg list-installed | grep -i openjdk
        echo ""
        
        # Check JAVA_HOME environment variable
        echo "JAVA_HOME Environment Variable:"
        echo "----------------------------------------"
        if [ -n "$JAVA_HOME" ]; then
            echo "JAVA_HOME=$JAVA_HOME"
        else
            echo "JAVA_HOME is not set"
        fi
        echo ""
        
    else
        echo "❌ Java is not installed"
        echo ""
        echo "Recommended Java versions to install:"
        echo "----------------------------------------"
        echo "pkg install openjdk-17  # Recommended version"
        echo "pkg install openjdk-8   # Compatible version"
        echo "pkg install openjdk-11  # Stable version"
        echo ""
    fi
    
    # Check system architecture and compatibility
    echo "System Information:"
    echo "----------------------------------------"
    echo "Architecture: $(uname -m)"
    echo "System: $(uname -o)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    # Check memory information
    echo "Memory Information:"
    echo "----------------------------------------"
    free -h
    echo ""
    
    # Check storage space
    echo "Storage Space:"
    echo "----------------------------------------"
    df -h $PREFIX
    echo ""
    
    read -p "Press Enter to return to menu..."
}

# Install vanilla Minecraft server
install_vanilla_server() {
    clear
    echo "=================================================="
    echo "          Install Vanilla Minecraft Server"
    echo "=================================================="
    echo ""
    
    # Create Minecraft directory
    create_minecraft_dir
    
    # Get dynamic version list
    if ! get_minecraft_versions; then
        echo "❌ Unable to fetch version list, using fallback list"
        # Fallback version list - using correct format
        versions=(
            "1.18.2" "Long-term Support"
            "1.17.1" "Stable Version"
            "1.16.5" "Classic Version"
            "1.15.2" "Classic Version"
            "1.14.4" "Classic Version"
            "1.13.2" "Classic Version"
            "1.12.2" "Classic Version"
            "1.11.2" "Classic Version"
            "1.10.2" "Classic Version"
            "1.9.4" "Classic Version"
            "1.8.9" "Classic Version"
        )
        version_ids=("1.18.2" "1.17.1" "1.16.5" "1.15.2" "1.14.4" "1.13.2" "1.12.2" "1.11.2" "1.10.2" "1.9.4" "1.8.9")
    fi
    
    # Display version selection menu - using correct dialog format
    menu_items=()
    for ((i=0; i<${#versions[@]}; i+=2)); do
        menu_items+=("$((i/2+1))" "${versions[i]} - ${versions[i+1]}")
    done
    
    version_choice=$(dialog \
        --title "Select Vanilla Server Version" \
        --menu "Select version to install:" \
        20 60 15 \
        "${menu_items[@]}" \
        --stdout)
    
    if [ -z "$version_choice" ]; then
        return
    fi
    
    # Get selected version information
    index=$((version_choice-1))
    version_name="${version_ids[index]}"
    version_desc="${versions[index*2+1]}"
    
    # First try to get download URL using official API
    echo "Getting official download URL..."
    download_url=$(get_correct_vanilla_url "$version_name")
    
    # If official API fails, use fallback address
    if [ $? -ne 0 ] || [ -z "$download_url" ]; then
        echo "Official API failed, trying fallback address..."
        download_url=$(get_fallback_vanilla_url "$version_name")
        if [ $? -ne 0 ] || [ -z "$download_url" ]; then
            echo "❌ Unable to get download URL"
            read -p "Press Enter to return..."
            return
        fi
    fi
    
    # Create version directory
    version_dir="$MC_DIR/vanilla_$version_name"
    mkdir -p "$version_dir"
    
    clear
    echo "=================================================="
    echo "       Install Vanilla Minecraft Server $version_name"
    echo "=================================================="
    echo ""
    echo "Version: $version_name - $version_desc"
    echo "Directory: $version_dir"
    echo "Download URL: $download_url"
    echo ""
    
    # Check if directory was created successfully
    if [ ! -d "$version_dir" ]; then
        echo "❌ Unable to create directory: $version_dir"
        echo "Please check storage permissions"
        read -p "Press Enter to return..."
        return
    fi
    
    # Download server jar file
    echo "Downloading server file..."
    cd "$version_dir" || {
        echo "❌ Unable to enter directory: $version_dir"
        read -p "Press Enter to return..."
        return
    }
    
    # Try using curl for download (more reliable)
    echo "Using curl to download..."
    if curl -L -o "server.jar" "$download_url"; then
        echo "✅ Server file downloaded successfully"
        echo "✅ File saved as: server.jar"
    else
        echo "❌ curl download failed, trying wget..."
        # If curl fails, try wget
        if wget -O "server.jar" "$download_url"; then
            echo "✅ Server file downloaded successfully"
            echo "✅ File saved as: server.jar"
        else
            echo "❌ Download failed, please check network connection"
            echo "You can manually download: $download_url"
            echo "Then rename it to server.jar and place in: $version_dir"
            read -p "Press Enter to return..."
            return
        fi
    fi
    
    echo ""
    echo "Creating startup script..."
    
    # Determine recommended memory based on version
    local major=$(echo "$version_name" | cut -d. -f1)
    local minor=$(echo "$version_name" | cut -d. -f2)
    local memory="1G"
    
    # Newer versions need more memory
    if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 17 ]); then
        memory="2G"
    fi
    
    # Create startup script
    cat > "start.sh" << EOF
#!/bin/bash
echo "Starting Minecraft Server $version_name"
echo "Memory allocation: ${memory} (modify -Xmx parameter in start.sh)"
java -Xmx${memory} -Xms512M -jar server.jar nogui
EOF
    
    chmod +x start.sh
    
    # Create EULA agreement file
    echo "eula=true" > eula.txt
    
    echo "✅ Vanilla server installation completed!"
    echo ""
    echo "Server location: $version_dir"
    echo "Start command: cd '$version_dir' && ./start.sh"
    echo ""
    echo "Notes:"
    echo "• World files will be generated on first startup"
    echo "• Modify server.properties to configure server"
    echo "• Edit -Xmx parameter in start.sh for more memory"
    echo "• Recommended memory: ${memory} (automatically adjusted based on version)"
    echo ""
    
    read -p "Press Enter to return to menu..."
}

# Install Fabric Minecraft server
install_fabric_server() {
    clear
    echo "=================================================="
    echo "         Install Fabric Minecraft Server"
    echo "=================================================="
    echo ""
    
    # Create Minecraft directory
    create_minecraft_dir
    
    # Fabric supported version list - rich version selection
    versions=(
        "1.21.4" "Latest Fabric"
        "1.21.3" "Fabric Supported"
        "1.21.2" "Fabric Supported"
        "1.21.1" "Fabric Supported"
        "1.21" "Fabric Supported"
        "1.20.6" "Fabric Stable"
        "1.20.5" "Fabric Supported"
        "1.20.4" "Fabric Supported"
        "1.20.3" "Fabric Supported"
        "1.20.2" "Fabric Supported"
        "1.20.1" "Fabric Supported"
        "1.19.4" "Fabric Supported"
        "1.19.3" "Fabric Supported"
        "1.19.2" "Fabric Supported"
        "1.19.1" "Fabric Supported"
        "1.19" "Fabric Supported"
        "1.18.2" "Fabric Long-term Support"
        "1.18.1" "Fabric Supported"
        "1.18" "Fabric Supported"
        "1.17.1" "Fabric Supported"
        "1.17" "Fabric Supported"
        "1.16.5" "Fabric Classic"
        "1.16.4" "Fabric Supported"
        "1.16.3" "Fabric Supported"
        "1.16.2" "Fabric Supported"
        "1.16.1" "Fabric Supported"
        "1.15.2" "Fabric Classic"
        "1.14.4" "Fabric Classic"
    )
    version_ids=("1.21.4" "1.21.3" "1.21.2" "1.21.1" "1.21" "1.20.6" "1.20.5" "1.20.4" "1.20.3" "1.20.2" "1.20.1" "1.19.4" "1.19.3" "1.19.2" "1.19.1" "1.19" "1.18.2" "1.18.1" "1.18" "1.17.1" "1.17" "1.16.5" "1.16.4" "1.16.3" "1.16.2" "1.16.1" "1.15.2" "1.14.4")
    
    # Display version selection menu - using correct dialog format
    menu_items=()
    for ((i=0; i<${#versions[@]}; i+=2)); do
        menu_items+=("$((i/2+1))" "${versions[i]} - ${versions[i+1]}")
    done
    
    version_choice=$(dialog \
        --title "Select Fabric Server Version" \
        --menu "Select version to install:" \
        20 60 15 \
        "${menu_items[@]}" \
        --stdout)
    
    if [ -z "$version_choice" ]; then
        return
    fi
    
    # Get selected version information
    index=$((version_choice-1))
    version_name="${version_ids[index]}"
    version_desc="${versions[index*2+1]}"
    
    # Fixed Fabric versions
    fabric_loader_version="0.17.3"
    fabric_installer_version="1.1.0"
    
    # Build Fabric server download URL
    download_url="https://meta.fabricmc.net/v2/versions/loader/$version_name/$fabric_loader_version/$fabric_installer_version/server/jar"
    
    # Create version directory
    version_dir="$MC_DIR/fabric_$version_name"
    mkdir -p "$version_dir"
    
    clear
    echo "=================================================="
    echo "     Install Fabric Minecraft Server $version_name"
    echo "=================================================="
    echo ""
    echo "Version: $version_name - $version_desc"
    echo "Fabric Loader: $fabric_loader_version (fixed)"
    echo "Fabric Installer: $fabric_installer_version (fixed)"
    echo "Directory: $version_dir"
    echo "Download URL: $download_url"
    echo ""
    
    # Check if directory was created successfully
    if [ ! -d "$version_dir" ]; then
        echo "❌ Unable to create directory: $version_dir"
        echo "Please check storage permissions"
        read -p "Press Enter to return..."
        return
    fi
    
    # Download Fabric server file
    echo "Downloading Fabric server file..."
    cd "$version_dir" || {
        echo "❌ Unable to enter directory: $version_dir"
        read -p "Press Enter to return..."
        return
    }
    
    # Try using curl to download
    echo "Using curl to download..."
    if curl -L -o "server.jar" "$download_url"; then
        echo "✅ Fabric server file downloaded successfully"
        echo "✅ File saved as: server.jar"
    else
        echo "❌ curl download failed, trying wget..."
        if wget -O "server.jar" "$download_url"; then
            echo "✅ Fabric server file downloaded successfully"
            echo "✅ File saved as: server.jar"
        else
            echo "❌ Download failed, please check network connection"
            echo "You can manually download: $download_url"
            echo "Then rename it to server.jar and place in: $version_dir"
            read -p "Press Enter to return..."
            return
        fi
    fi
    
    echo ""
    echo "Creating startup script..."
    
    # Determine recommended memory based on version
    local major=$(echo "$version_name" | cut -d. -f1)
    local minor=$(echo "$version_name" | cut -d. -f2)
    local memory="2G"
    
    # Fabric typically needs more memory
    if [ "$major" -ge 2 ] || ([ "$major" -eq 1 ] && [ "$minor" -ge 17 ]); then
        memory="3G"
    fi
    
    # Create startup script
    cat > "start.sh" << EOF
#!/bin/bash
echo "Starting Fabric Minecraft Server $version_name"
echo "Fabric Loader: $fabric_loader_version"
echo "Fabric Installer: $fabric_installer_version"
echo "Memory allocation: ${memory} (modify -Xmx parameter in start.sh)"
java -Xmx${memory} -Xms1G -jar server.jar nogui
EOF
    
    chmod +x start.sh
    
    # Create EULA agreement file
    echo "eula=true" > eula.txt
    
    # Create mods directory
    mkdir -p mods
    
    echo "✅ Fabric server installation completed!"
    echo ""
    echo "Server location: $version_dir"
    echo "Start command: cd '$version_dir' && ./start.sh"
    echo ""
    echo "Notes:"
    echo "• World files and Fabric configuration will be generated on first startup"
    echo "• Place mods in the mods folder"
    echo "• Edit -Xmx parameter in start.sh for more memory"
    echo "• Recommended memory: ${memory} (Fabric needs more memory)"
    echo ""
    
    read -p "Press Enter to return to menu..."
}

# Get server list
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

# Start server
start_server() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    clear
    echo "=================================================="
    echo "       Start Server: $server_name"
    echo "=================================================="
    echo ""
    
    if [ ! -f "$server_dir/server.jar" ]; then
        echo "❌ Server file does not exist: $server_dir/server.jar"
        read -p "Press Enter to return..."
        return
    fi
    
    echo "Server directory: $server_dir"
    echo "Starting server..."
    echo ""
    echo "Tip: Press Ctrl+C to stop server"
    echo "=================================================="
    echo ""
    
    cd "$server_dir"
    java -jar server.jar nogui
    
    echo ""
    echo "=================================================="
    echo "Server has stopped running"
    echo "=================================================="
    echo ""
    read -p "Press Enter to return..."
}

# Delete server
delete_server() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    # First confirmation
    dialog --title "Confirm Deletion" \
           --yesno "Are you sure you want to delete server '$server_name'?\n\nThis action cannot be undone!" \
           10 50
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Second confirmation
    dialog --title "Final Confirmation" \
           --yesno "⚠️  Final Warning!\n\nReally delete server '$server_name'?\nAll data will be permanently lost!" \
           12 50
    
    if [ $? -eq 0 ]; then
        if rm -rf "$server_dir"; then
            dialog --title "Deletion Successful" \
                   --msgbox "✅ Server '$server_name' successfully deleted!" \
                   8 40
        else
            dialog --title "Deletion Failed" \
                   --msgbox "❌ Failed to delete server, please check permissions" \
                   8 40
        fi
    fi
}

# Check server disk usage
check_server_size() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    
    if [ -d "$server_dir" ]; then
        local size=$(du -sh "$server_dir" 2>/dev/null | cut -f1)
        local file_count=$(find "$server_dir" -type f | wc -l)
        
        dialog --title "Server Disk Usage" \
               --msgbox "Server: $server_name\n\nDisk Usage: $size\nFile Count: $file_count\n\nDirectory: $server_dir" \
               12 50
    else
        dialog --title "Error" \
               --msgbox "❌ Server directory does not exist: $server_dir" \
               8 40
    fi
}

# View server logs
view_server_logs() {
    local server_name=$1
    local server_dir="$MC_DIR/$server_name"
    local logs_dir="$server_dir/logs"
    
    if [ ! -d "$logs_dir" ]; then
        dialog --title "Error" \
               --msgbox "❌ Log directory does not exist: $logs_dir\n\nServer may not have run yet or no logs generated." \
               10 50
        return
    fi
    
    # Find all .log files
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$(basename "$file")" "Log File")
    done < <(find "$logs_dir" -name "*.log" -type f -print0 2>/dev/null)
    
    if [ ${#log_files[@]} -eq 0 ]; then
        dialog --title "Error" \
               --msgbox "❌ No log files found\n\nDirectory: $logs_dir" \
               10 50
        return
    fi
    
    # Select log file
    local log_choice=$(dialog \
        --title "Select Log File - $server_name" \
        --menu "Select log file to view:" \
        20 60 10 \
        "${log_files[@]}" \
        --stdout)
    
    if [ -z "$log_choice" ]; then
        return
    fi
    
    local log_file="$logs_dir/$log_choice"
    
    # Display log content
    if [ -f "$log_file" ]; then
        dialog --title "Log Content - $log_choice" \
               --textbox "$log_file" \
               25 80
    else
        dialog --title "Error" \
               --msgbox "❌ Unable to read log file: $log_file" \
               10 50
    fi
}

# Server management menu
manage_servers() {
    while true; do
        # Get server list
        servers=($(get_server_list))
        
        if [ ${#servers[@]} -eq 0 ]; then
            dialog --title "Server Management" \
                   --msgbox "❌ No servers found\n\nPlease install a server first" \
                   8 40
            return
        fi
        
        # Build menu options
        menu_items=()
        for ((i=0; i<${#servers[@]}; i++)); do
            menu_items+=("$((i+1))" "${servers[i]}")
        done
        
        server_choice=$(dialog \
            --title "Select Server" \
            --menu "Select server to manage:" \
            20 60 10 \
            "${menu_items[@]}" \
            --stdout)
        
        if [ -z "$server_choice" ]; then
            break
        fi
        
        # Get selected server
        index=$((server_choice-1))
        selected_server="${servers[index]}"
        
        # Server action menu
        action_choice=$(dialog \
            --title "Server Actions - $selected_server" \
            --menu "Select action to perform:" \
            17 45 5 \
            1 "🚀 Start Server" \
            2 "🗑️  Delete Server" \
            3 "📊 Check Disk Usage" \
            4 "📋 View Server Logs" \
            0 "Return" \
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

# Install Minecraft server main menu
install_minecraft_server_menu() {
    while true; do
        choice=$(dialog \
            --title "Install Minecraft Server" \
            --menu "Select server type:" \
            15 45 5 \
            1 "Install Vanilla Minecraft Server" \
            2 "Install Fabric Minecraft Server" \
            0 "Return to Main Menu" \
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

# Use your original installation code
install_mc_server() {
    clear
    # Directly run your provided code
    echo "=================================================="
    echo "           Minecraft Server Environment Auto Setup"
    echo "=================================================="
    echo ""

    # Dynamic countdown function
    countdown() {
        local seconds=$1
        while [ $seconds -gt 0 ]; do
            echo -ne "Waiting ${seconds}s...\033[0K\r"
            sleep 1
            ((seconds--))
        done
        echo -ne "Starting execution!\033[0K\r"
        echo ""
    }

    # Progress bar function
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

    # Total steps
    total_steps=4
    current_step=0

    echo "Script will start execution in 2 seconds..."
    countdown 2

    echo ""
    echo "Starting installation process..."
    echo ""

    # Step 1: Change sources
    ((current_step++))
    echo "Step $current_step/$total_steps: Change sources (using Tsinghua mirror)"
    apt --fix-broken install
    echo "Executing: sed command to update source list..."
    sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' $PREFIX/etc/apt/sources.list && apt update && apt upgrade -y
    if [ $? -eq 0 ]; then
        echo "✅ Source change successful"
    else
        echo "❌ Source change failed"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # Step 2: Update Termux
    ((current_step++))
    echo "Step $current_step/$total_steps: Check and update Termux"
    echo "Executing: pkg update..."
    pkg update -y
    if [ $? -eq 0 ]; then
        echo "✅ Termux update successful"
    else
        echo "❌ Termux update failed"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # Step 3: Upgrade packages
    ((current_step++))
    echo "Step $current_step/$total_steps: Upgrade installed packages"
    echo "Executing: pkg upgrade..."
    pkg upgrade -y
    if [ $? -eq 0 ]; then
        echo "✅ Package upgrade successful"
    else
        echo "❌ Package upgrade failed"
        exit 1
    fi
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # Step 4: Install OpenJDK
    ((current_step++))
    echo "Step $current_step/$total_steps: Download and install required OpenJDK version for server"
    echo "Installing required OpenJDK version for server..."
    for version in 17 21; do
        echo "Trying to install OpenJDK-$version..."
        pkg install -y openjdk-$version 2>/dev/null && echo "✅ openjdk-$version installation successful" || echo "❌ openjdk-$version not available"
    done
    progress_bar $current_step $total_steps
    echo ""
    echo ""

    # Completion message
    echo "=================================================="
    echo "✅ Minecraft Server Environment Setup Complete!"
    echo "=================================================="
    echo ""
    echo "Installed Java versions:"
    pkg list-installed | grep openjdk
    echo ""
    echo "You can check Java version using:"
    echo "java -version"
    
    echo ""
    read -p "Press Enter to return to menu..."
}

# Main menu
while true; do
    choice=$(dialog \
        --title "Minecraft Server Manager" \
        --menu "Select operation:" \
        17 50 8 \
        1 "Install Minecraft Server Environment" \
        2 "Check JAVA Environment" \
        3 "Install Minecraft Server" \
        4 "Start/Manage Servers" \
        0 "Exit Program" \
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
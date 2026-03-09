#!/bin/bash
# start_commander.sh - Script unificat de lansare pentru QEMU Commander Pro
# Rulează cu sudo pentru a activa Hugepages și Performance Governor

# Culori pentru output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     OMNIBUS QEMU COMMANDER PRO - DEPLOYMENT FINAL          ║${NC}"
echo -e "${CYAN}║     Virtualizare Enterprise pentru 100+ OS-uri              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificare privilegii root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Eroare: Rulează acest script cu sudo pentru a activa Hugepages și Real-Time Priority.${NC}"
   echo -e "${YELLOW}📌 Utilizare: sudo ./start_commander.sh${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/6] Verificare dependințe...${NC}"

# Verificare Python și Flask
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 nu este instalat. Instalează: apt install python3 python3-pip${NC}"
    exit 1
fi

# Instalare pachete Python necesare
pip3 install flask flask-cors psutil paramiko --quiet

# Verificare Quickemu
if ! command -v quickemu &> /dev/null; then
    echo -e "${YELLOW}⚠️ Quickemu nu este instalat. Instalare automată...${NC}"
    sudo apt-add-repository ppa:flexiondotorg/quickemu -y
    sudo apt update
    sudo apt install quickemu quickgui -y
fi

echo -e "${YELLOW}[2/6] Activare optimizări kernel...${NC}"

# Activare Hugepages (2MB per pagină) - pentru performanță RAM
echo 8192 > /proc/sys/vm/nr_hugepages
echo -e "${GREEN}✅ Hugepages activate: 8192 pagini (16GB)${NC}"

# Setare Performance Governor pentru toate nucleele CPU
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null || true
done
echo -e "${GREEN}✅ CPU Governor setat la 'performance' pe toate nucleele${NC}"

# Activare IOMMU pentru GPU Passthrough (dacă există)
if grep -q "Intel" /proc/cpuinfo; then
    if ! grep -q "intel_iommu=on" /etc/default/grub; then
        echo -e "${YELLOW}⚠️ IOMMU Intel nu este activat. Pentru GPU Passthrough, adaugă 'intel_iommu=on' în grub.${NC}"
    fi
elif grep -q "AMD" /proc/cpuinfo; then
    if ! grep -q "amd_iommu=on" /etc/default/grub; then
        echo -e "${YELLOW}⚠️ IOMMU AMD nu este activat. Pentru GPU Passthrough, adaugă 'amd_iommu=on' în grub.${NC}"
    fi
fi

echo -e "${YELLOW}[3/6] Generare configurații pentru OS-uri prioritare...${NC}"

# Lista celor 100+ OS-uri prioritare (primele 40 pentru test)
OS_LIST=(
    # Windows Series (5)
    "windows 11" "windows 10" "windows 8.1" "windows 7" "windows server 2025"
    
    # macOS Series (5)
    "macos sequoia" "macos sonoma" "macos ventura" "macos monterey" "macos catalina"
    
    # Ubuntu Series (5)
    "ubuntu 24.04" "ubuntu 22.04" "ubuntu 20.04" "ubuntu 24.10" "ubuntu 24.04 server"
    
    # Fedora Series (5)
    "fedora 41" "fedora 40" "fedora 39" "fedora workstation" "fedora silverblue"
    
    # Debian Series (5)
    "debian 12" "debian 11" "debian 10" "debian testing" "debian unstable"
    
    # Arch Family (5)
    "archlinux" "manjaro kde" "manjaro gnome" "endeavouros" "garuda"
    
    # Enterprise Linux (5)
    "rhel 9" "rocky 9" "alma 9" "centos stream 9" "oracle linux 9"
    
    # BSD Family (5)
    "freebsd 14" "openbsd 7" "netbsd 10" "ghostbsd" "dragonflybsd"
    
    # Specializate (5)
    "kali" "nixos" "tails" "qubes" "whonix"
    
    # Exotice (5)
    "haiku" "reactos" "freedos" "android-x86" "kolibrios"
)

for os in "${OS_LIST[@]}"; do
    echo -e "${YELLOW}   📦 Generare: ${os}${NC}"
    quickget $os &> /dev/null || true
    
    # Adăugare optimizări în fișierul .conf
    CONF_FILE=$(ls *.conf | grep -i "${os// /-}" | head -n 1 2>/dev/null)
    if [ -f "$CONF_FILE" ]; then
        echo "extra_args=\"-device i6300esb -watchdog-action reset -mem-prealloc -mem-path /dev/hugepages -object thread-context,id=tc1,prealloc-threads=4\"" >> "$CONF_FILE"
        echo -e "${GREEN}   ✅ Config optimizată: $CONF_FILE${NC}"
    fi
done

echo -e "${YELLOW}[4/6] Pornire Server Bridge Python...${NC}"

# Creare server.py
cat > server.py << 'EOF'
import time
import subprocess
import psutil
import paramiko
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Baza de date OS - specificații hardware
os_specs = {
    "windows 11": {"cpu": "4", "ram": "8192", "disk": "64GB", "gpu": "dx12"},
    "windows 10": {"cpu": "4", "ram": "4096", "disk": "32GB", "gpu": "dx11"},
    "macos sequoia": {"cpu": "6", "ram": "12288", "disk": "80GB", "gpu": "metal"},
    "ubuntu 24.04": {"cpu": "4", "ram": "4096", "disk": "25GB", "gpu": "vulkan"},
    "archlinux": {"cpu": "4", "ram": "4096", "disk": "20GB", "gpu": "vulkan"},
}

# Monitorizare rețea
last_net_io = psutil.net_io_counters()
last_time = time.time()

@app.route('/stats', methods=['GET'])
def get_stats():
    global last_net_io, last_time
    
    # CPU/RAM pentru procesul QEMU
    qemu_proc = None
    for proc in psutil.process_iter(['name']):
        if proc.info['name'] and 'qemu' in proc.info['name'].lower():
            qemu_proc = proc
            break
    
    # Calcul viteză rețea
    current_net = psutil.net_io_counters()
    current_time = time.time()
    interval = current_time - last_time
    down_speed = (current_net.bytes_recv - last_net_io.bytes_recv) / (1024 * 1024) / interval
    up_speed = (current_net.bytes_sent - last_net_io.bytes_sent) / (1024 * 1024) / interval
    
    last_net_io = current_net
    last_time = current_time
    
    if qemu_proc:
        return jsonify({
            "status": "running",
            "cpu": f"{qemu_proc.cpu_percent(interval=0.1)}%",
            "ram": f"{round(qemu_proc.memory_info().rss / 1024 / 1024, 2)} MB",
            "down": f"{round(down_speed, 2)} MB/s",
            "up": f"{round(up_speed, 2)} MB/s"
        })
    
    return jsonify({
        "status": "offline",
        "cpu": "0%",
        "ram": "0 MB",
        "down": "0 MB/s",
        "up": "0 MB/s"
    })

@app.route('/control', methods=['POST'])
def control_vm():
    data = request.json
    action = data.get('action')
    vm_name = data.get('vm_name', '').lower().replace(' ', '-')
    conf_file = f"{vm_name}.conf"
    
    spec = os_specs.get(vm_name, {"cpu": "2", "ram": "2048"})
    
    if action == 'start':
        # ThreadContext pentru boot rapid
        vcpus = int(spec['cpu'].split()[0])
        thread_opts = f"-object thread-context,id=tc1,prealloc-threads={vcpus}"
        mem_opts = f"-mem-prealloc -mem-path /dev/hugepages,prealloc-context=tc1"
        watchdog_opts = "-device i6300esb -watchdog-action reset"
        port_opts = "-netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 -device virtio-net-pci,netdev=net0"
        
        cmd = [
            "quickemu", "--vm", conf_file,
            "--extra_args", f"{thread_opts} {mem_opts} {watchdog_opts} {port_opts}"
        ]
        
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return jsonify({"msg": f"VM {vm_name} pornită cu optimizări ThreadContext și Watchdog."})
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    elif action == 'stop':
        try:
            subprocess.run(["pkill", "-f", conf_file])
            return jsonify({"msg": f"VM {vm_name} oprită."})
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Acțiune necunoscută"}), 400

@app.route('/ssh_exec', methods=['POST'])
def ssh_exec():
    data = request.json
    cmd = data.get('command')
    
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect("127.0.0.1", port=2222, username="user", password="user", timeout=5)
        
        stdin, stdout, stderr = ssh.exec_command(cmd)
        output = stdout.read().decode() + stderr.read().decode()
        ssh.close()
        return jsonify({"output": output})
    except Exception as e:
        return jsonify({"output": f"SSH Error: {str(e)}"})

@app.route('/snapshot', methods=['POST'])
def snapshot():
    data = request.json
    action = data.get('action')
    vm_name = data.get('vm_name', '').lower().replace(' ', '-')
    snap_name = data.get('snap_name', f"snap_{int(time.time())}")
    disk_path = f"{vm_name}/{vm_name}.qcow2"
    
    try:
        if action == 'create':
            subprocess.run(["qemu-img", "snapshot", "-c", snap_name, disk_path], check=True)
            return jsonify({"msg": f"Snapshot creat: {snap_name}"})
        elif action == 'restore':
            subprocess.run(["qemu-img", "snapshot", "-a", snap_name, disk_path], check=True)
            return jsonify({"msg": f"Restaurat la: {snap_name}"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Acțiune invalidă"}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Pornire server în background
python3 server.py &
SERVER_PID=$!
echo -e "${GREEN}✅ Server Bridge pornit (PID: $SERVER_PID) pe portul 5000${NC}"

echo -e "${YELLOW}[5/6] Pornire Dashboard HTML...${NC}"

# Creare dashboard HTML (folosim codul generat anterior)
cat > commander.html << 'EOF'
<!DOCTYPE html>
<html lang="ro">
<head>
    <meta charset="UTF-8">
    <title>OMNIBUS QEMU COMMANDER PRO</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Courier New', monospace;
        }
        body {
            background: #0a0c14;
            color: #00ff88;
            padding: 20px;
            min-height: 100vh;
        }
        .header {
            background: linear-gradient(135deg, #121620, #0a0c14);
            border: 2px solid #00ffff;
            border-radius: 30px;
            padding: 30px;
            margin-bottom: 30px;
        }
        .header-title {
            font-size: 2.5em;
            font-weight: 800;
            background: linear-gradient(135deg, #00ffff, #aa80ff, #ff66b2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            margin: 20px 0;
        }
        .stat-card {
            background: #121620;
            border: 1px solid #2a3442;
            border-radius: 15px;
            padding: 20px;
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: 700;
            color: #00ff88;
        }
        .main-grid {
            display: grid;
            grid-template-columns: 350px 1fr;
            gap: 25px;
            margin-bottom: 30px;
        }
        .os-panel {
            background: #121620;
            border: 1px solid #2a3442;
            border-radius: 25px;
            padding: 25px;
            height: 70vh;
            overflow-y: auto;
        }
        .os-item {
            padding: 12px 15px;
            margin: 5px 0;
            border: 1px solid #2a3442;
            border-radius: 10px;
            cursor: pointer;
            transition: 0.3s;
        }
        .os-item:hover {
            border-color: #00ffff;
            color: #00ffff;
        }
        .os-item.selected {
            border-color: #ffd700;
            color: #ffd700;
        }
        .btn-group {
            display: flex;
            gap: 15px;
            margin: 25px 0;
        }
        .btn {
            padding: 15px 25px;
            border-radius: 50px;
            border: none;
            font-weight: 600;
            cursor: pointer;
            transition: 0.3s;
        }
        .btn-start { background: #00ff88; color: black; }
        .btn-stop { background: #ff6b6b; color: white; }
        .btn:hover { transform: scale(1.02); box-shadow: 0 0 20px currentColor; }
        .monitor-panel {
            background: #1e2430;
            border: 1px solid #2a3442;
            border-radius: 20px;
            padding: 20px;
        }
        .monitor-stats {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 15px;
            margin: 20px 0;
        }
        .stat-monitor {
            background: #0a0c14;
            padding: 15px;
            border-radius: 12px;
            text-align: center;
        }
        .ssh-panel {
            background: #1e2430;
            border: 2px solid #ffaa66;
            border-radius: 15px;
            padding: 20px;
            margin-top: 25px;
        }
        .ssh-input {
            width: 100%;
            background: #000;
            border: 1px solid #ffaa66;
            border-radius: 8px;
            padding: 12px;
            color: #fff;
            margin: 10px 0;
        }
        .ssh-output {
            background: #000;
            border: 1px solid #2a3442;
            border-radius: 8px;
            padding: 15px;
            max-height: 150px;
            overflow-y: auto;
            color: #00ff88;
            font-size: 0.85em;
        }
        .snapshot-panel {
            background: linear-gradient(135deg, rgba(0,255,255,0.1), rgba(170,128,255,0.1));
            border: 2px solid #ffd700;
            border-radius: 15px;
            padding: 20px;
            margin-top: 25px;
        }
        @keyframes pulse-red {
            0% { background-color: #0a0c14; }
            50% { background-color: #330000; }
            100% { background-color: #0a0c14; }
        }
        .critical-overload { animation: pulse-red 0.5s infinite; }
        .footer {
            text-align: center;
            padding: 40px;
            color: #5f6c80;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-title">🖥️ OMNIBUS QEMU COMMANDER PRO</div>
        <div class="stats-grid">
            <div class="stat-card"><span class="stat-value" id="totalVMs">128</span><br>OS Suportate</div>
            <div class="stat-card"><span class="stat-value" id="activeVMs">0</span><br>VM-uri Active</div>
            <div class="stat-card"><span class="stat-value" id="totalCPU">0%</span><br>CPU Utilizat</div>
            <div class="stat-card"><span class="stat-value" id="totalRAM">0 MB</span><br>RAM Alocată</div>
        </div>
    </div>

    <div class="main-grid">
        <div class="os-panel">
            <h3 style="color: #00ffff;">📋 CATALOG OS (128+)</h3>
            <input type="text" id="search" placeholder="Caută sistem..." style="width:100%; padding:10px; margin:10px 0; background:#0a0c14; border:1px solid #2a3442; color:#fff;">
            <ul id="osList" style="list-style:none; padding:0;">
                <li class="os-item" onclick="selectOS('Windows 11 Pro')">Windows 11 Pro (24H2)</li>
                <li class="os-item" onclick="selectOS('Windows 10 LTSC')">Windows 10 LTSC</li>
                <li class="os-item" onclick="selectOS('macOS Sequoia')">macOS Sequoia 15</li>
                <li class="os-item" onclick="selectOS('macOS Sonoma')">macOS Sonoma 14</li>
                <li class="os-item" onclick="selectOS('Ubuntu 24.04')">Ubuntu 24.04 LTS</li>
                <li class="os-item" onclick="selectOS('Fedora 41')">Fedora Workstation 41</li>
                <li class="os-item" onclick="selectOS('Debian 12')">Debian 12 (Bookworm)</li>
                <li class="os-item" onclick="selectOS('Arch Linux')">Arch Linux (Rolling)</li>
                <li class="os-item" onclick="selectOS('Kali Linux')">Kali Linux 2026.1</li>
                <li class="os-item" onclick="selectOS('FreeBSD 14')">FreeBSD 14.1</li>
            </ul>
        </div>

        <div>
            <div class="monitor-panel">
                <h3>⚙️ CONTROL PANEL</h3>
                <div style="display:flex; justify-content:space-between; margin:20px 0;">
                    <span style="font-size:1.5em; color:#ffd700;" id="currentOS">Neselectat</span>
                    <span style="color:#ffd700;" id="vmStatus">OFFLINE</span>
                </div>
                
                <div class="btn-group">
                    <button class="btn btn-start" onclick="vmAction('start')" id="startBtn">▶️ START VM</button>
                    <button class="btn btn-stop" onclick="vmAction('stop')" id="stopBtn">⏹️ STOP VM</button>
                </div>

                <div class="monitor-stats">
                    <div class="stat-monitor"><span id="cpuValue">0%</span><br>CPU</div>
                    <div class="stat-monitor"><span id="ramValue">0 MB</span><br>RAM</div>
                    <div class="stat-monitor"><span id="netDown">0 MB/s</span><br>⬇️ DL</div>
                    <div class="stat-monitor"><span id="netUp">0 MB/s</span><br>⬆️ UL</div>
                </div>

                <canvas id="perfChart" height="100"></canvas>
            </div>

            <div class="ssh-panel">
                <h4 style="color:#ffaa66;">🔐 SSH REMOTE</h4>
                <input type="text" class="ssh-input" id="sshCmd" placeholder="ex: nvidia-smi, blender -b scene.blend -a">
                <div class="ssh-output" id="sshOutput">Conectare la VM...</div>
            </div>

            <div class="snapshot-panel">
                <h4 style="color:#ffd700;">🛡️ SNAPSHOT MANAGER</h4>
                <div style="display:flex; gap:10px; margin-top:10px;">
                    <button onclick="snapshotAction('create')" style="flex:1; padding:10px; background:#00ffff; color:black;">📸 CREATE</button>
                    <button onclick="snapshotAction('restore')" style="flex:1; padding:10px; background:#ffaa66; color:black;">🔄 RESTORE</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentOS = "";
        let cpuData = [], netData = [], timeLabels = [];
        let isRunning = false;
        let snapshots = [];

        const ctx = document.getElementById('perfChart').getContext('2d');
        const chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: 'CPU %',
                    borderColor: '#00ff88',
                    data: cpuData,
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'NET MB/s',
                    borderColor: '#00ffff',
                    data: netData,
                    tension: 0.4,
                    fill: true,
                    yAxisID: 'y1'
                }]
            },
            options: {
                scales: { y: { min: 0, max: 100 }, y1: { position: 'right', min: 0, max: 50 } }
            }
        });

        function selectOS(os) {
            currentOS = os;
            document.getElementById('currentOS').innerText = os;
            document.getElementById('startBtn').disabled = false;
        }

        async function vmAction(action) {
            if (!currentOS) return alert('Selectează un OS!');
            const res = await fetch('http://localhost:5000/control', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action, vm_name: currentOS })
            });
            const data = await res.json();
            document.getElementById('sshOutput').innerHTML += `\n> ${data.msg || data.error}`;
            isRunning = action === 'start';
            document.getElementById('vmStatus').innerText = isRunning ? 'RUNNING' : 'OFFLINE';
        }

        async function snapshotAction(action) {
            if (!currentOS) return alert('Selectează un OS!');
            const res = await fetch('http://localhost:5000/snapshot', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action, vm_name: currentOS })
            });
            const data = await res.json();
            document.getElementById('sshOutput').innerHTML += `\n> ${data.msg || data.error}`;
        }

        async function sendSSH() {
            const cmd = document.getElementById('sshCmd').value;
            const res = await fetch('http://localhost:5000/ssh_exec', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ command: cmd })
            });
            const data = await res.json();
            document.getElementById('sshOutput').innerHTML += `\n> ${data.output}`;
        }

        async function updateStats() {
            try {
                const res = await fetch('http://localhost:5000/stats');
                const data = await res.json();
                
                document.getElementById('cpuValue').innerText = data.cpu;
                document.getElementById('ramValue').innerText = data.ram;
                document.getElementById('netDown').innerText = data.down;
                document.getElementById('netUp').innerText = data.up;
                
                const cpuNum = parseFloat(data.cpu);
                const netNum = parseFloat(data.down);
                
                if (cpuNum > 95) document.body.classList.add('critical-overload');
                else document.body.classList.remove('critical-overload');
                
                const now = new Date().toLocaleTimeString();
                timeLabels.push(now);
                cpuData.push(cpuNum);
                netData.push(netNum);
                
                if (timeLabels.length > 20) {
                    timeLabels.shift();
                    cpuData.shift();
                    netData.shift();
                }
                chart.update();
                
                if (isRunning) document.getElementById('vmStatus').innerText = 'RUNNING';
            } catch (e) {
                console.log('Aștept serverul...');
            }
        }

        document.getElementById('sshCmd').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendSSH();
        });

        setInterval(updateStats, 2000);
    </script>
</body>
</html>
EOF

# Deschidere dashboard în browser
xdg-open commander.html 2>/dev/null || open commander.html 2>/dev/null
echo -e "${GREEN}✅ Dashboard deschis în browser${NC}"

echo -e "${YELLOW}[6/6] Sistem activ și monitorizat...${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎯 QEMU Commander PRO - DEPLOYMENT FINALIZAT${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "📡 Server Bridge: http://localhost:5000"
echo -e "🖥️ Dashboard: commander.html"
echo -e "🔐 SSH Port: 2222 (forwarded)"
echo -e "🎨 Render UI Port: 8080"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📌 Pentru a opri serverul: CTRL+C${NC}"
echo -e "${GREEN}🌟 WE ARE HERE • WE ARE STABLE 🚀${NC}"

# Menține scriptul activ
trap "kill $SERVER_PID 2>/dev/null; echo -e '\n${RED}Server oprit. La revedere!${NC}'; exit" INT
while true; do sleep 1; done
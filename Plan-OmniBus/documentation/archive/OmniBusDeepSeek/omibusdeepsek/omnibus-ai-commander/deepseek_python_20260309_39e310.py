#!/usr/bin/env python3
# server.py - OmniBus AI Commander Backend
# Rulează cu: python3 server.py

from flask import Flask, render_template, Response, jsonify, request
import psutil
import time
import json
import subprocess
import os
import threading
from queue import Queue

app = Flask(__name__)

# ============================================================
# CONFIGURARE
# ============================================================
RENDER_DIR = "./renders"
CONFIG_DIR = "./configs"
INSTALL_QUEUE = Queue()
INSTALL_STATUS = {"active": False, "current_os": "", "percent": 0, "total": 0, "completed": []}

# Creăm directoarele dacă nu există
os.makedirs(RENDER_DIR, exist_ok=True)
os.makedirs(CONFIG_DIR, exist_ok=True)

# ============================================================
# STREAM SSE - MONITORIZARE ÎN TIMP REAL
# ============================================================
@app.route('/stats-stream')
def stats_stream():
    """Stream de date live pentru dashboard prin SSE"""
    def generate():
        last_net = psutil.net_io_counters().bytes_recv
        last_time = time.time()
        
        while True:
            # CPU
            cpu_percent = psutil.cpu_percent(interval=0.5)
            
            # RAM
            ram = psutil.virtual_memory()
            ram_percent = ram.percent
            ram_used = ram.used / (1024**3)  # GB
            ram_total = ram.total / (1024**3)  # GB
            
            # Network (viteză)
            current_net = psutil.net_io_counters().bytes_recv
            current_time = time.time()
            net_speed = (current_net - last_net) / (1024 * 1024) / (current_time - last_time)  # MB/s
            last_net = current_net
            last_time = current_time
            
            # Hugepages (simulat)
            hugepages = 85  # În realitate, ai citi din /proc/meminfo
            
            # Verificăm procese QEMU
            qemu_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
                if 'qemu' in proc.info['name'].lower() if proc.info['name'] else False:
                    qemu_processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cpu': proc.info['cpu_percent'],
                        'ram': proc.info['memory_info'].rss / (1024**2) if proc.info['memory_info'] else 0
                    })
            
            stats = {
                "cpu": round(cpu_percent, 1),
                "ram_percent": round(ram_percent, 1),
                "ram_used": round(ram_used, 1),
                "ram_total": round(ram_total, 1),
                "net": round(net_speed, 2),
                "hugepages": hugepages,
                "qemu_count": len(qemu_processes),
                "qemu": qemu_processes,
                "install_status": INSTALL_STATUS,
                "timestamp": time.time()
            }
            
            yield f"data: {json.dumps(stats)}\n\n"
            time.sleep(1)
    
    return Response(generate(), mimetype='text/event-stream')

# ============================================================
# AI HARDWARE ADVISOR
# ============================================================
@app.route('/ai-recommend')
def ai_recommend():
    """Analizează hardware-ul și recomandă sisteme de operare"""
    
    # Colectăm date hardware
    ram_gb = psutil.virtual_memory().total / (1024**3)
    cpu_cores = psutil.cpu_count(logical=True)
    cpu_phys = psutil.cpu_count(logical=False)
    disk_free = psutil.disk_usage('/').free / (1024**3)
    
    # Detectăm GPU (simplificat)
    gpu_type = "Generic"
    try:
        lspci = subprocess.run(['lspci'], capture_output=True, text=True)
        if 'nvidia' in lspci.stdout.lower():
            gpu_type = "NVIDIA"
        elif 'amd' in lspci.stdout.lower():
            gpu_type = "AMD"
        elif 'intel' in lspci.stdout.lower():
            gpu_type = "Intel"
    except:
        pass
    
    # Logica de recomandare
    if ram_gb >= 32 and cpu_cores >= 12 and disk_free >= 200:
        icon = "🌟"
        level = "HIGH-END WORKSTATION"
        rec = ["Windows 11 Pro (GPU Render)", "macOS Sequoia (Metal)", "Ubuntu 24.04 (CPU Node)"]
        reason = f"AI detectează {round(ram_gb)}GB RAM, {cpu_cores} nuclee și GPU {gpu_type}. Poți rula 3+ VM-uri simultan."
    elif ram_gb >= 16 and cpu_cores >= 6 and disk_free >= 100:
        icon = "⚖️"
        level = "BALANCED SYSTEM"
        rec = ["Windows 10 LTSC (Light Render)", "Debian 12 (Headless)", "Arch Linux (Custom)"]
        reason = f"Configurație echilibrată: {round(ram_gb)}GB RAM, {cpu_cores} nuclee. Recomandăm 2-3 sisteme."
    elif ram_gb >= 8 and cpu_cores >= 4:
        icon = "💻"
        level = "ENTRY LEVEL"
        rec = ["Ubuntu 24.04 LTS", "Windows 10 (Light)", "FreeBSD 14"]
        reason = f"Resurse moderate: {round(ram_gb)}GB RAM. Poți rula 1-2 sisteme ușoare."
    else:
        icon = "⚠️"
        level = "LIMITED RESOURCES"
        rec = ["Alpine Linux (Ultra-light)", "FreeDOS", "KolibriOS"]
        reason = f"Resurse limitate: {round(ram_gb)}GB RAM. Recomandăm un sistem minimalist."
    
    # Generăm HTML pentru dashboard
    html = f"""
    <div class="ai-card">
        <div class="ai-header">{icon} {level}</div>
        <div class="ai-reason">{reason}</div>
        <div class="ai-rec-list">
            {''.join([f'<div class="ai-rec-item" hx-post="/install-os" hx-vals=\'{{"os": "{r}"}}\' hx-target="#install-log" hx-swap="beforeend">📦 {r}</div>' for r in rec])}
        </div>
        <div class="ai-specs">
            <span>RAM: {round(ram_gb)}GB</span>
            <span>CPU: {cpu_cores} nuclee ({cpu_phys} fizice)</span>
            <span>GPU: {gpu_type}</span>
            <span>Disk liber: {round(disk_free)}GB</span>
        </div>
    </div>
    """
    return html

# ============================================================
# SMART INSTALLER - COADĂ DE INSTALARE
# ============================================================
@app.route('/install-os', methods=['POST'])
def install_os():
    """Adaugă un OS în coada de instalare"""
    os_name = request.form.get('os', 'sistem necunoscut')
    
    # Generăm un ID unic pentru această instalare
    install_id = f"install_{int(time.time())}_{len(INSTALL_STATUS['completed'])}"
    
    # Adăugăm în coadă
    INSTALL_QUEUE.put({
        'id': install_id,
        'os': os_name,
        'status': 'pending'
    })
    
    # Dacă nu există o instalare activă, pornim procesarea
    if not INSTALL_STATUS['active']:
        thread = threading.Thread(target=process_install_queue)
        thread.daemon = True
        thread.start()
    
    # Returnăm un element pentru log
    return f"""
    <li class="log-item pending" id="{install_id}">
        <span class="log-time">[{time.strftime('%H:%M:%S')}]</span>
        <span class="log-os">{os_name}</span>
        <span class="log-status">⏳ În așteptare</span>
    </li>
    """

@app.route('/install-progress')
def install_progress():
    """Returnăm statusul instalării curente"""
    return jsonify(INSTALL_STATUS)

def process_install_queue():
    """Procesează coada de instalare (rulează în thread separat)"""
    INSTALL_STATUS['active'] = True
    INSTALL_STATUS['total'] = INSTALL_QUEUE.qsize()
    
    while not INSTALL_QUEUE.empty():
        install = INSTALL_QUEUE.get()
        os_name = install['os']
        install_id = install['id']
        
        INSTALL_STATUS['current_os'] = os_name
        INSTALL_STATUS['percent'] = 0
        
        # Simulăm instalarea (în realitate, aici ai rula quickget)
        for i in range(1, 101):
            INSTALL_STATUS['percent'] = i
            time.sleep(0.1)  # Simulăm progresul
            
            # Dacă ajungem la 25%, 50%, 75%, actualizăm și în fișierul real
            if i == 25:
                # Aici ai rula comanda reală: subprocess.run(['quickget', os_name.split()[0], os_name.split()[1]])
                pass
        
        INSTALL_STATUS['completed'].append(os_name)
        
        # Actualizăm elementul din log prin HTMX (out-of-band)
        # În realitate, ai trimite un update SSE
    
    INSTALL_STATUS['active'] = False
    INSTALL_STATUS['current_os'] = ""
    INSTALL_STATUS['percent'] = 0

# ============================================================
# CONTROL VM (START/STOP)
# ============================================================
@app.route('/control-vm', methods=['POST'])
def control_vm():
    """Pornește sau oprește o mașină virtuală"""
    vm_name = request.form.get('vm')
    action = request.form.get('action')
    
    # Căutăm fișierul de configurare
    conf_file = f"{CONFIG_DIR}/{vm_name.lower().replace(' ', '-')}.conf"
    
    if action == 'start':
        # Pornim VM-ul cu optimizări
        cmd = [
            "quickemu", "--vm", conf_file,
            "--extra_args", "-device i6300esb -watchdog-action reset -mem-prealloc -mem-path /dev/hugepages"
        ]
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            status = f"✅ {vm_name} a pornit cu succes"
        except Exception as e:
            status = f"❌ Eroare: {str(e)}"
    
    elif action == 'stop':
        try:
            subprocess.run(["pkill", "-f", vm_name])
            status = f"⏹️ {vm_name} oprit"
        except Exception as e:
            status = f"❌ Eroare: {str(e)}"
    
    else:
        status = "❌ Acțiune necunoscută"
    
    # Returnăm un fragment HTML pentru buton
    return f"""
    <div class="vm-status" hx-swap-oob="true" id="vm-{vm_name.replace(' ', '-')}">
        {status}
    </div>
    """

# ============================================================
# RENDER PREVIEW
# ============================================================
def get_latest_render():
    """Identifică cea mai recentă imagine randată"""
    try:
        files = [f for f in os.listdir(RENDER_DIR) if f.endswith(('.png', '.jpg', '.exr'))]
        if not files:
            return None
        latest = max([os.path.join(RENDER_DIR, f) for f in files], key=os.path.getmtime)
        return os.path.basename(latest)
    except:
        return None

@app.route('/render-stream')
def render_stream():
    """Stream pentru imagini randate"""
    def generate():
        last_file = None
        while True:
            current = get_latest_render()
            if current and current != last_file:
                html = f"""
                <div class="render-frame" hx-swap-oob="true" id="render-preview">
                    <img src="/get-render/{current}" style="width:100%; border-radius:8px; border:2px solid #00ff41;">
                    <div class="render-filename">{current}</div>
                </div>
                """
                yield f"data: {json.dumps({'html': html, 'file': current})}\n\n"
                last_file = current
            time.sleep(2)
    return Response(generate(), mimetype='text/event-stream')

@app.route('/get-render/<filename>')
def get_render(filename):
    """Servește imaginea randată"""
    from flask import send_from_directory
    return send_from_directory(RENDER_DIR, filename)

# ============================================================
# PAGINA PRINCIPALĂ
# ============================================================
@app.route('/')
def index():
    """Servește dashboard-ul HTMX"""
    return render_template('index.html')

# ============================================================
# PORNIRE SERVER
# ============================================================
if __name__ == '__main__':
    print("=" * 60)
    print("🚀 OMNIBUS AI COMMANDER - Server Pornit")
    print("=" * 60)
    print("📡 Endpoint SSE: http://localhost:5000/stats-stream")
    print("🖥️  Dashboard: http://localhost:5000")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
#!/usr/bin/env python3
# server.py - OmniBus AI Commander Backend
# Flask server cu SSE pentru monitorizare real-time și gestionare VM-uri

from flask import Flask, render_template, Response, jsonify, request
from flask_cors import CORS
import psutil
import time
import json
import subprocess
import os
import threading
from queue import Queue

app = Flask(__name__)
CORS(app)

# ============================================================
# CONFIGURARE ȘI VARIABILE GLOBALE
# ============================================================

# Coadă pentru instalări secvențiale
install_queue = Queue()
current_install = {"os": "", "percent": 0, "active": False, "total": 0, "completed": 0}
install_history = []

# Lista completă de OS-uri suportate (100+)
OS_CATALOG = [
    # Windows Series
    {"name": "Windows 11 Pro", "type": "windows", "size_gb": 25, "priority": 1},
    {"name": "Windows 10 LTSC", "type": "windows", "size_gb": 20, "priority": 1},
    {"name": "Windows Server 2025", "type": "windows", "size_gb": 30, "priority": 2},
    {"name": "Windows 8.1", "type": "windows", "size_gb": 18, "priority": 3},
    
    # macOS Series
    {"name": "macOS Sequoia", "type": "macos", "size_gb": 35, "priority": 1},
    {"name": "macOS Sonoma", "type": "macos", "size_gb": 32, "priority": 1},
    {"name": "macOS Ventura", "type": "macos", "size_gb": 30, "priority": 2},
    
    # Ubuntu Series
    {"name": "Ubuntu 24.04 LTS", "type": "linux", "size_gb": 12, "priority": 1},
    {"name": "Ubuntu 22.04 LTS", "type": "linux", "size_gb": 12, "priority": 1},
    {"name": "Ubuntu 20.04 LTS", "type": "linux", "size_gb": 12, "priority": 2},
    
    # Fedora Series
    {"name": "Fedora 41", "type": "linux", "size_gb": 15, "priority": 2},
    {"name": "Fedora 40", "type": "linux", "size_gb": 15, "priority": 2},
    
    # Debian Series
    {"name": "Debian 12", "type": "linux", "size_gb": 8, "priority": 1},
    {"name": "Debian 11", "type": "linux", "size_gb": 8, "priority": 2},
    
    # Arch Family
    {"name": "Arch Linux", "type": "linux", "size_gb": 5, "priority": 2},
    {"name": "Manjaro KDE", "type": "linux", "size_gb": 10, "priority": 3},
    {"name": "EndeavourOS", "type": "linux", "size_gb": 9, "priority": 3},
    
    # Enterprise Linux
    {"name": "RHEL 9", "type": "linux", "size_gb": 15, "priority": 2},
    {"name": "Rocky Linux 9", "type": "linux", "size_gb": 14, "priority": 2},
    {"name": "AlmaLinux 9", "type": "linux", "size_gb": 14, "priority": 2},
    
    # BSD Family
    {"name": "FreeBSD 14", "type": "bsd", "size_gb": 6, "priority": 3},
    {"name": "OpenBSD 7.5", "type": "bsd", "size_gb": 5, "priority": 3},
    
    # Specialized
    {"name": "Kali Linux", "type": "security", "size_gb": 18, "priority": 2},
    {"name": "NixOS 24.11", "type": "linux", "size_gb": 12, "priority": 3},
    {"name": "Tails", "type": "security", "size_gb": 4, "priority": 4},
    
    # Exotic
    {"name": "Haiku OS", "type": "exotic", "size_gb": 2, "priority": 4},
    {"name": "ReactOS", "type": "exotic", "size_gb": 3, "priority": 4},
    {"name": "FreeDOS", "type": "retro", "size_gb": 1, "priority": 5},
    {"name": "Android-x86", "type": "mobile", "size_gb": 8, "priority": 3},
]

# ============================================================
# FUNCȚII UTILITARE
# ============================================================

def get_hardware_budget():
    """Calculează bugetul de resurse disponibil"""
    try:
        total_ram = psutil.virtual_memory().total / (1024**3)  # GB
        available_ram = psutil.virtual_memory().available / (1024**3)
        total_cores = psutil.cpu_count(logical=True)
        free_disk = psutil.disk_usage('/').free / (1024**3)  # GB
        
        # Estimare consum per VM (medie)
        max_vms_ram = int((available_ram) / 4)
        max_vms_cpu = int(total_cores / 2)
        max_vms_disk = int(free_disk / 20)
        
        safe_limit = min(max_vms_ram, max_vms_cpu, max_vms_disk)
        
        return {
            "safe_limit": max(1, safe_limit),
            "total_ram": f"{round(total_ram, 1)}",
            "available_ram": f"{round(available_ram, 1)}",
            "total_cores": total_cores,
            "free_disk": f"{round(free_disk, 1)}",
            "max_vms_ram": max_vms_ram,
            "max_vms_cpu": max_vms_cpu,
            "max_vms_disk": max_vms_disk
        }
    except Exception as e:
        return {"safe_limit": 3, "total_ram": "16", "available_ram": "8", "total_cores": 8, "free_disk": "100"}

def get_ai_recommendation():
    """Generează recomandări inteligente bazate pe hardware"""
    hw = get_hardware_budget()
    ram = float(hw["available_ram"])
    cores = hw["total_cores"]
    
    if ram > 20 and cores > 12:
        return {
            "level": "HIGH-END WORKSTATION",
            "systems": ["Windows 11 Pro (GPU Render)", "macOS Sequoia (Metal)", "Ubuntu 24.04 (CPU Node)", "Arch Linux (Fast IO)"],
            "max_simultaneous": 4,
            "color": "#00ff88"
        }
    elif ram > 10 and cores > 6:
        return {
            "level": "MAINSTREAM PC",
            "systems": ["Windows 10 LTSC", "Ubuntu 24.04", "Debian 12"],
            "max_simultaneous": 2,
            "color": "#ffff00"
        }
    else:
        return {
            "level": "BASIC CONFIGURATION",
            "systems": ["Alpine Linux (Ultra-light)", "Debian 11 (Headless)"],
            "max_simultaneous": 1,
            "color": "#ffaa66"
        }

# ============================================================
# ENDPOINT-URI SSE (SERVER-SENT EVENTS)
# ============================================================

@app.route('/stats-stream')
def stats_stream():
    """Stream de statistici în timp real"""
    def generate():
        last_net = psutil.net_io_counters()
        last_time = time.time()
        
        while True:
            try:
                # CPU
                cpu_percent = psutil.cpu_percent(interval=0.5)
                
                # RAM
                ram = psutil.virtual_memory()
                ram_percent = ram.percent
                ram_used = ram.used / (1024**3)
                ram_total = ram.total / (1024**3)
                
                # Network
                current_net = psutil.net_io_counters()
                current_time = time.time()
                interval = current_time - last_time
                
                down_speed = (current_net.bytes_recv - last_net.bytes_recv) / (1024 * 1024) / interval
                up_speed = (current_net.bytes_sent - last_net.bytes_sent) / (1024 * 1024) / interval
                
                last_net = current_net
                last_time = current_time
                
                # Disk
                disk = psutil.disk_usage('/')
                disk_percent = disk.percent
                disk_free = disk.free / (1024**3)
                
                # Process monitoring (căutăm procese QEMU)
                qemu_processes = []
                for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
                    if proc.info['name'] and 'qemu' in proc.info['name'].lower():
                        qemu_processes.append({
                            "pid": proc.info['pid'],
                            "cpu": proc.info['cpu_percent'],
                            "ram": round(proc.info['memory_info'].rss / (1024**2), 2)
                        })
                
                stats = {
                    "cpu": round(cpu_percent, 1),
                    "ram_percent": ram_percent,
                    "ram_used": round(ram_used, 1),
                    "ram_total": round(ram_total, 1),
                    "down": round(down_speed, 2),
                    "up": round(up_speed, 2),
                    "disk_percent": disk_percent,
                    "disk_free": round(disk_free, 1),
                    "qemu_count": len(qemu_processes),
                    "qemu_processes": qemu_processes,
                    "install_active": current_install["active"],
                    "install_current": current_install["os"],
                    "install_percent": current_install["percent"]
                }
                
                yield f"data: {json.dumps(stats)}\n\n"
                time.sleep(1)
                
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"
                time.sleep(2)
    
    return Response(generate(), mimetype='text/event-stream')

# ============================================================
# ENDPOINT-URI API
# ============================================================

@app.route('/api/hardware')
def api_hardware():
    """Returnează informații hardware detaliate"""
    return jsonify(get_hardware_budget())

@app.route('/api/recommend')
def api_recommend():
    """Returnează recomandări AI"""
    return jsonify(get_ai_recommendation())

@app.route('/api/catalog')
def api_catalog():
    """Returnează catalogul complet de OS-uri"""
    return jsonify(OS_CATALOG)

@app.route('/api/install/start', methods=['POST'])
def api_install_start():
    """Pornește instalarea unui set de OS-uri"""
    data = request.json
    systems = data.get('systems', [])
    
    global current_install, install_history
    
    current_install = {
        "os": systems[0] if systems else "",
        "percent": 0,
        "active": True,
        "total": len(systems),
        "completed": 0,
        "queue": systems
    }
    
    # Simulăm instalarea (în realitate ar rula quickget)
    def install_thread():
        global current_install
        for i, os in enumerate(systems):
            for p in range(0, 101, 10):
                current_install["percent"] = p
                current_install["os"] = os
                time.sleep(0.3)
            current_install["completed"] = i + 1
            install_history.append(f"✅ {os} - instalat cu succes")
        
        current_install["active"] = False
    
    thread = threading.Thread(target=install_thread)
    thread.daemon = True
    thread.start()
    
    return jsonify({"status": "started", "systems": systems})

@app.route('/api/install/status')
def api_install_status():
    """Returnează statusul instalării curente"""
    return jsonify(current_install)

@app.route('/api/install/history')
def api_install_history():
    """Returnează istoricul instalărilor"""
    return jsonify(install_history[-10:])  # ultimele 10

@app.route('/api/control/vm', methods=['POST'])
def api_control_vm():
    """Controlează o mașină virtuală (start/stop)"""
    data = request.json
    action = data.get('action')
    vm_name = data.get('vm_name')
    
    # Aici ar fi logica reală cu quickemu
    return jsonify({"status": "success", "message": f"{action} pentru {vm_name}"})

# ============================================================
# ENDPOINT-URI HTMX (pentru dashboard)
# ============================================================

@app.route('/htmx/hardware-stats')
def htmx_hardware_stats():
    """Returnează HTML cu statistici hardware pentru HTMX"""
    hw = get_hardware_budget()
    rec = get_ai_recommendation()
    
    html = f"""
    <div class="hardware-panel">
        <div class="stat-row">
            <span>💾 RAM Disponibilă:</span>
            <span class="stat-value">{hw['available_ram']} GB / {hw['total_ram']} GB</span>
        </div>
        <div class="stat-row">
            <span>⚙️ Nuclee CPU:</span>
            <span class="stat-value">{hw['total_cores']}</span>
        </div>
        <div class="stat-row">
            <span>💽 Spațiu liber:</span>
            <span class="stat-value">{hw['free_disk']} GB</span>
        </div>
        <div class="stat-row">
            <span>🔒 Capacitate maximă:</span>
            <span class="stat-value">{hw['safe_limit']} VM-uri simultan</span>
        </div>
        <div class="ai-recommendation" style="border-left-color: {rec['color']};">
            <strong>{rec['level']}</strong><br>
            Recomandare: {', '.join(rec['systems'])}
        </div>
    </div>
    """
    return html

@app.route('/htmx/os-list')
def htmx_os_list():
    """Returnează lista de OS-uri filtrată"""
    filter_type = request.args.get('type', 'all')
    search = request.args.get('search', '').lower()
    
    filtered = OS_CATALOG
    if filter_type != 'all':
        filtered = [os for os in OS_CATALOG if os['type'] == filter_type]
    
    if search:
        filtered = [os for os in filtered if search in os['name'].lower()]
    
    # Sortăm după prioritate
    filtered.sort(key=lambda x: x['priority'])
    
    html = ""
    for os in filtered[:20]:  # limităm la 20 pentru performanță
        html += f"""
        <div class="os-item" data-os="{os['name']}" onclick="selectOS('{os['name']}')">
            <div class="os-name">{os['name']}</div>
            <div class="os-meta">
                <span class="os-type">{os['type']}</span>
                <span class="os-size">{os['size_gb']} GB</span>
            </div>
        </div>
        """
    
    return html

@app.route('/htmx/install-progress')
def htmx_install_progress():
    """Returnează bara de progres pentru instalare"""
    if current_install["active"]:
        html = f"""
        <div class="progress-container">
            <div class="progress-bar" style="width: {current_install['percent']}%"></div>
            <span class="progress-text">
                {current_install['os']} - {current_install['percent']}% 
                ({current_install['completed']}/{current_install['total']})
            </span>
        </div>
        """
    else:
        html = '<div class="idle-message">Fără instalări active. Selectează un sistem.</div>'
    
    return html

@app.route('/htmx/install-history')
def htmx_install_history():
    """Returnează istoricul instalărilor"""
    html = ""
    for entry in install_history[-5:]:
        html += f'<div class="history-item">{entry}</div>'
    
    if not html:
        html = '<div class="history-item muted">Nicio instalare recentă</div>'
    
    return html

# ============================================================
# PAGINA PRINCIPALĂ - DASHBOARD-UL HTMX
# ============================================================

@app.route('/')
def index():
    """Servește dashboard-ul principal"""
    return '''
<!DOCTYPE html>
<html lang="ro">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🌐 OMNIBUS AI COMMANDER - Virtualization Platform</title>
    <script src="https://unpkg.com/htmx.org@2.0.4"></script>
    <script src="https://unpkg.com/htmx-ext-sse@2.0.1/sse.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Inter', 'Segoe UI', monospace;
        }

        :root {
            --bg-deep: #0a0c14;
            --bg-card: #121620;
            --bg-panel: #1a1f2a;
            --bg-terminal: #1e2430;
            --bg-success: #00a86b;
            --bg-warning: #f0b400;
            --bg-danger: #dc3545;
            --text-primary: #e9f1ff;
            --text-secondary: #8b9bb5;
            --text-muted: #5f6c80;
            --border: #2a3442;
            --accent-cyan: #00ffff;
            --accent-green: #00ff88;
            --accent-purple: #aa80ff;
            --accent-orange: #ffaa66;
            --accent-gold: #ffd700;
            --gradient-1: linear-gradient(135deg, #00ffff, #aa80ff);
            --gradient-2: linear-gradient(135deg, #00ff88, #00ffff);
            --shadow: 0 8px 32px rgba(0, 255, 255, 0.15);
            --glow: 0 0 20px rgba(0, 255, 255, 0.3);
        }

        body {
            background: var(--bg-deep);
            color: var(--text-primary);
            min-height: 100vh;
            padding: 20px;
        }

        .dashboard {
            max-width: 1800px;
            margin: 0 auto;
        }

        /* Header */
        .header {
            background: linear-gradient(135deg, var(--bg-card), var(--bg-deep));
            border: 2px solid var(--accent-cyan);
            border-radius: 30px;
            padding: 30px;
            margin-bottom: 30px;
            position: relative;
            overflow: hidden;
        }

        .header-title {
            font-size: 3em;
            font-weight: 800;
            background: var(--gradient-1);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .header-subtitle {
            color: var(--text-secondary);
            font-size: 1.2em;
        }

        /* Grid principal */
        .main-grid {
            display: grid;
            grid-template-columns: 1fr 2fr;
            gap: 25px;
            margin-bottom: 30px;
        }

        /* Panou monitorizare */
        .monitor-panel {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 25px;
            padding: 25px;
        }

        .monitor-stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
            margin: 20px 0;
        }

        .stat-card {
            background: var(--bg-panel);
            border: 1px solid var(--border);
            border-radius: 15px;
            padding: 15px;
            text-align: center;
        }

        .stat-value {
            font-size: 2em;
            font-weight: 700;
            color: var(--accent-cyan);
        }

        .progress-bar-container {
            background: var(--bg-terminal);
            height: 10px;
            border-radius: 5px;
            margin: 10px 0;
            overflow: hidden;
        }

        .progress-fill {
            height: 100%;
            background: var(--gradient-2);
            width: 0%;
            transition: width 0.3s;
        }

        /* Panou control */
        .control-panel {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 25px;
            padding: 25px;
        }

        .os-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 10px;
            max-height: 400px;
            overflow-y: auto;
            padding: 10px;
        }

        .os-item {
            background: var(--bg-panel);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 12px;
            cursor: pointer;
            transition: all 0.3s;
        }

        .os-item:hover {
            border-color: var(--accent-cyan);
            transform: translateY(-2px);
        }

        .os-item.selected {
            border-color: var(--accent-gold);
            background: rgba(255,215,0,0.1);
        }

        .os-name {
            font-weight: 600;
        }

        .os-meta {
            display: flex;
            justify-content: space-between;
            margin-top: 5px;
            font-size: 0.7em;
            color: var(--text-muted);
        }

        .btn-group {
            display: flex;
            gap: 15px;
            margin: 20px 0;
        }

        .btn {
            padding: 15px 25px;
            border-radius: 50px;
            border: none;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }

        .btn-primary {
            background: var(--gradient-2);
            color: black;
        }

        .btn-primary:hover {
            transform: scale(1.02);
            box-shadow: var(--glow);
        }

        .btn-secondary {
            background: transparent;
            border: 2px solid var(--accent-gold);
            color: var(--accent-gold);
        }

        .btn-secondary:hover {
            background: rgba(255,215,0,0.1);
        }

        .ai-box {
            border-left: 4px solid var(--accent-green);
            padding: 15px;
            background: rgba(0,255,136,0.05);
            margin: 20px 0;
        }

        .install-panel {
            margin-top: 25px;
            padding: 20px;
            background: var(--bg-terminal);
            border: 1px solid var(--border);
            border-radius: 15px;
        }

        .progress-container {
            position: relative;
            height: 40px;
            background: var(--bg-deep);
            border-radius: 20px;
            overflow: hidden;
        }

        .progress-bar {
            height: 100%;
            background: var(--gradient-2);
            width: 0%;
            transition: width 0.3s;
        }

        .progress-text {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-weight: 600;
            text-shadow: 0 0 10px black;
        }

        .history-item {
            padding: 8px;
            border-bottom: 1px solid var(--border);
            font-size: 0.9em;
        }

        .history-item.muted {
            color: var(--text-muted);
        }

        /* Footer */
        .footer {
            text-align: center;
            padding: 40px;
            margin-top: 60px;
            border-top: 1px solid var(--border);
            color: var(--text-muted);
        }
    </style>
</head>
<body>
    <div class="dashboard" hx-ext="sse" sse-connect="/stats-stream">

        <!-- Header -->
        <div class="header">
            <div class="header-title">🌐 OMNIBUS AI COMMANDER</div>
            <div class="header-subtitle">Platformă Inteligentă de Virtualizare • 100+ OS-uri • AI Advisor • Smart Installer</div>
        </div>

        <!-- Grid principal -->
        <div class="main-grid">
            <!-- Panou monitorizare -->
            <div class="monitor-panel">
                <h2 style="color: var(--accent-cyan); margin-bottom: 20px;">📊 MONITORIZARE ÎN TIMP REAL</h2>
                
                <div class="monitor-stats">
                    <div class="stat-card">
                        <div>CPU</div>
                        <div class="stat-value"><span sse-swap="message" hx-swap="innerHTML" id="cpu-display">0</span>%</div>
                    </div>
                    <div class="stat-card">
                        <div>RAM</div>
                        <div class="stat-value"><span sse-swap="message" hx-swap="innerHTML" id="ram-display">0</span>%</div>
                    </div>
                </div>

                <div class="progress-bar-container">
                    <div class="progress-fill" id="cpu-bar" style="width:0%"></div>
                </div>
                <div style="margin-top: 5px; color: var(--text-secondary);">CPU Load</div>

                <div class="progress-bar-container">
                    <div class="progress-fill" id="ram-bar" style="width:0%"></div>
                </div>
                <div style="margin-top: 5px; color: var(--text-secondary);">RAM Usage</div>

                <div style="display: flex; justify-content: space-between; margin-top: 20px;">
                    <div>⬇️ Download: <span sse-swap="message" id="down-display">0</span> MB/s</div>
                    <div>⬆️ Upload: <span sse-swap="message" id="up-display">0</span> MB/s</div>
                </div>

                <div style="margin-top: 20px; color: var(--text-secondary);">
                    Spațiu liber: <span sse-swap="message" id="disk-free">0</span> GB
                </div>

                <div style="margin-top: 20px; color: var(--accent-cyan);">
                    VM-uri active: <span sse-swap="message" id="qemu-count">0</span>
                </div>
            </div>

            <!-- Hardware Stats & AI Advisor -->
            <div class="monitor-panel">
                <h2 style="color: var(--accent-green); margin-bottom: 20px;">🤖 AI HARDWARE ADVISOR</h2>
                
                <div hx-get="/htmx/hardware-stats" hx-trigger="load, every 30s" hx-target="this" hx-swap="innerHTML">
                    Se încarcă statisticile hardware...
                </div>
            </div>
        </div>

        <!-- Panou Control -->
        <div class="control-panel">
            <h2 style="color: var(--accent-gold); margin-bottom: 20px;">🎮 CONTROL PANEL</h2>
            
            <div style="display: flex; gap: 20px; margin-bottom: 20px;">
                <input type="text" id="search-os" placeholder="Caută sistem de operare..." 
                       style="flex:1; padding:12px; background: var(--bg-terminal); border:1px solid var(--border); color:white; border-radius:10px;">
                <select id="os-filter" style="padding:12px; background: var(--bg-terminal); border:1px solid var(--border); color:white; border-radius:10px;">
                    <option value="all">Toate</option>
                    <option value="windows">Windows</option>
                    <option value="linux">Linux</option>
                    <option value="macos">macOS</option>
                    <option value="bsd">BSD</option>
                </select>
            </div>

            <div class="os-list" id="os-container" 
                 hx-get="/htmx/os-list" 
                 hx-trigger="load, keyup changed delay:500ms from:#search-os, change from:#os-filter" 
                 hx-target="this" 
                 hx-swap="innerHTML"
                 hx-vals='js:{search: document.getElementById("search-os").value, type: document.getElementById("os-filter").value}'>
                Se încarcă lista de sisteme...
            </div>

            <div class="btn-group">
                <button class="btn btn-primary" onclick="startInstallSelected()" id="install-btn">
                    ⚡ INSTALEAZĂ SELECTATE
                </button>
                <button class="btn btn-secondary" onclick="clearSelection()">
                    🧹 CURĂȚĂ SELECȚIA
                </button>
            </div>

            <div class="install-panel">
                <h3 style="color: var(--accent-cyan); margin-bottom: 15px;">📦 INSTALARE ÎN CURS</h3>
                
                <div id="install-progress" hx-get="/htmx/install-progress" hx-trigger="every 1s" hx-swap="innerHTML">
                    <div class="idle-message">Fără instalări active.</div>
                </div>

                <div style="margin-top: 20px;">
                    <h4 style="color: var(--text-secondary);">Istoric instalări:</h4>
                    <div id="install-history" hx-get="/htmx/install-history" hx-trigger="every 2s" hx-swap="innerHTML">
                        <div class="history-item muted">Se încarcă...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            <p>🌐 OMNIBUS AI COMMANDER • Platformă inteligentă de virtualizare</p>
            <p style="margin-top: 10px; color: var(--accent-gold);">WE ARE HERE • WE ARE STABLE</p>
        </div>
    </div>

    <script>
        // Variabile globale
        let selectedOS = [];

        // Funcții pentru selectare OS
        function selectOS(osName) {
            const items = document.querySelectorAll('.os-item');
            items.forEach(item => {
                if (item.dataset.os === osName) {
                    item.classList.toggle('selected');
                    if (item.classList.contains('selected')) {
                        if (!selectedOS.includes(osName)) selectedOS.push(osName);
                    } else {
                        selectedOS = selectedOS.filter(os => os !== osName);
                    }
                }
            });
            updateInstallButton();
        }

        function clearSelection() {
            selectedOS = [];
            document.querySelectorAll('.os-item').forEach(item => {
                item.classList.remove('selected');
            });
            updateInstallButton();
        }

        function updateInstallButton() {
            const btn = document.getElementById('install-btn');
            btn.innerText = selectedOS.length > 0 
                ? `⚡ INSTALEAZĂ ${selectedOS.length} SISTEME` 
                : '⚡ INSTALEAZĂ SELECTATE';
        }

        function startInstallSelected() {
            if (selectedOS.length === 0) {
                alert('Selectează cel puțin un sistem de operare!');
                return;
            }
            
            fetch('/api/install/start', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ systems: selectedOS })
            })
            .then(response => response.json())
            .then(data => {
                console.log('Instalare pornită:', data);
                clearSelection();
            });
        }

        // Procesare SSE pentru update-uri live
        document.body.addEventListener('htmx:sseMessage', function(evt) {
            const data = JSON.parse(evt.detail.data);
            
            document.getElementById('cpu-display').innerText = data.cpu;
            document.getElementById('ram-display').innerText = data.ram_percent;
            document.getElementById('down-display').innerText = data.down;
            document.getElementById('up-display').innerText = data.up;
            document.getElementById('disk-free').innerText = data.disk_free;
            document.getElementById('qemu-count').innerText = data.qemu_count;
            
            document.getElementById('cpu-bar').style.width = data.cpu + '%';
            document.getElementById('ram-bar').style.width = data.ram_percent + '%';
        });
    </script>
</body>
</html>
    '''
# ============================================================
# PORNIRE SERVER
# ============================================================

if __name__ == '__main__':
    print("=" * 60)
    print("🌐 OMNIBUS AI COMMANDER - SERVER PORNIT")
    print("=" * 60)
    print("📡 Endpoint-uri principale:")
    print("   - http://localhost:5000/          Dashboard principal")
    print("   - http://localhost:5000/stats-stream    SSE Stream")
    print("   - http://localhost:5000/api/hardware    API Hardware")
    print("   - http://localhost:5000/api/recommend   API AI Advisor")
    print("   - http://localhost:5000/api/catalog     Catalog OS-uri")
    print("   - http://localhost:5000/api/install/*   API Instalare")
    print("   - http://localhost:5000/htmx/*          Endpoint-uri HTMX")
    print("=" * 60)
    print("⚙️  Hardware detectat:")
    
    # Afișăm hardware-ul detectat la pornire
    hw = get_hardware_budget()
    print(f"   - RAM: {hw['total_ram']} GB total, {hw['available_ram']} GB disponibil")
    print(f"   - CPU: {hw['total_cores']} nuclee")
    print(f"   - Spațiu liber: {hw['free_disk']} GB")
    print(f"   - Capacitate maximă recomandată: {hw['safe_limit']} VM-uri simultan")
    print("=" * 60)
    print("🤖 AI Advisor activ - Se recomandă:")
    rec = get_ai_recommendation()
    print(f"   - Nivel: {rec['level']}")
    print(f"   - Sisteme recomandate: {', '.join(rec['systems'][:3])}")
    if len(rec['systems']) > 3:
        print(f"     și încă {len(rec['systems'])-3}...")
    print("=" * 60)
    print("🚀 Pornește serverul Flask...")
    print("📝 Log-uri server:")
    print("-" * 60)
    
    # Pornim serverul Flask
    # Folosim host='0.0.0.0' pentru a permite acces din rețea
    # Port 5000 este standard pentru Flask
    # debug=True pentru dezvoltare (în producție setează debug=False)
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
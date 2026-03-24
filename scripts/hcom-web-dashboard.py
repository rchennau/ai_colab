#!/usr/bin/env python3
import os
import sqlite3
import json
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

# Path to hcom database
DB_PATH = os.path.expanduser("~/.hcom/hcom.db")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/')
def index():
    return render_template_string("""
<!DOCTYPE html>
<html>
<head>
    <title>ai-colab Project Health</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: sans-serif; background: #1e1e1e; color: #eee; padding: 20px; }
        .container { max-width: 1000px; margin: auto; }
        .card { background: #2d2d2d; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        h1, h2 { color: #00bcd4; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ai-colab Project Health</h1>
        <div class="grid">
            <div class="card">
                <h2>Performance Trends</h2>
                <canvas id="perfChart"></canvas>
            </div>
            <div class="card">
                <h2>Task Distribution</h2>
                <canvas id="taskChart"></canvas>
            </div>
        </div>
        <div class="card">
            <h2>Recent Activity</h2>
            <div id="events">Loading...</div>
        </div>
    </div>

    <script>
        async function fetchData() {
            const perfResp = await fetch('/api/performance');
            const perfData = await perfResp.json();
            
            const ctx = document.getElementById('perfChart').getContext('2d');
            new Chart(ctx, {
                type: 'line',
                data: {
                    labels: perfData.labels,
                    datasets: perfData.datasets
                },
                options: {
                    scales: { y: { beginAtZero: false, grid: { color: '#444' } }, x: { grid: { display: false } } },
                    plugins: { legend: { labels: { color: '#eee' } } }
                }
            });

            // Fetch events
            const eventResp = await fetch('/api/events');
            const eventData = await eventResp.json();
            const evDiv = document.getElementById('events');
            evDiv.innerHTML = eventData.map(e => `<div><b>${e.msg_from}</b>: ${e.msg_text}</div>`).join('');
        }
        fetchData();
    </script>
</body>
</html>
""")

@app.route('/api/performance')
def api_performance():
    conn = get_db_connection()
    rows = conn.execute("SELECT routine, cycles, timestamp FROM performance ORDER BY timestamp ASC").fetchall()
    conn.close()
    
    routines = {}
    labels = []
    for r in rows:
        ts = r['timestamp']
        if ts not in labels: labels.append(ts)
        
        name = r['routine']
        if name not in routines: routines[name] = []
        routines[name].append(r['cycles'])
        
    datasets = []
    colors = ['#00bcd4', '#ffeb3b', '#4caf50', '#ff5722']
    for i, (name, data) in enumerate(routines.items()):
        datasets.append({
            "label": name,
            "data": data,
            "borderColor": colors[i % len(colors)],
            "fill": False
        })
        
    return jsonify({"labels": labels, "datasets": datasets})

@app.route('/api/events')
def api_events():
    conn = get_db_connection()
    rows = conn.execute("SELECT msg_from, msg_text FROM events WHERE type='message' ORDER BY id DESC LIMIT 10").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050)

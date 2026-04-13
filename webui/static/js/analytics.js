/**
 * ai-colab Analytics Dashboard (P24.2)
 * Real-time aggregation of agent performance metrics.
 * Fetches data from /api/analytics/* endpoints and renders charts.
 */

// ============================================================
// Configuration
// ============================================================

const ANALYTICS_CONFIG = {
    refreshInterval: 30000, // 30 seconds
    trendDays: 7,
    chartColors: {
        blue: '#4cc9f0',
        green: '#2ecc71',
        yellow: '#f1c40f',
        red: '#e74c3c',
        purple: '#9b59b6',
        orange: '#f39c12',
    }
};

// ============================================================
// Data Fetching
// ============================================================

async function fetchAnalyticsSummary() {
    try {
        const response = await fetch('/api/analytics/summary');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics summary:', error);
        return null;
    }
}

async function fetchAnalyticsAgents() {
    try {
        const response = await fetch('/api/analytics/agents');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics agents:', error);
        return { agents: [], count: 0 };
    }
}

async function fetchAnalyticsTasks(days = 7) {
    try {
        const response = await fetch(`/api/analytics/tasks?days=${days}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics tasks:', error);
        return { tasks: [], count: 0 };
    }
}

async function fetchAnalyticsErrors(days = 7) {
    try {
        const response = await fetch(`/api/analytics/errors?days=${days}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics errors:', error);
        return { errors: {} };
    }
}

async function fetchAnalyticsCost() {
    try {
        const response = await fetch('/api/analytics/cost');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics cost:', error);
        return { total_cost: 0, total_tokens: 0, agents: {} };
    }
}

async function fetchAnalyticsTrends(days = 7) {
    try {
        const response = await fetch(`/api/analytics/trends?days=${days}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch analytics trends:', error);
        return { trends: [] };
    }
}

// ============================================================
// Rendering
// ============================================================

function renderSummaryCard(summary) {
    if (!summary) {
        document.getElementById('analytics-summary').innerHTML = '<p class="error">Failed to load summary</p>';
        return;
    }

    const html = `
        <div class="summary-grid">
            <div class="summary-card">
                <div class="summary-label">Total Agents</div>
                <div class="summary-value">${summary.total_agents}</div>
            </div>
            <div class="summary-card">
                <div class="summary-label">Active Agents</div>
                <div class="summary-value" style="color: ${ANALYTICS_CONFIG.chartColors.green}">${summary.active_agents}</div>
            </div>
            <div class="summary-card">
                <div class="summary-label">Error Agents</div>
                <div class="summary-value" style="color: ${summary.error_agents > 0 ? ANALYTICS_CONFIG.chartColors.red : ANALYTICS_CONFIG.chartColors.green}">${summary.error_agents}</div>
            </div>
            <div class="summary-card">
                <div class="summary-label">Avg Progress</div>
                <div class="summary-value">${summary.avg_progress}%</div>
            </div>
        </div>
    `;

    document.getElementById('analytics-summary').innerHTML = html;
}

function renderAgentCards(agentsData) {
    if (!agentsData || !agentsData.agents) {
        document.getElementById('analytics-agents').innerHTML = '<p class="error">Failed to load agents</p>';
        return;
    }

    const agents = agentsData.agents;
    if (agents.length === 0) {
        document.getElementById('analytics-agents').innerHTML = '<p class="info">No agents detected</p>';
        return;
    }

    const html = agents.map(agent => {
        const statusColor = agent.status === 'ready' ? ANALYTICS_CONFIG.chartColors.green :
                           agent.status === 'busy' ? ANALYTICS_CONFIG.chartColors.yellow :
                           ANALYTICS_CONFIG.chartColors.red;

        return `
            <div class="agent-card">
                <div class="agent-header">
                    <span class="agent-name">${agent.name}</span>
                    <span class="agent-status" style="color: ${statusColor}">${agent.status}</span>
                </div>
                <div class="agent-progress">
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${agent.progress}%"></div>
                    </div>
                    <span class="progress-text">${agent.progress}%</span>
                </div>
                <div class="agent-details">
                    <div class="detail-row">
                        <span>Track:</span>
                        <span>${agent.track || 'None'}</span>
                    </div>
                    <div class="detail-row">
                        <span>Step:</span>
                        <span>${agent.step || 'Idle'}</span>
                    </div>
                    <div class="detail-row">
                        <span>Phase:</span>
                        <span>${agent.phase || 'N/A'}</span>
                    </div>
                    <div class="detail-row">
                        <span>Latency:</span>
                        <span>${agent.latency_ms}ms</span>
                    </div>
                </div>
            </div>
        `;
    }).join('');

    document.getElementById('analytics-agents').innerHTML = `<div class="agent-grid">${html}</div>`;
}

function renderErrorDistribution(errorsData) {
    if (!errorsData || !errorsData.errors) {
        document.getElementById('analytics-errors').innerHTML = '<p class="error">Failed to load errors</p>';
        return;
    }

    const errors = errorsData.errors;
    const errorTypes = Object.keys(errors);

    if (errorTypes.length === 0) {
        document.getElementById('analytics-errors').innerHTML = '<p class="info">No errors recorded</p>';
        return;
    }

    const maxCount = Math.max(...Object.values(errors));
    const html = errorTypes.map(type => {
        const count = errors[type];
        const width = (count / maxCount) * 100;
        return `
            <div class="error-row">
                <span class="error-type">${type}</span>
                <div class="error-bar">
                    <div class="error-fill" style="width: ${width}%"></div>
                </div>
                <span class="error-count">${count}</span>
            </div>
        `;
    }).join('');

    document.getElementById('analytics-errors').innerHTML = `
        <h3>Error Distribution (Last ${errorsData.days} Days)</h3>
        <div class="error-list">${html}</div>
    `;
}

function renderCostMetrics(costData) {
    if (!costData) {
        document.getElementById('analytics-cost').innerHTML = '<p class="error">Failed to load cost metrics</p>';
        return;
    }

    const html = `
        <div class="cost-summary">
            <div class="cost-card">
                <div class="cost-label">Total Cost</div>
                <div class="cost-value">$${costData.total_cost.toFixed(2)}</div>
            </div>
            <div class="cost-card">
                <div class="cost-label">Total Tokens</div>
                <div class="cost-value">${costData.total_tokens.toLocaleString()}</div>
            </div>
        </div>
    `;

    if (costData.agents && Object.keys(costData.agents).length > 0) {
        const agentRows = Object.entries(costData.agents).map(([name, data]) => `
            <tr>
                <td>${name}</td>
                <td>${data.tokens.toLocaleString()}</td>
                <td>$${data.cost.toFixed(2)}</td>
                <td>${data.tasks_completed}</td>
            </tr>
        `).join('');

        html += `
            <table class="cost-table">
                <thead>
                    <tr>
                        <th>Agent</th>
                        <th>Tokens</th>
                        <th>Cost</th>
                        <th>Tasks</th>
                    </tr>
                </thead>
                <tbody>${agentRows}</tbody>
            </table>
        `;
    }

    document.getElementById('analytics-cost').innerHTML = html;
}

function renderTrends(trendsData) {
    if (!trendsData || !trendsData.trends) {
        document.getElementById('analytics-trends').innerHTML = '<p class="error">Failed to load trends</p>';
        return;
    }

    const trends = trendsData.trends;
    if (trends.length === 0) {
        document.getElementById('analytics-trends').innerHTML = '<p class="info">No trend data available</p>';
        return;
    }

    // Simple text-based trend display (can be enhanced with charting library later)
    const html = trends.map(day => `
        <div class="trend-row">
            <span class="trend-day">${day.day}</span>
            <span class="trend-completed">${day.completed} completed</span>
            <span class="trend-failed">${day.failed} failed</span>
            <span class="trend-errors">${day.errors} errors</span>
            <span class="trend-duration">${Math.round(day.avg_duration)}ms avg</span>
        </div>
    `).join('');

    document.getElementById('analytics-trends').innerHTML = `
        <h3>Daily Trends (Last ${trendsData.days} Days)</h3>
        <div class="trend-list">${html}</div>
    `;
}

// ============================================================
// Main Dashboard Update
// ============================================================

async function updateAnalyticsDashboard() {
    const [summary, agents, errors, cost, trends] = await Promise.all([
        fetchAnalyticsSummary(),
        fetchAnalyticsAgents(),
        fetchAnalyticsErrors(),
        fetchAnalyticsCost(),
        fetchAnalyticsTrends(),
    ]);

    renderSummaryCard(summary);
    renderAgentCards(agents);
    renderErrorDistribution(errors);
    renderCostMetrics(cost);
    renderTrends(trends);
}

// ============================================================
// Initialization
// ============================================================

function initAnalyticsDashboard() {
    // Initial load
    updateAnalyticsDashboard();

    // Auto-refresh
    setInterval(updateAnalyticsDashboard, ANALYTICS_CONFIG.refreshInterval);
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAnalyticsDashboard);
} else {
    initAnalyticsDashboard();
}

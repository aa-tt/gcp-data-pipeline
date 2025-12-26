import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import './App.css';

function App() {
  const [formData, setFormData] = useState({
    dataType: 'user_event',
    userId: '',
    eventName: '',
    properties: '{}',
  });
  const [response, setResponse] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Analytics state
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [analyticsData, setAnalyticsData] = useState(null);
  const [analyticsLoading, setAnalyticsLoading] = useState(false);
  const [analyticsError, setAnalyticsError] = useState(null);
  const [pollingInterval, setPollingInterval] = useState(null);

  // Get API URLs from environment variables
  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080';
  const ANALYTICS_URL = import.meta.env.VITE_ANALYTICS_URL || 'http://localhost:8081';

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const fetchAnalytics = async () => {
    try {
      setAnalyticsLoading(true);
      setAnalyticsError(null);
      
      const result = await axios.get(`${ANALYTICS_URL}?days=7&limit=50`, {
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (result.data.success) {
        setAnalyticsData(result.data);
      } else {
        setAnalyticsError(result.data.message || 'Failed to fetch analytics');
      }
    } catch (err) {
      console.error('Analytics error:', err);
      setAnalyticsError(err.response?.data?.message || err.message || 'Failed to fetch analytics');
    } finally {
      setAnalyticsLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setResponse(null);

    try {
      // Parse properties JSON
      let properties = {};
      try {
        properties = JSON.parse(formData.properties);
      } catch (err) {
        throw new Error('Invalid JSON in properties field');
      }

      // Prepare payload
      const payload = {
        data_type: formData.dataType,
        payload: {
          user_id: formData.userId,
          event_name: formData.eventName,
          timestamp: new Date().toISOString(),
          ...properties, // Merge properties at root level for PySpark compatibility
        },
      };

      console.log('Sending request to:', API_URL);
      console.log('Payload:', payload);

      const result = await axios.post(API_URL, payload, {
        headers: {
          'Content-Type': 'application/json',
        },
      });

      setResponse(result.data);
      console.log('Success:', result.data);
      
      // Show analytics section and start polling
      setShowAnalytics(true);
      
      // Initial fetch after 5 seconds
      setTimeout(() => {
        fetchAnalytics();
      }, 5000);
      
      // Set up polling every 10 seconds
      const interval = setInterval(fetchAnalytics, 10000);
      setPollingInterval(interval);
      
    } catch (err) {
      console.error('Error:', err);
      setError(err.response?.data?.error || err.message || 'Failed to send data');
    } finally {
      setLoading(false);
    }
  };

  const loadSampleData = () => {
    const amount = (Math.random() * 1000).toFixed(2);
    const productId = 'PROD-' + Math.floor(Math.random() * 1000);
    
    setFormData({
      dataType: 'user_event',
      userId: 'user_' + Math.random().toString(36).substr(2, 9),
      eventName: 'purchase',
      properties: JSON.stringify({
        page: '/checkout',
        referrer: '/cart',
        device: 'desktop',
        browser: 'chrome',
        amount: parseFloat(amount),
        product_id: productId,
        quantity: Math.floor(Math.random() * 5) + 1,
        transaction_id: 'TXN-' + Math.floor(Math.random() * 100000),
      }, null, 2),
    });
  };

  const stopPolling = () => {
    if (pollingInterval) {
      clearInterval(pollingInterval);
      setPollingInterval(null);
    }
  };

  useEffect(() => {
    // Cleanup polling on unmount
    return () => {
      if (pollingInterval) {
        clearInterval(pollingInterval);
      }
    };
  }, [pollingInterval]);

  // Prepare chart data
  const getChartData = () => {
    if (!analyticsData?.daily_metrics) return [];
    
    const metricsMap = {};
    analyticsData.daily_metrics.forEach(metric => {
      if (!metricsMap[metric.metric_date]) {
        metricsMap[metric.metric_date] = {
          date: metric.metric_date,
          total_amount: 0,
          total_transactions: 0,
        };
      }
      // Sum up value (amount) and count (transactions) from daily_metrics
      if (metric.metric_name === 'total_amount') {
        metricsMap[metric.metric_date].total_amount += parseFloat(metric.value || 0);
        metricsMap[metric.metric_date].total_transactions += parseInt(metric.count || 0);
      }
    });
    
    return Object.values(metricsMap).sort((a, b) => a.date.localeCompare(b.date));
  };

  return (
    <div className="App">
      <div className="container">
        <header>
          <h1>🚀 Data Pipeline Ingestion</h1>
          <p>Send data to GCP Cloud Function for processing</p>
        </header>

        <form onSubmit={handleSubmit} className="ingestion-form">
          <div className="form-group">
            <label htmlFor="dataType">Data Type</label>
            <select
              id="dataType"
              name="dataType"
              value={formData.dataType}
              onChange={handleInputChange}
              required
            >
              <option value="user_event">User Event</option>
              <option value="transaction">Transaction</option>
              <option value="system_log">System Log</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="userId">User ID</label>
            <input
              type="text"
              id="userId"
              name="userId"
              value={formData.userId}
              onChange={handleInputChange}
              placeholder="e.g., user_12345"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="eventName">Event Name</label>
            <input
              type="text"
              id="eventName"
              name="eventName"
              value={formData.eventName}
              onChange={handleInputChange}
              placeholder="e.g., page_view, purchase, login"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="properties">Properties (JSON)</label>
            <textarea
              id="properties"
              name="properties"
              value={formData.properties}
              onChange={handleInputChange}
              placeholder='{"key": "value"}'
              rows="6"
            />
          </div>

          <div className="form-actions">
            <button type="button" onClick={loadSampleData} className="btn-secondary">
              Load Sample Data
            </button>
            <button type="submit" disabled={loading} className="btn-primary">
              {loading ? 'Sending...' : 'Send Data'}
            </button>
          </div>
        </form>

        {error && (
          <div className="alert alert-error">
            <strong>Error:</strong> {error}
          </div>
        )}

        {response && (
          <div className="alert alert-success">
            <strong>Success!</strong> Data ingested successfully.
            <pre>{JSON.stringify(response, null, 2)}</pre>
          </div>
        )}

        {showAnalytics && (
          <div className="analytics-section">
            <div className="analytics-header">
              <h2>📊 Pipeline Analytics</h2>
              <div className="analytics-controls">
                <button onClick={fetchAnalytics} disabled={analyticsLoading} className="btn-secondary">
                  {analyticsLoading ? 'Refreshing...' : '🔄 Refresh'}
                </button>
                <button onClick={stopPolling} className="btn-secondary">
                  {pollingInterval ? '⏸ Stop Auto-Refresh' : '▶️ Start Auto-Refresh'}
                </button>
              </div>
            </div>

            {analyticsLoading && !analyticsData && (
              <div className="loading-spinner">
                <p>⏳ Loading analytics data from BigQuery...</p>
                <p className="small-text">This may take a few moments while the pipeline processes your data</p>
              </div>
            )}

            {analyticsError && (
              <div className="alert alert-error">
                <strong>Analytics Error:</strong> {analyticsError}
              </div>
            )}

            {analyticsData && (
              <>
                {/* Summary Stats */}
                <div className="stats-grid">
                  <div className="stat-card">
                    <div className="stat-value">{analyticsData.summary?.total_records || 0}</div>
                    <div className="stat-label">Total Records</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-value">{analyticsData.summary?.unique_users || 0}</div>
                    <div className="stat-label">Unique Users</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-value">{analyticsData.summary?.unique_products || 0}</div>
                    <div className="stat-label">Unique Products</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-value">
                      ${parseFloat(analyticsData.summary?.total_revenue || 0).toFixed(2)}
                    </div>
                    <div className="stat-label">Total Revenue</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-value">
                      ${parseFloat(analyticsData.summary?.avg_transaction_amount || 0).toFixed(2)}
                    </div>
                    <div className="stat-label">Avg Transaction</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-value">
                      {analyticsData.summary?.latest_event 
                        ? new Date(analyticsData.summary.latest_event).toLocaleString()
                        : 'N/A'}
                    </div>
                    <div className="stat-label">Latest Event</div>
                  </div>
                </div>

                {/* Charts */}
                {getChartData().length > 0 && (
                  <div className="charts-section">
                    <div className="chart-card">
                      <h3>Daily Revenue Trend</h3>
                      <ResponsiveContainer width="100%" height={300}>
                        <LineChart data={getChartData()}>
                          <CartesianGrid strokeDasharray="3 3" />
                          <XAxis dataKey="date" />
                          <YAxis />
                          <Tooltip />
                          <Legend />
                          <Line type="monotone" dataKey="total_amount" stroke="#8884d8" name="Revenue ($)" />
                        </LineChart>
                      </ResponsiveContainer>
                    </div>

                    <div className="chart-card">
                      <h3>Daily Transactions</h3>
                      <ResponsiveContainer width="100%" height={300}>
                        <BarChart data={getChartData()}>
                          <CartesianGrid strokeDasharray="3 3" />
                          <XAxis dataKey="date" />
                          <YAxis />
                          <Tooltip />
                          <Legend />
                          <Bar dataKey="total_transactions" fill="#82ca9d" name="Transactions" />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                )}

                {/* Recent Analytics Data */}
                <div className="table-section">
                  <h3>Recent Analytics Data</h3>
                  <div className="table-container">
                    <table>
                      <thead>
                        <tr>
                          <th>User ID</th>
                          <th>Product ID</th>
                          <th>Amount</th>
                          <th>Event Date</th>
                          <th>Event Time</th>
                        </tr>
                      </thead>
                      <tbody>
                        {analyticsData.analytics_data?.slice(0, 10).map((row, idx) => (
                          <tr key={idx}>
                            <td>{row.user_id || 'N/A'}</td>
                            <td>{row.product_id || 'N/A'}</td>
                            <td>${parseFloat(row.amount || 0).toFixed(2)}</td>
                            <td>{row.event_date || 'N/A'}</td>
                            <td>{row.event_timestamp ? new Date(row.event_timestamp).toLocaleTimeString() : 'N/A'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>

                {/* Daily Metrics */}
                {analyticsData.daily_metrics?.length > 0 && (
                  <div className="table-section">
                    <h3>Daily Metrics</h3>
                    <div className="table-container">
                      <table>
                        <thead>
                          <tr>
                            <th>Date</th>
                            <th>Metric Name</th>
                            <th>Dimension</th>
                            <th>Value</th>
                            <th>Count</th>
                          </tr>
                        </thead>
                        <tbody>
                          {analyticsData.daily_metrics?.slice(0, 10).map((row, idx) => (
                            <tr key={idx}>
                              <td>{row.metric_date || 'N/A'}</td>
                              <td>{row.metric_name || 'N/A'}</td>
                              <td>{row.dimension || 'N/A'}</td>
                              <td>${parseFloat(row.value || 0).toFixed(2)}</td>
                              <td>{row.count || 0}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;

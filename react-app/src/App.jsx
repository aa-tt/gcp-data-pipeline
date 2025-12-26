import React, { useState } from 'react';
import axios from 'axios';
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

  // Get API URL from environment variable or default to local
  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080';

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
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
          properties: properties,
          timestamp: new Date().toISOString(),
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
    } catch (err) {
      console.error('Error:', err);
      setError(err.response?.data?.error || err.message || 'Failed to send data');
    } finally {
      setLoading(false);
    }
  };

  const loadSampleData = () => {
    setFormData({
      dataType: 'user_event',
      userId: 'user_' + Math.random().toString(36).substr(2, 9),
      eventName: 'page_view',
      properties: JSON.stringify({
        page: '/dashboard',
        referrer: '/home',
        device: 'desktop',
        browser: 'chrome',
      }, null, 2),
    });
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
              <option value="sensor_data">Sensor Data</option>
              <option value="log_event">Log Event</option>
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
              placeholder="user_123456"
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
              placeholder="page_view, click, purchase, etc."
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
              required
            />
          </div>

          <div className="button-group">
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
            <strong>Success!</strong>
            <pre>{JSON.stringify(response, null, 2)}</pre>
          </div>
        )}

        <div className="info-box">
          <h3>ℹ️ Information</h3>
          <p><strong>API Endpoint:</strong> <code>{API_URL}</code></p>
          <p>This application sends data to the GCP Cloud Function which publishes to Pub/Sub for processing.</p>
        </div>
      </div>
    </div>
  );
}

export default App;

import React, { useEffect, useState } from 'react';
// Import the web component - it registers itself as a custom element
import '@authid/web-component';

function AuthIDEnrollment() {
  const [status, setStatus] = useState('loading');
  const [error, setError] = useState(null);
  const [params, setParams] = useState({});

  useEffect(() => {
    // Get parameters from URL
    const urlParams = new URLSearchParams(window.location.search);
    const operationId = urlParams.get('operationId');
    const secret = urlParams.get('secret');
    const baseUrl = urlParams.get('baseUrl') || 'https://id-uat.authid.ai';

    console.log('🔐 AuthID Enrollment Initialization');
    console.log('Operation ID:', operationId);
    console.log('Secret:', secret ? '***' : 'missing');
    console.log('Base URL:', baseUrl);

    if (!operationId || !secret) {
      setStatus('error');
      setError('Operation ID and Secret are required');
      setParams({ operationId, secret, baseUrl });
      return;
    }

    // Construct the full operation URL for the web component
    // The web component expects the base URL with operation parameters
    const operationURL = `${baseUrl}/?operationId=${operationId}&secret=${secret}`;
    
    setParams({
      operationId,
      secret,
      baseUrl,
      operationURL
    });
    
    setStatus('ready');
    console.log('📋 AuthID Operation URL:', operationURL);
  }, []);

  const handleControl = (msg, authidControlFace) => {
    console.log('🎮 AuthID Control Message:', msg);

    // Handle success
    if (msg.type === 'success' || msg.status === 'completed') {
      console.log('✅ Enrollment successful');
      setStatus('success');
      
      // Notify iOS app if using WKWebView
      if (window.webkit?.messageHandlers?.enrollmentComplete) {
        window.webkit.messageHandlers.enrollmentComplete.postMessage({
          success: true,
          operationId: params.operationId
        });
      }
    }

    // Handle error
    if (msg.type === 'error' || msg.status === 'failed') {
      console.error('❌ Enrollment error:', msg);
      setStatus('error');
      setError(msg.error || msg.message || 'An error occurred during enrollment');
      
      // Notify iOS app of error
      if (window.webkit?.messageHandlers?.enrollmentError) {
        window.webkit.messageHandlers.enrollmentError.postMessage({
          error: msg.error || msg.message
        });
      }
    }

    // Handle cancel
    if (msg.type === 'cancel' || msg.status === 'cancelled') {
      console.log('⚠️ Enrollment cancelled');
      setStatus('cancelled');
    }
  };

  // Render different states
  if (status === 'loading') {
    return (
      <div className="container">
        <div className="card info">
          <h2>📋 Loading...</h2>
          <p>Initializing enrollment...</p>
        </div>
      </div>
    );
  }

  if (status === 'error' && !params.operationId) {
    return (
      <div className="container">
        <div className="card error">
          <h2>⚠️ Missing Parameters</h2>
          <p>Operation ID and Secret are required for enrollment.</p>
          <p>Please restart the enrollment process from the BBMS app.</p>
          <div className="params-display">
            <div><strong>Operation ID:</strong> {params.operationId || 'Missing'}</div>
            <div><strong>Secret:</strong> {params.secret ? 'Provided' : 'Missing'}</div>
          </div>
        </div>
      </div>
    );
  }

  if (status === 'success') {
    return (
      <div className="container">
        <div className="card success">
          <h2>✅ Enrollment Complete!</h2>
          <p>Your biometric authentication has been set up successfully.</p>
          <p><strong>You can now close this window and return to the BBMS app.</strong></p>
          <button onClick={() => window.close()}>Close Window</button>
        </div>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="container">
        <div className="card error">
          <h2>❌ Enrollment Failed</h2>
          <p><strong>Error:</strong> {error}</p>
          <p>Please try again or contact support if the problem persists.</p>
          <div className="params-display">
            <div><strong>Operation ID:</strong> {params.operationId}</div>
            <div><strong>Operation URL:</strong> {params.operationURL}</div>
          </div>
          <button onClick={() => window.location.reload()}>Try Again</button>
        </div>
      </div>
    );
  }

  if (status === 'cancelled') {
    return (
      <div className="container">
        <div className="card info">
          <h2>Enrollment Cancelled</h2>
          <p>You cancelled the enrollment process.</p>
          <p>You can close this window or try again.</p>
          <button onClick={() => window.location.reload()}>Try Again</button>
        </div>
      </div>
    );
  }

  // Create and mount the AuthID web component
  useEffect(() => {
    if (status === 'ready' && params.operationURL) {
      const container = document.getElementById('authid-container');
      if (container) {
        console.log('📦 Creating authid-component element...');
        console.log('customElements.get before:', customElements.get('authid-component'));
        
        // Create the custom element
        const authidElement = document.createElement('authid-component');
        authidElement.setAttribute('data-url', params.operationURL);
        authidElement.setAttribute('data-target', 'auto');
        authidElement.setAttribute('data-webauth', 'true');
        authidElement.setAttribute('data-control', 'true');
        
        // Listen for load event
        authidElement.addEventListener('load', () => {
          console.log('🎬 AuthID component loaded');
        });
        
        // Append to container
        container.appendChild(authidElement);
        console.log('✅ authid-component appended:', authidElement);
        console.log('customElements.get after:', customElements.get('authid-component'));
        
        // Cleanup
        return () => {
          if (container.contains(authidElement)) {
            container.removeChild(authidElement);
          }
        };
      }
    }
  }, [status, params.operationURL]);

  // Render container for AuthID Web Component (for ready state)
  if (status === 'ready') {
    return (
      <div className="container">
        <div className="authid-wrapper">
          <div id="authid-container" style={{ width: '100%', height: '100%' }}></div>
        </div>
      </div>
    );
  }

  // Fallback
  return null;
}

export default AuthIDEnrollment;

# AuthID Biometric Login Implementation Guide

## Current Status

### ✅ What Works:
- Biometric enrollment with AuthID hosted web component
- Biometrics stored on AuthID servers (not locally)
- User account linked to AuthID `AccountNumber`

### ❌ What's Missing:
- Biometric login/verification flow
- Operation to verify returning user's biometric
- Login endpoint that uses AuthID verification

---

## Architecture

### Enrollment Flow (DONE ✅)
```
iOS App → Backend API → AuthID API (create operation)
                    ↓
              Web Component URL
                    ↓
         User takes selfie in Safari
                    ↓
         AuthID stores biometric template
                    ↓
         verifiedPage message → Complete
```

### Login Flow (NEEDS IMPLEMENTATION ⚠️)
```
iOS App → Backend API → AuthID API (create verification operation)
                    ↓
              Web Component URL
                    ↓
         User takes selfie in Safari
                    ↓
         AuthID compares with stored template
                    ↓
         Match/No Match → Login Success/Fail
```

---

## Implementation Plan

### 1. Create Biometric Login Initiation Method

Add to `auth/src/services/authIdService.js`:

```javascript
/**
 * Initiate biometric login/verification
 * Creates an AuthID operation to verify user's identity via biometric
 */
async initiateBiometricLogin(userId) {
  try {
    logger.info('🔐 Initiating REAL AuthID biometric login', { userId });

    // Create verification operation
    const operationData = {
      AccountNumber: userId,
      Codeword: "",
      Name: "VerifyBioCredential", // Different from enrollment!
      Timeout: 300, // 5 minutes for login
      TransportType: 0,
      Tag: `bbms-login-${Date.now()}`
    };

    logger.info('📤 Creating biometric verification operation', { 
      url: `${this.transactionURL}/v2/operations`,
      userId 
    });

    const operationResponse = await axios.post(
      `${this.transactionURL}/v2/operations`,
      operationData,
      { headers: await this.getAuthHeaders() }
    );

    const operationId = operationResponse.data.OperationId;
    const oneTimeSecret = operationResponse.data.OneTimeSecret;
    
    // Construct verification URL (same web component, different operation)
    const verificationWebUrl = process.env.AUTHID_WEB_URL || 'http://localhost:3002';
    const verificationUrl = `${verificationWebUrl}/verify?operationId=${operationId}&secret=${oneTimeSecret}&baseUrl=${encodeURIComponent('https://id-uat.authid.ai')}`;
    
    logger.info('✅ AuthID login operation created', { 
      operationId,
      userId,
      verificationUrl
    });

    return {
      success: true,
      operationId: operationId,
      verificationUrl: verificationUrl,
      qrCode: verificationUrl,
      oneTimeSecret: oneTimeSecret,
      expiresAt: new Date(Date.now() + 300 * 1000).toISOString() // 5 minutes
    };

  } catch (error) {
    logger.error('❌ Failed to initiate AuthID login', { 
      error: error.message,
      response: error.response?.data,
      userId 
    });
    
    throw new Error(`AuthID login initiation failed: ${error.message}`);
  }
}
```

### 2. Create Login Endpoint

Add to `auth/src/routes/biometricRoutes.js`:

```javascript
/**
 * POST /api/biometric/login/initiate
 * Start biometric login process
 */
router.post('/login/initiate', async (req, res) => {
  try {
    const { email, userId } = req.body;
    
    logger.info('🔐 Initiating biometric login', { email, userId });
    
    // Find user by email or userId
    let user;
    if (email) {
      user = await userService.getUserByEmail(email);
    } else if (userId) {
      user = await userService.getUserById(userId);
    }
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }
    
    // Check if user has biometric enrolled
    if (!user.biometric_enrolled || user.biometric_status !== 'completed') {
      return res.status(400).json({
        error: 'Biometric not enrolled',
        code: 'NOT_ENROLLED',
        message: 'Please enroll your biometric first'
      });
    }
    
    // Create AuthID verification operation
    const loginOperation = await authIdService.initiateBiometricLogin(user.id);
    
    // Store operation ID for later verification
    await userService.updateUser(user.id, {
      pending_login_operation: loginOperation.operationId
    });
    
    logger.info('✅ Biometric login initiated', { 
      userId: user.id,
      operationId: loginOperation.operationId 
    });
    
    res.json({
      success: true,
      userId: user.id,
      operationId: loginOperation.operationId,
      verificationUrl: loginOperation.verificationUrl,
      qrCode: loginOperation.qrCode,
      expiresAt: loginOperation.expiresAt
    });
    
  } catch (error) {
    logger.error('❌ Failed to initiate biometric login', { 
      error: error.message 
    });
    
    res.status(500).json({
      error: 'Login initiation failed',
      message: error.message
    });
  }
});

/**
 * POST /api/biometric/login/verify/:operationId
 * Verify biometric login operation and issue JWT token
 */
router.post('/login/verify/:operationId', async (req, res) => {
  try {
    const { operationId } = req.params;
    
    logger.info('🔍 Verifying biometric login operation', { operationId });
    
    // Check operation status with AuthID
    let authIdStatus;
    try {
      authIdStatus = await authIdService.checkOperationStatus(operationId);
    } catch (error) {
      // If 404, operation might still be pending (UAT sync lag)
      if (error.message.includes('404')) {
        return res.json({
          success: false,
          status: 'pending',
          message: 'Verification in progress'
        });
      }
      throw error;
    }
    
    // Check if verification completed successfully
    if (authIdStatus.state === 1 && authIdStatus.result === 1) {
      // SUCCESS - User verified!
      const userId = authIdStatus.accountNumber;
      const user = await userService.getUserById(userId);
      
      if (!user) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }
      
      // Generate JWT token
      const token = jwt.sign(
        { 
          userId: user.id, 
          email: user.email,
          role: user.role 
        },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
      );
      
      // Update last login
      await userService.updateUser(user.id, {
        last_login: new Date().toISOString(),
        pending_login_operation: null
      });
      
      logger.info('✅ Biometric login successful', { 
        userId: user.id,
        operationId 
      });
      
      return res.json({
        success: true,
        status: 'verified',
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        }
      });
    } 
    else if (authIdStatus.state === 2 || authIdStatus.result === 2) {
      // FAILED - No match or failed verification
      logger.warn('❌ Biometric verification failed', { 
        operationId,
        state: authIdStatus.state,
        result: authIdStatus.result
      });
      
      return res.status(401).json({
        success: false,
        status: 'failed',
        error: 'Biometric verification failed',
        message: 'Face did not match enrolled biometric'
      });
    }
    else {
      // PENDING - Still verifying
      return res.json({
        success: false,
        status: 'pending',
        message: 'Verification in progress'
      });
    }
    
  } catch (error) {
    logger.error('❌ Biometric login verification error', { 
      error: error.message,
      operationId: req.params.operationId 
    });
    
    res.status(500).json({
      error: 'Verification failed',
      message: error.message
    });
  }
});
```

### 3. Create Verification Web Page

Create `authid-web/public/verify.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Biometric Login - BBMS</title>
    <script src="https://cdn.authid.ai/sdk/web/v4/authid-web-component.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        
        #app-container {
            background: white;
            border-radius: 16px;
            padding: 32px;
            max-width: 600px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        
        h1 {
            color: #667eea;
            margin-top: 0;
        }
        
        .status {
            padding: 12px;
            border-radius: 8px;
            margin: 16px 0;
            font-weight: 500;
        }
        
        .status.pending { background: #fef3c7; color: #92400e; }
        .status.success { background: #d1fae5; color: #065f46; }
        .status.error { background: #fee2e2; color: #991b1b; }
    </style>
</head>
<body>
    <div id="app-container">
        <h1>🔐 Biometric Login</h1>
        <div id="status" class="status pending">
            Please complete facial verification to log in...
        </div>
        <div id="authid-container"></div>
    </div>

    <script>
        console.log('🔐 AuthID Biometric Login');
        
        // Get parameters from URL
        const urlParams = new URLSearchParams(window.location.search);
        const operationId = urlParams.get('operationId');
        const secret = urlParams.get('secret');
        const baseUrl = urlParams.get('baseUrl') || 'https://id-uat.authid.ai';
        
        console.log('Operation ID:', operationId);
        console.log('Base URL:', baseUrl);
        
        const container = document.getElementById('authid-container');
        
        if (!operationId || !secret) {
            container.innerHTML = '<div class="status error">Missing operation parameters</div>';
        } else {
            // Create AuthID web component
            const authidURL = `${baseUrl}/?OperationId=${operationId}&OneTimeSecret=${secret}`;
            console.log('AuthID URL:', authidURL);
            
            const authidElement = document.createElement('authid-web-component');
            authidElement.setAttribute('url', authidURL);
            authidElement.style.width = '100%';
            authidElement.style.height = '600px';
            
            // Listen for completion
            window.addEventListener('message', async (event) => {
                console.log('📨 Message received:', event.data);
                
                // Check for verification completion
                if (event.data && event.data.type === 'authid:page' && 
                    event.data.pageName === 'verifiedPage' && event.data.success === true) {
                    console.log('✅ Verification completed!');
                    
                    document.getElementById('status').className = 'status pending';
                    document.getElementById('status').textContent = 'Verifying your identity...';
                    
                    // Poll for verification result
                    await pollVerificationResult();
                }
            });
            
            container.appendChild(authidElement);
        }
        
        async function pollVerificationResult() {
            const maxAttempts = 30; // 30 * 2 seconds = 60 seconds max
            let attempts = 0;
            
            const poll = setInterval(async () => {
                attempts++;
                
                try {
                    const response = await fetch(
                        `${window.location.protocol}//${window.location.hostname}:3001/api/biometric/login/verify/${operationId}`,
                        { method: 'POST' }
                    );
                    
                    const data = await response.json();
                    console.log('Verification result:', data);
                    
                    if (data.status === 'verified' && data.token) {
                        clearInterval(poll);
                        showSuccess(data.token, data.user);
                    } else if (data.status === 'failed') {
                        clearInterval(poll);
                        showError('Verification failed. Please try again.');
                    } else if (attempts >= maxAttempts) {
                        clearInterval(poll);
                        showError('Verification timeout. Please try again.');
                    }
                } catch (error) {
                    console.error('Polling error:', error);
                    if (attempts >= maxAttempts) {
                        clearInterval(poll);
                        showError('Connection error. Please try again.');
                    }
                }
            }, 2000); // Poll every 2 seconds
        }
        
        function showSuccess(token, user) {
            document.getElementById('status').className = 'status success';
            document.getElementById('status').innerHTML = `
                ✅ Login successful!<br>
                Welcome back, ${user.name}!<br><br>
                <small>Redirecting to app...</small>
            `;
            
            // Store token and redirect
            // Option 1: Pass to iOS app via URL scheme
            setTimeout(() => {
                window.location.href = `bbms://login?token=${encodeURIComponent(token)}`;
            }, 2000);
            
            // Option 2: Close webview and pass token via JavaScript bridge
            // if (window.webkit?.messageHandlers?.loginSuccess) {
            //     window.webkit.messageHandlers.loginSuccess.postMessage({ token, user });
            // }
        }
        
        function showError(message) {
            document.getElementById('status').className = 'status error';
            document.getElementById('status').textContent = `❌ ${message}`;
        }
    </script>
</body>
</html>
```

---

## iOS App Integration

### Login Flow:

```swift
// 1. User opens app and selects biometric login
func startBiometricLogin(email: String) {
    // Call backend to initiate login
    let url = URL(string: "\(authServiceURL)/api/biometric/login/initiate")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONEncoder().encode(["email": email])
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data else { return }
        
        if let result = try? JSONDecoder().decode(LoginInitResponse.self, from: data) {
            // Open verification URL in WKWebView
            DispatchQueue.main.async {
                self.openVerificationWebView(url: result.verificationUrl)
            }
        }
    }.resume()
}

// 2. Open web component for verification
func openVerificationWebView(url: String) {
    let webView = WKWebView()
    
    // Handle URL scheme callback with token
    webView.navigationDelegate = self
    
    // Load verification URL
    if let url = URL(string: url) {
        webView.load(URLRequest(url: url))
    }
    
    // Present webview
    present(webView, animated: true)
}

// 3. Receive token and log in
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) {
    if let url = navigationAction.request.url,
       url.scheme == "bbms",
       url.host == "login",
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
        
        // Store token
        UserDefaults.standard.set(token, forKey: "authToken")
        
        // Dismiss webview
        webView.dismiss(animated: true) {
            // Navigate to main app
            self.navigateToMainScreen()
        }
    }
}
```

---

## Testing Checklist

### Enrollment (Already Working ✅)
1. ✅ User enrolls biometric from iOS app
2. ✅ Takes selfie in Safari web component
3. ✅ Enrollment completes and saves to AuthID

### Login (New Flow ⚠️)
1. ⚠️ User opens app and selects "Login with Face ID"
2. ⚠️ Backend creates verification operation
3. ⚠️ iOS opens verification URL in webview
4. ⚠️ User takes selfie for verification
5. ⚠️ AuthID compares with stored template
6. ⚠️ If match: Returns JWT token → User logged in
7. ⚠️ If no match: Shows error → User tries again

---

## Security Considerations

### ✅ Best Practices:
- Biometric templates stored on AuthID servers (not locally)
- One-time secrets for each operation
- Operation timeout (5 minutes for login)
- JWT token generation only after successful verification
- HTTPS for all communication

### ⚠️ Additional Recommendations:
- Add rate limiting to prevent brute force attempts
- Log all verification attempts for audit trail
- Implement account lockout after multiple failed attempts
- Use refresh tokens for long-term sessions

---

## Next Steps

1. **Implement methods** in `authIdService.js`
2. **Add routes** in `biometricRoutes.js`
3. **Create verify.html** page
4. **Update iOS app** to use login flow
5. **Test** end-to-end login process

Would you like me to implement these changes now?

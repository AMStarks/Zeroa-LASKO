# Decentralized Server Infrastructure Specification

## 🏗️ Server Architecture Overview

### **Core Components:**

1. **Message Relay Nodes** (Multiple instances)
2. **Peer Discovery Service**
3. **Encryption/Decryption Service**
4. **Message Queue System**
5. **Blockchain Integration Layer**

---

## 📋 **Server Requirements**

### **Hardware Specifications:**
- **CPU:** 4+ cores (ARM64 or x86_64)
- **RAM:** 8GB+ (16GB recommended)
- **Storage:** 100GB+ SSD
- **Network:** 100Mbps+ bandwidth
- **OS:** Ubuntu 22.04 LTS or Docker

### **Software Stack:**
```
┌─────────────────────────────────────┐
│           Load Balancer            │
│         (Nginx/Traefik)            │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         API Gateway                │
│      (Kong/FastAPI)               │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│      Message Relay Service         │
│      (Node.js/Python)              │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│      Database Layer                │
│   (PostgreSQL + Redis)             │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│      Blockchain Integration        │
│      (TLS API Client)              │
└─────────────────────────────────────┘
```

---

## 🔧 **Implementation Details**

### **1. Message Relay Service**
```python
# message_relay.py
class MessageRelayService:
    def __init__(self):
        self.active_connections = {}
        self.message_queue = Redis()
        self.encryption_service = EncryptionService()
    
    async def relay_message(self, from_address: str, to_address: str, encrypted_content: str):
        # Store message for offline users
        # Route to online users via P2P
        # Fallback to blockchain if needed
        pass
    
    async def handle_peer_discovery(self, address: str, public_key: str):
        # Register peer for discovery
        # Update online status
        pass
```

### **2. API Endpoints**
```python
# api_routes.py
@app.post("/api/v1/message/relay")
async def relay_message(request: MessageRequest):
    # Relay encrypted message to recipient
    pass

@app.get("/api/v1/peers/discover")
async def discover_peers(address: str):
    # Return list of online peers
    pass

@app.post("/api/v1/peer/register")
async def register_peer(request: PeerRegistration):
    # Register peer for discovery
    pass
```

### **3. Database Schema**
```sql
-- messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    sender_address VARCHAR(255),
    receiver_address VARCHAR(255),
    encrypted_content TEXT,
    message_type VARCHAR(50),
    timestamp TIMESTAMP,
    delivered BOOLEAN DEFAULT FALSE,
    blockchain_txid VARCHAR(255)
);

-- peers table
CREATE TABLE peers (
    address VARCHAR(255) PRIMARY KEY,
    public_key TEXT,
    last_seen TIMESTAMP,
    is_online BOOLEAN DEFAULT FALSE,
    connection_info JSONB
);
```

---

## 🚀 **Deployment Options**

### **Option 1: Cloud Deployment**
- **AWS/GCP/Azure:** Auto-scaling, managed databases
- **Cost:** $200-500/month for production
- **Setup:** 2-4 hours

### **Option 2: VPS Deployment**
- **Provider:** DigitalOcean, Linode, Vultr
- **Cost:** $50-100/month
- **Setup:** 1-2 hours

### **Option 3: Self-Hosted**
- **Hardware:** Dedicated server or home setup
- **Cost:** $20-50/month
- **Setup:** 4-8 hours

---

## 📊 **Performance Requirements**

### **Message Throughput:**
- **Target:** 10,000+ messages/second
- **Latency:** <100ms for relay
- **Uptime:** 99.9% availability

### **Scalability:**
- **Horizontal scaling:** Multiple relay nodes
- **Load balancing:** Automatic failover
- **Database:** Read replicas for high availability

---

## 🔐 **Security Requirements**

### **Encryption:**
- **Transport:** TLS 1.3 for all connections
- **Message:** End-to-end encryption (AES-256)
- **Keys:** RSA-2048 for key exchange

### **Authentication:**
- **API Keys:** For service authentication
- **Digital Signatures:** For message verification
- **Rate Limiting:** Prevent abuse

---

## 📱 **Client Integration**

### **iOS App Updates Needed:**
```swift
// Add to TLSLayer2MessagingService.swift
class RealP2PService {
    private let relayServer = "https://your-relay-server.com"
    
    func sendMessageViaRelay(to: String, content: String) async -> Bool {
        // Encrypt message
        // Send to relay server
        // Handle response
    }
    
    func discoverPeers() async -> [Peer] {
        // Query relay server for online peers
        // Return list of available peers
    }
}
```

---

## 🎯 **Next Steps**

1. **Choose deployment option** (I recommend Option 2: VPS)
2. **Set up server infrastructure**
3. **Implement relay service**
4. **Update iOS app for real P2P**
5. **Test end-to-end messaging**

**Estimated Timeline:** 2-3 weeks for full implementation 
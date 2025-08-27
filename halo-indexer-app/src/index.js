const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const winston = require('winston');
require('dotenv').config();

// Import services
const { initializeDatabase } = require('./database/connection');
const { initializeRedis } = require('./services/redis');
const { initializeSequentialCodeGenerator } = require('./services/sequentialCodeGenerator');
const { initializeTLSClient } = require('./services/tlsClient');
const { initializeTrinityManager } = require('./services/trinityManager');
const { initializeBatchManager } = require('./services/batchManager');
const { initializeCassandra } = require('./services/cassandra');

// Import routes
const postsRouter = require('./routes/posts');
const usersRouter = require('./routes/users');
const blocksRouter = require('./routes/blocks');
const healthRouter = require('./routes/health');
const subscriptionsRouter = require('./routes/subscriptions');
const trinityRouter = require('./routes/trinity');
const haloRouter = require('./routes/halo');
const { router: metricsRouter, trackApiRequest } = require('./routes/metrics');
const moderationRouter = require('./routes/moderation');
const { startCharterAutoRefresh } = require('./services/charter');

// Initialize logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'halo-indexer' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
  next();
});

// Metrics tracking middleware
app.use(trackApiRequest);

// Routes
app.use('/api/posts', postsRouter);
app.use('/api/users', usersRouter);
app.use('/api/blocks', blocksRouter);
app.use('/api/health', healthRouter);
app.use('/api/trinity', trinityRouter);
app.use('/api/halo', haloRouter);
app.use('/api/metrics', metricsRouter);
app.use('/api/moderation', moderationRouter);
app.use('/api/subscriptions', subscriptionsRouter);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'Halo Indexer',
    version: '1.0.0',
    status: 'running',
    description: 'Layer 1.5 Bridge for LASKO'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.originalUrl} not found`
  });
});

// Initialize services and start server
async function startServer() {
  try {
    logger.info('Starting Halo Indexer...');
    // Start charter auto-refresh before routes serve it
    startCharterAutoRefresh(logger);

    // Initialize database
    await initializeDatabase();
    logger.info('Database initialized');

    // Initialize Redis
    await initializeRedis();
    logger.info('Redis initialized');

    // Initialize sequential code generator
    await initializeSequentialCodeGenerator();
    logger.info('Sequential code generator initialized');

    // Initialize TLS client
    await initializeTLSClient();
    logger.info('TLS client initialized');

    // Initialize Trinity manager (lead + 2 slaves)
    await initializeTrinityManager();
    logger.info('Trinity manager initialized');

    // Initialize batch manager
    await initializeBatchManager();
    logger.info('Batch manager initialized');

    // Initialize Cassandra (optional - for persistent storage)
    if (process.env.CASSANDRA_ENABLED === 'true') {
      await initializeCassandra();
      logger.info('Cassandra initialized');
    }

    // Start server
    app.listen(PORT, () => {
      logger.info(`Halo Indexer running on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV}`);
      logger.info(`Node ID: ${process.env.NODE_ID || 'unknown'}`);
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start the server
startServer(); 
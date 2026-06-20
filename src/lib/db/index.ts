import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'

const connectionUrl = process.env.DATABASE_URL

if (!connectionUrl) {
  throw new Error(
    'DATABASE_URL environment variable is not set. Expected format: postgresql://user:password@host:port/database'
  )
}

const queryClient = postgres(connectionUrl, {
  max: Number(process.env.DB_POOL_MAX) || 20,
  idleTimeout: Number(process.env.DB_POOL_IDLE_TIMEOUT) || 30000,
  query_timeout: Number(process.env.DB_QUERY_TIMEOUT) || 30000,
  ssl: 'require',
  types: {
    bigint: postgres.BigInt,
  },
  ...(process.env.NODE_ENV === 'development' && {
    debug: console.log,
  }),
})

export const db = drizzle(queryClient, {
  logger: process.env.NODE_ENV === 'development',
})

process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing database connections...')
  try {
    await queryClient.end()
    process.exit(0)
  } catch (error) {
    console.error('Error closing database connections:', error)
    process.exit(1)
  }
})

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing database connections...')
  try {
    await queryClient.end()
    process.exit(0)
  } catch (error) {
    console.error('Error closing database connections:', error)
    process.exit(1)
  }
})

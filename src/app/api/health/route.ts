import { db } from '@/lib/db'
import { NextResponse } from 'next/server'

export async function GET() {
  try {
    await db.execute('SELECT 1')
    
    return NextResponse.json(
      {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV,
        region: process.env.HUAWEI_REGION || 'unknown',
      },
      { status: 200 }
    )
  } catch (error) {
    console.error('[Health Check Failed]', error)
    return NextResponse.json(
      {
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      },
      { status: 503 }
    )
  }
}

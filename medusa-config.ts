import { loadEnv, defineConfig } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

// Production : crash si les secrets ne sont pas définis
const isDev = process.env.NODE_ENV === 'development'

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: isDev
        ? (process.env.JWT_SECRET || "dev-only-secret-change-in-prod")
        : process.env.JWT_SECRET!,
      cookieSecret: isDev
        ? (process.env.COOKIE_SECRET || "dev-only-secret-change-in-prod")
        : process.env.COOKIE_SECRET!,
    }
  },
  modules: [
    // Cloudflare R2 / S3 file storage (activé si S3_FILE_URL est défini)
    ...(process.env.S3_FILE_URL ? [{
      resolve: "@medusajs/file",
      options: {
        providers: [
          {
            resolve: "@medusajs/file-s3",
            id: "s3",
            options: {
              fileUrl: process.env.S3_FILE_URL,
              accessKeyId: process.env.S3_ACCESS_KEY_ID,
              secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
              region: process.env.S3_REGION || "auto",
              bucket: process.env.S3_BUCKET,
              endpoint: process.env.S3_ENDPOINT,
            },
          },
        ],
      },
    }] : []),
  ],
})

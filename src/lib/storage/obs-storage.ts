import { GetObjectCommand, PutObjectCommand, DeleteObjectCommand, S3Client } from "@aws-sdk/client-s3"
import { getSignedUrl } from "@aws-sdk/s3-request-presigner"

const obsClient = new S3Client({
  region: process.env.OBS_REGION!,
  credentials: {
    accessKeyId: process.env.OBS_ACCESS_KEY!,
    secretAccessKey: process.env.OBS_SECRET_KEY!,
  },
  endpoint: `https://obs.${process.env.OBS_REGION}.huaweicloud.com`,
})

const BUCKET = process.env.OBS_BUCKET!

export async function uploadFormFile(file: File, folder: string): Promise<string> {
  try {
    if (!file) throw new Error('No file provided')
    const fileName = `${folder}/${Date.now()}-${file.name.replace(/\s+/g, '-').toLowerCase()}`
    const buffer = Buffer.from(await file.arrayBuffer())

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: fileName,
      Body: buffer,
      ContentType: file.type || 'application/octet-stream',
      Metadata: {
        'upload-time': new Date().toISOString(),
        'original-name': file.name,
      },
    })

    await obsClient.send(command)
    const publicUrl = `https://${BUCKET}.obs.${process.env.OBS_REGION}.huaweicloud.com/${fileName}`
    return publicUrl
  } catch (error) {
    console.error('[OBS Upload Error]', error)
    throw new Error(`Failed to upload file: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

export async function deleteFile(fileUrl: string): Promise<void> {
  try {
    if (!fileUrl) return
    const key = fileUrl.split(`${BUCKET}/`)[1]
    if (!key) return

    const command = new DeleteObjectCommand({
      Bucket: BUCKET,
      Key: key,
    })

    await obsClient.send(command)
  } catch (error) {
    console.error('[OBS Delete Error]', error)
  }
}

export async function getSignedUploadUrl(
  fileName: string,
  contentType: string,
  expiresIn: number = 3600
): Promise<string> {
  try {
    const key = `uploads/${Date.now()}-${fileName.replace(/\s+/g, '-').toLowerCase()}`
    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      ContentType: contentType,
    })
    return await getSignedUrl(obsClient, command, { expiresIn })
  } catch (error) {
    console.error('[OBS Signed URL Error]', error)
    throw new Error(`Failed to generate signed URL: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

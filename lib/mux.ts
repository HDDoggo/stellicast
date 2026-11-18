/**
 * Mux Video helpers (server-side only).
 *
 * Credentials come from Settings environment variables:
 *   MUX_TOKEN_ID, MUX_TOKEN_SECRET
 * They are never committed to the repository.
 */

const MUX_API = 'https://api.mux.com';

export function isMuxConfigured(): boolean {
  return Boolean(process.env.MUX_TOKEN_ID && process.env.MUX_TOKEN_SECRET);
}

function authHeader(): string {
  const id = process.env.MUX_TOKEN_ID as string;
  const secret = process.env.MUX_TOKEN_SECRET as string;
  return `Basic ${Buffer.from(`${id}:${secret}`).toString('base64')}`;
}

async function muxFetch(path: string, init: RequestInit = {}): Promise<any> {
  const response = await fetch(`${MUX_API}${path}`, {
    ...init,
    headers: {
      Authorization: authHeader(),
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
    cache: 'no-store',
  });

  const text = await response.text();

  if (!response.ok) {
    throw new Error(`Mux ${path} failed (${response.status}): ${text.slice(0, 300)}`);
  }

  return text ? JSON.parse(text) : null;
}

export type MuxDirectUpload = {
  id: string;
  url: string;
};

/**
 * Create a direct upload. The browser PUTs the file straight to `url`,
 * so video bytes never pass through the app server.
 */
export async function createMuxDirectUpload(options: {
  corsOrigin: string;
  passthrough?: string;
}): Promise<MuxDirectUpload> {
  const payload: Record<string, any> = {
    cors_origin: options.corsOrigin,
    new_asset_settings: {
      playback_policy: ['public'],
      ...(options.passthrough ? { passthrough: options.passthrough } : {}),
    },
  };

  const data = await muxFetch('/video/v1/uploads', {
    method: 'POST',
    body: JSON.stringify(payload),
  });

  return { id: data.data.id, url: data.data.url };
}

export async function getMuxUpload(uploadId: string): Promise<any> {
  const data = await muxFetch(`/video/v1/uploads/${uploadId}`);
  return data?.data ?? null;
}

export async function getMuxAsset(assetId: string): Promise<any> {
  const data = await muxFetch(`/video/v1/assets/${assetId}`);
  return data?.data ?? null;
}

export async function deleteMuxAsset(assetId: string): Promise<void> {
  await muxFetch(`/video/v1/assets/${assetId}`, { method: 'DELETE' });
}

export function firstPlaybackId(asset: any): string | null {
  const ids = asset?.playback_ids;
  if (!Array.isArray(ids) || ids.length === 0) return null;
  const publicId = ids.find((p: any) => p?.policy === 'public');
  return (publicId ?? ids[0])?.id ?? null;
}

export function muxPlaybackUrl(playbackId: string): string {
  return `https://stream.mux.com/${playbackId}.m3u8`;
}

export function muxThumbnailUrl(playbackId: string): string {
  return `https://image.mux.com/${playbackId}/thumbnail.jpg?width=1280&height=720&fit_mode=preserve&time=1`;
}

export function muxMp4Url(playbackId: string): string {
  return `https://stream.mux.com/${playbackId}/high.mp4`;
}

/** Extract the playback id from a stored https://stream.mux.com/<id>.m3u8 url. */
export function playbackIdFromUrl(videoUrl: string | null | undefined): string | null {
  if (!videoUrl || typeof videoUrl !== 'string') return null;
  const match = videoUrl.match(/stream\.mux\.com\/([^/.]+)\.m3u8/);
  return match ? match[1] : null;
}

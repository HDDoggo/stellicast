import { NextRequest, NextResponse } from 'next/server';
import { createSupabaseServerClient } from '@/../lib/supabase-server';
import {
  getMuxUpload,
  getMuxAsset,
  firstPlaybackId,
  muxPlaybackUrl,
  muxThumbnailUrl,
  isMuxConfigured,
} from '@/../lib/mux';

/**
 * Resolve a finished Mux upload into a playable video.
 *
 * The browser calls this after PUTting the file to the Mux upload URL.
 * It walks upload -> asset -> playback id and stores the resulting HLS
 * url, poster frame and duration on the video row.
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    if (!isMuxConfigured()) {
      return NextResponse.json(
        { error: 'Video processing is not configured.' },
        { status: 503 }
      );
    }

    const supabase = await createSupabaseServerClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json().catch(() => ({}));
    const uploadId = body?.uploadId as string | undefined;

    if (!uploadId) {
      return NextResponse.json({ error: 'uploadId is required' }, { status: 400 });
    }

    const { data: video, error: videoError } = await supabase
      .from('videos')
      .select('id, thumbnail_url, video_url, duration, channels(owner_id)')
      .eq('id', id)
      .single();

    if (videoError || !video) {
      return NextResponse.json({ error: 'Video not found' }, { status: 404 });
    }

    const channels = video.channels as any;
    const ownerId = Array.isArray(channels) ? channels[0]?.owner_id : channels?.owner_id;

    if (ownerId !== user.id) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    // Mux creates the asset asynchronously after the upload completes.
    const upload = await getMuxUpload(uploadId);
    const assetId = upload?.asset_id;

    if (!assetId) {
      return NextResponse.json({ status: 'processing' });
    }

    const asset = await getMuxAsset(assetId);

    // Guard against attaching someone else's upload to this video.
    if (asset?.passthrough && asset.passthrough !== video.id) {
      return NextResponse.json(
        { error: 'This upload does not belong to this video.' },
        { status: 403 }
      );
    }

    if (asset?.status !== 'ready') {
      return NextResponse.json({ status: 'processing', assetStatus: asset?.status ?? 'unknown' });
    }

    const playbackId = firstPlaybackId(asset);
    if (!playbackId) {
      return NextResponse.json({ status: 'processing' });
    }

    const update: Record<string, any> = {
      video_url: muxPlaybackUrl(playbackId),
    };

    // Keep a user-uploaded custom thumbnail if one already exists.
    if (!video.thumbnail_url) {
      update.thumbnail_url = muxThumbnailUrl(playbackId);
    }

    if (typeof asset.duration === 'number' && asset.duration > 0) {
      update.duration = Math.round(asset.duration);
    }

    const { error: updateError } = await supabase
      .from('videos')
      .update(update)
      .eq('id', video.id);

    if (updateError) throw updateError;

    return NextResponse.json({
      status: 'ready',
      playbackId,
      videoUrl: update.video_url,
      thumbnailUrl: update.thumbnail_url ?? video.thumbnail_url,
      duration: update.duration ?? video.duration ?? null,
    });
  } catch (error: any) {
    console.error('Mux sync error:', error);
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
  }
}

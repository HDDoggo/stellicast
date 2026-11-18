import { createServerClient } from '@supabase/ssr';
import { createClient } from '@supabase/supabase-js';
import { cookies } from 'next/headers';

// Fallbacks keep server rendering and API routes from throwing when the
// deployment has no Supabase credentials yet; queries return an API error that
// callers already handle, so pages render their empty states.
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://not-configured.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'not-configured-anon-key';
const supabaseSecretKey = process.env.SUPABASE_SECRET_API_KEY || 'not-configured-secret-key';

export const isSupabaseConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();

  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        } catch {
          // Server Component - cookies cannot be set here
          // They will be refreshed on the next request
        }
      },
    },
  });
}

// Admin client using secret API key - bypasses RLS, use with caution!
export function createSupabaseAdminClient() {
  return createClient(supabaseUrl, supabaseSecretKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
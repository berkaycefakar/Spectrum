// Spectrum — account deletion, server side.
//
// App Store Review Guideline 5.1.1(v): an app that lets users create an account must let them
// delete it. The app can erase its own tables, but the row in `auth.users` needs the
// service-role key — and that key can never ship inside the binary, because anyone can pull it
// out of an IPA and get full admin access to the database. So the last step happens here.
//
// Deploy:
//   supabase functions deploy delete-user
//
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected by the platform;
// you do not add them yourself.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Unauthorized" }, 401);
  }

  // Identify the caller from THEIR token. The user id is never taken from the request body:
  // that would let any signed-in user delete anybody else's account.
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  // Elevate only after the caller is proven, and only for this one id.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const id = user.id;

  // Owned content first, then the social graph, then the profile — same order as the client
  // path, so an interrupted run never leaves a live-looking profile pointing at nothing.
  // `PromiseLike`, not `Promise`: a PostgREST builder has `then` but no `catch`/`finally`,
  // so the stricter annotation fails Deno's type check. It is also lazy — nothing is sent
  // until the `await` below — which is what keeps the deletion order the comment describes.
  const steps: Array<[string, PromiseLike<{ error: unknown }>]> = [
    ["reviews", admin.from("reviews").delete().eq("user_id", id)],
    ["album_reviews", admin.from("album_reviews").delete().eq("user_id", id)],
    ["artist_reviews", admin.from("artist_reviews").delete().eq("user_id", id)],
    ["follows(follower)", admin.from("follows").delete().eq("follower_id", id)],
    ["follows(following)", admin.from("follows").delete().eq("following_id", id)],
    // Moderation records the user created or is the subject of.
    ["user_blocks(blocker)", admin.from("user_blocks").delete().eq("blocker_id", id)],
    ["user_blocks(blocked)", admin.from("user_blocks").delete().eq("blocked_id", id)],
    ["content_reports", admin.from("content_reports").delete().eq("reporter_id", id)],
  ];

  for (const [label, request] of steps) {
    const { error } = await request;
    if (error) {
      return json({ error: `Failed clearing ${label}: ${String(error)}` }, 500);
    }
  }

  // Avatar is best-effort: a user who never uploaded one has nothing at this path, and a
  // storage hiccup must not block the deletion itself.
  try {
    await admin.storage.from("avatars").remove([`${id}/avatar.jpg`]);
  } catch (_) {
    // Intentionally ignored.
  }

  const { error: profileError } = await admin.from("profiles").delete().eq("id", id);
  if (profileError) {
    return json({ error: `Failed clearing profile: ${String(profileError)}` }, 500);
  }

  // The part the app cannot do.
  const { error: deleteError } = await admin.auth.admin.deleteUser(id);
  if (deleteError) {
    return json({ error: deleteError.message }, 500);
  }

  return json({ ok: true });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

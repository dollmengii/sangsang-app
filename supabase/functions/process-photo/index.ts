// 사진 처리 (기획서 4.9의 1단계, 13.5).
// 앱이 originals/{내 id}/{사진 id}.jpg 로 올린 뒤 이 함수를 부른다.
// 1) 방향을 바로잡고 긴 쪽 1080px 이하로 줄여 다시 저장한다. 다시 인코딩하면서 EXIF(촬영 위치 등)는 모두 사라진다.
// 2) 가로 20px 무드 이미지를 moods/{내 id}/{사진 id}.png 로 만든다.
// 3) photos 표에 줄을 넣는다. 사진 검사와 승인은 다음 단계의 AI 분석이 맡는다.
import { createClient } from "npm:@supabase/supabase-js@2";
import { processImage } from "../_shared/image.ts";

const MAX_PHOTOS = 3;
const MAX_UPLOAD_BYTES = 12 * 1024 * 1024;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const token = req.headers.get("Authorization")?.replace("Bearer ", "") ?? "";
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json(401, { error: "unauthorized" });
  const uid = userData.user.id;

  const { photoId, isFace } = await req.json().catch(() => ({}));
  if (typeof photoId !== "string" || !/^[0-9a-f-]{36}$/.test(photoId)) {
    return json(400, { error: "invalid_photo_id" });
  }
  const originalPath = `${uid}/${photoId}.jpg`;

  const { count } = await admin.from("photos").select("id", { count: "exact", head: true }).eq("owner", uid);
  if ((count ?? 0) >= MAX_PHOTOS) {
    await admin.storage.from("originals").remove([originalPath]);
    return json(409, { error: "too_many_photos" });
  }

  const { data: blob, error: downloadError } = await admin.storage.from("originals").download(originalPath);
  if (downloadError || !blob) return json(404, { error: "upload_not_found" });
  if (blob.size > MAX_UPLOAD_BYTES) {
    await admin.storage.from("originals").remove([originalPath]);
    return json(413, { error: "too_large" });
  }

  let processed;
  try {
    processed = await processImage(new Uint8Array(await blob.arrayBuffer()));
  } catch {
    await admin.storage.from("originals").remove([originalPath]);
    return json(422, { error: "not_an_image" });
  }
  const { cleaned, moodPng, width, height } = processed;

  const moodPath = `${uid}/${photoId}.png`;

  const up1 = await admin.storage.from("originals")
    .upload(originalPath, cleaned, { contentType: "image/jpeg", upsert: true });
  const up2 = await admin.storage.from("moods")
    .upload(moodPath, moodPng, { contentType: "image/png", upsert: true });
  if (up1.error || up2.error) return json(500, { error: "storage_failed" });

  const isFirst = (count ?? 0) === 0;
  const { error: insertError } = await admin.from("photos").insert({
    id: photoId,
    owner: uid,
    original_path: originalPath,
    mood_path: moodPath,
    is_face: isFace !== false,
    is_primary: isFirst,
  });
  if (insertError) return json(500, { error: "db_failed" });

  return json(200, { photoId, moodPath, width, height });
});

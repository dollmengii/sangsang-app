import { Image } from "npm:imagescript@1.3.0";
import { readJpegOrientation } from "./exif.ts";

export const MAX_SIDE = 1080;
export const MOOD_WIDTH = 20;

// EXIF 방향(1~8)대로 픽셀을 옮긴다. imagescript의 rotate()는 정사각형이 아닌 이미지에서
// 결과가 틀려서 직접 옮긴다.
export function applyOrientation(image: Image, orientation: number): Image {
  if (orientation < 2 || orientation > 8) return image;
  const w = image.width;
  const h = image.height;
  const swap = orientation >= 5;
  const out = new Image(swap ? h : w, swap ? w : h);
  const src = new Uint32Array(image.bitmap.buffer, image.bitmap.byteOffset, w * h);
  const dst = new Uint32Array(out.bitmap.buffer, out.bitmap.byteOffset, w * h);
  const ow = out.width;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let dx: number, dy: number;
      switch (orientation) {
        case 2: dx = w - 1 - x; dy = y; break;
        case 3: dx = w - 1 - x; dy = h - 1 - y; break;
        case 4: dx = x; dy = h - 1 - y; break;
        case 5: dx = y; dy = x; break;
        case 6: dx = h - 1 - y; dy = x; break;
        case 7: dx = h - 1 - y; dy = w - 1 - x; break;
        default: dx = y; dy = w - 1 - x; break; // 8
      }
      dst[dy * ow + dx] = src[y * w + x];
    }
  }
  return out;
}

/// 방향을 바로잡고 긴 쪽을 1080px 이하로 줄여 JPEG로 다시 만든다(EXIF 없음).
/// 가로 20px 무드 이미지(PNG)도 함께 만든다.
export async function processImage(bytes: Uint8Array) {
  let image = await Image.decode(bytes);
  if (Math.max(image.width, image.height) > MAX_SIDE) {
    if (image.width >= image.height) image.resize(MAX_SIDE, Image.RESIZE_AUTO);
    else image.resize(Image.RESIZE_AUTO, MAX_SIDE);
  }
  image = applyOrientation(image, readJpegOrientation(bytes));
  const cleaned = await image.encodeJPEG(85);
  const moodPng = await image.clone().resize(MOOD_WIDTH, Image.RESIZE_AUTO).encode();
  return { cleaned, moodPng, width: image.width, height: image.height };
}

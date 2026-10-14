import { assertEquals } from "jsr:@std/assert@1";
import { Image } from "npm:imagescript@1.3.0";
import { applyOrientation, MOOD_WIDTH, processImage } from "./image.ts";
import { readJpegOrientation } from "./exif.ts";

const RED = 0xff0000ff;

function marked() {
  const img = new Image(2, 3); // 왼쪽 위만 빨강
  img.setPixelAt(1, 1, RED);
  return img;
}

function redAt(img: Image): [number, number] {
  for (let y = 1; y <= img.height; y++) {
    for (let x = 1; x <= img.width; x++) if (img.getPixelAt(x, y) === RED) return [x, y];
  }
  return [0, 0];
}

// EXIF 방향별로 화면에 보여야 할 빨간 점 위치 (원래 왼쪽 위 점)
Deno.test("orientation 6 rotates clockwise", () => {
  const r = applyOrientation(marked(), 6);
  assertEquals([r.width, r.height], [3, 2]);
  assertEquals(redAt(r), [3, 1]);
});
Deno.test("orientation 8 rotates counter-clockwise", () => {
  assertEquals(redAt(applyOrientation(marked(), 8)), [1, 2]);
});
Deno.test("orientation 3 rotates 180", () => {
  assertEquals(redAt(applyOrientation(marked(), 3)), [2, 3]);
});
Deno.test("orientation 5 transposes", () => {
  assertEquals(redAt(applyOrientation(marked(), 5)), [1, 1]);
});
Deno.test("orientation 7 transverses", () => {
  assertEquals(redAt(applyOrientation(marked(), 7)), [3, 2]);
});

Deno.test("processImage shrinks to 1080 and makes a 20px mood image without EXIF", async () => {
  const big = new Image(2000, 1500).fill(0x336699ff);
  const { cleaned, moodPng, width, height } = await processImage(await big.encodeJPEG(90));
  assertEquals([width, height], [1080, 810]);
  assertEquals(readJpegOrientation(cleaned), 1);
  const mood = await Image.decode(moodPng);
  assertEquals(mood.width, MOOD_WIDTH);
});

import { assertEquals } from "jsr:@std/assert@1";
import { readJpegOrientation } from "./exif.ts";

function jpegWithOrientation(value: number, littleEndian: boolean): Uint8Array {
  // SOI, APP1(Exif, TIFF 헤더, IFD0 항목 1개), SOS
  const tiff = new Uint8Array(8 + 2 + 12 + 4);
  const v = new DataView(tiff.buffer);
  v.setUint16(0, littleEndian ? 0x4949 : 0x4d4d);
  v.setUint16(2, 42, littleEndian);
  v.setUint32(4, 8, littleEndian);
  v.setUint16(8, 1, littleEndian);
  v.setUint16(10, 0x0112, littleEndian);
  v.setUint16(12, 3, littleEndian);
  v.setUint32(14, 1, littleEndian);
  v.setUint16(18, value, littleEndian);
  const app1Len = 2 + 6 + tiff.length;
  const out = new Uint8Array(2 + 2 + app1Len + 2);
  const o = new DataView(out.buffer);
  out.set([0xff, 0xd8, 0xff, 0xe1]);
  o.setUint16(4, app1Len);
  out.set([0x45, 0x78, 0x69, 0x66, 0, 0], 6);
  out.set(tiff, 12);
  out.set([0xff, 0xda], 12 + tiff.length);
  return out;
}

Deno.test("reads orientation (little endian)", () => {
  assertEquals(readJpegOrientation(jpegWithOrientation(6, true)), 6);
});
Deno.test("reads orientation (big endian)", () => {
  assertEquals(readJpegOrientation(jpegWithOrientation(8, false)), 8);
});
Deno.test("no exif means 1", () => {
  assertEquals(readJpegOrientation(new Uint8Array([0xff, 0xd8, 0xff, 0xda, 0, 2])), 1);
});
Deno.test("not a jpeg means 1", () => {
  assertEquals(readJpegOrientation(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), 1);
});

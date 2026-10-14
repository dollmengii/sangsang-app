// JPEG의 EXIF 방향 값(1~8)만 읽는다. 없으면 1.
// 사진을 다시 인코딩하면 EXIF(촬영 위치 포함)는 모두 사라지므로, 방향만 먼저 읽어 픽셀에 반영한다.
export function readJpegOrientation(bytes: Uint8Array): number {
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8) return 1;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = 2;
  while (offset + 4 < bytes.length) {
    if (bytes[offset] !== 0xff) return 1;
    const marker = bytes[offset + 1];
    const size = view.getUint16(offset + 2);
    if (marker === 0xe1 && view.getUint32(offset + 4) === 0x45786966) { // "Exif"
      const tiff = offset + 10;
      const little = view.getUint16(tiff) === 0x4949;
      const ifd0 = tiff + view.getUint32(tiff + 4, little);
      const entries = view.getUint16(ifd0, little);
      for (let i = 0; i < entries; i++) {
        const entry = ifd0 + 2 + i * 12;
        if (entry + 12 > bytes.length) return 1;
        if (view.getUint16(entry, little) === 0x0112) {
          const value = view.getUint16(entry + 8, little);
          return value >= 1 && value <= 8 ? value : 1;
        }
      }
      return 1;
    }
    if (marker === 0xda) return 1; // 이미지 데이터 시작, EXIF 없음
    offset += 2 + size;
  }
  return 1;
}

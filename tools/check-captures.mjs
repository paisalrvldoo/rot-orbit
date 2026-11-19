// Check our final four-shot handoff; authenticity and readability require Studio review.
import { readFileSync, readdirSync, lstatSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const directory = join(root, 'screenshots');
const tour = JSON.parse(readFileSync(join(root, 'TOUR.json'), 'utf8'));
const expected = ['01-cover.jpg', '02-index.jpg', '03-raid.jpg', '04-upgrades.jpg'];
const functions = ['Cover', 'Index', 'Raid', 'Upgrades'];
const errors = [];
const names = readdirSync(directory).sort();
if (JSON.stringify(names) !== JSON.stringify(expected)) {
  errors.push('screenshots/ must contain exactly ' + expected.join(', ') + '; replace all starter PNGs.');
}
if (tour.tour !== 1 || !Array.isArray(tour.steps) || tour.steps.length !== 4) {
  errors.push('TOUR.json must have four steps.');
} else {
  tour.steps.forEach((step, index) => {
    if (step.screenshot !== expected[index] || step.call?.module !== 'ReplicatedStorage.ScreenshotMode'
        || step.call?.fn !== functions[index] || step.call?.on !== 'Server'
        || step.call?.arg !== 0 || !Array.isArray(step.keys) || step.keys.length !== 0
        || !Number.isInteger(step.wait_ms) || step.wait_ms < 0 || step.wait_ms > 3000) {
      errors.push('TOUR step ' + (index + 1) + ' does not match the documented Studio preset.');
    }
  });
}

function jpegSize(bytes) {
  if (bytes.length < 4 || bytes.readUInt16BE(0) !== 0xffd8
      || bytes.readUInt16BE(bytes.length - 2) !== 0xffd9) throw new Error('not a complete JPEG');
  let offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset++] !== 0xff) throw new Error('invalid JPEG marker');
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xda || marker === 0xd9) break;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (offset + 2 > bytes.length) break;
    const length = bytes.readUInt16BE(offset);
    if (length < 2 || offset + length > bytes.length) throw new Error('truncated JPEG segment');
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      if (length < 8) throw new Error('invalid JPEG frame');
      return [bytes.readUInt16BE(offset + 5), bytes.readUInt16BE(offset + 3)];
    }
    offset += length;
  }
  throw new Error('no supported JPEG frame found');
}

for (const name of expected) {
  if (!names.includes(name)) continue;
  try {
    const path = join(directory, name);
    if (!lstatSync(path).isFile()) throw new Error('must be a regular file');
    const bytes = readFileSync(path);
    if (bytes.length > 256 * 1024) throw new Error('larger than 256 KiB');
    const [width, height] = jpegSize(bytes);
    if (width !== 1280 || height !== 720) throw new Error('expected 1280×720, got ' + width + '×' + height);
    process.stdout.write(name + ': 1280×720 JPEG, ' + bytes.length + ' bytes\n');
  } catch (error) {
    errors.push(name + ': ' + error.message);
  }
}
if (errors.length) {
  process.stderr.write('Final captures are not ready:\n- ' + errors.join('\n- ') + '\n');
  process.exitCode = 1;
} else {
  process.stdout.write('Four capture files and TOUR match. Confirm real Studio content, readability and approved Roblox uploads.\n');
}

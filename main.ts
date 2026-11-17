// main.ts -- Brainrot Heist entry program (Node 22, standard library only).
// The game is this directory's Rojo project, built into game.rbxl with
// `rojo build default.project.json --output game.rbxl`. This program hands
// the game in: it copies game.rbxl, src/, screenshots/ and PLAY.json from
// beside this file to /output and writes /output/dossier.json with the
// vendored make.fun library (vendor/makefun-roblox.ts, unchanged).
//
// Every name under /output starts with a letter, a digit or _ and holds
// only letters, digits, . _ and -: a file such as .gitkeep or .DS_Store
// anywhere under it fails the entry, so src/ and screenshots/ are copied
// without any name that starts with a dot.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
// The program runs twice and both runs must write the same bytes, so it
// does no timestamps, no randomness and no network calls of its own.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

// Fail loudly, before writing anything, when a required hand-in file is missing.
for (const required of ['game.rbxl', 'PLAY.json']) {
  if (!existsSync(join(here, required))) {
    throw new Error(`Brainrot Heist: missing ${required} — build the place first (rojo build) and fill in PLAY.json with the published place.`);
  }
}
if (!existsSync(join(here, 'screenshots'))) {
  throw new Error('Brainrot Heist: missing screenshots/ — add 3 screenshots from Roblox Studio first.');
}

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the bytes; the others refuse an entry the
// scorer would refuse (more than 4 screenshots or one over 256 KiB; a place of more than 500000 instances, whose
// scripts' sources come to over 8 MiB or whose scripts' paths come to over 1048576 characters, in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 }),
);

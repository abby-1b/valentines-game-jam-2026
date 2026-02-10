import { decode, encode } from "https://deno.land/x/pngs/mod.ts";

let EXPORT_IDX = 0;

type Color = [number, number, number];
type Bit = 0 | 1 | 2;
type BitPlane = Bit[][];
interface ImageData {
  width: number;
  height: number;
  image: Uint8Array;
}

/** Extracts a color palette from an image */
function getColors(image: ImageData): Color[] {
  const colors = new Map<string, Color>();
  const { image: data, width, height } = image;

  for (let i = 0; i < data.length; i += 4) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const key = `${r},${g},${b}`;
    
    if (!colors.has(key)) {
      if (r + b + g == 0) continue;
      colors.set(key, [r, g, b]);
    }
  }
  
  return Array.from(colors.values());
}

/** Converts 1D RGBA array to 2D array for easier pixel access */
function to2DArray(image: ImageData): Color[][] {
  const { width, height, image: data } = image;
  const result: Color[][] = [];
  
  for (let y = 0; y < height; y++) {
    const row: Color[] = [];
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      row.push([data[i], data[i + 1], data[i + 2]]);
    }
    result.push(row);
  }
  
  return result;
}

/** Extracts a 1 BPP array from an image */
function getBitPlaneOfColor(image: ImageData, color: Color): BitPlane {
  const { width, height } = image;
  const pixels2D = to2DArray(image);
  const bitplane: BitPlane = [];
  
  for (let y = 0; y < height; y++) {
    const row: Bit[] = [];
    for (let x = 0; x < width; x++) {
      const [r, g, b] = pixels2D[y][x];
      const [cr, cg, cb] = color;
      
      // Compare colors (all components must match exactly)
      row.push(r === cr && g === cg && b === cb ? 1 : 0);
    }
    bitplane.push(row);
  }
  
  return bitplane;
}

/** Separates an image into its corresponding bitplanes */
function getBitPlanes(image: ImageData): { bitplane: BitPlane, color: Color }[] {
  const bitplanes = [];
  for (const color of getColors(image)) {
    bitplanes.push({
      bitplane: getBitPlaneOfColor(image, color),
      color
    });
  }
  return bitplanes;
}

type Rect = { x: number, y: number, w: number, h: number };
interface CroppedBitPlane {
  data: BitPlane,
  xOffs: number,
  yOffs: number,
  rects: Rect[],
  color: Color,
}
function cbpFromBp(bitplane: BitPlane, color: Color): CroppedBitPlane {
  return {
    data: structuredClone(bitplane),
    xOffs: 0,
    yOffs: 0,
    rects: [],
    color,
  };
}

/** Removes simple data from a bitplane, returning simple rects */
function cropBitPlaneSides(cropped: CroppedBitPlane) {
  const isRowSameColor = (bp: BitPlane, idx: number): -1 | Bit => {
    const row = bp[idx];
    const el = row[0];
    for (let i = 1; i < row.length; i++) {
      if (row[i] != el) return -1;
    }
    return el;
  };

  const isRowEmpty = (bp: BitPlane, idx: number): boolean => {
    const row = bp[idx];
    for (let i = 0; i < row.length; i++) {
      if (row[i] != 0) return false;
    }
    return true;
  };

  const removeRow = (bp: BitPlane, idx: number) => {
    bp.splice(idx, 1);
  };

  const isColSameColor = (bp: BitPlane, idx: number): -1 | Bit => {
    const el = bp[0][idx];
    for (let i = 1; i < bp.length; i++) {
      if (bp[i][idx] != el) return -1;
    }
    return el;
  };

  const removeCol = (bp: BitPlane, idx: number) => {
    for (const row of bp) row.splice(idx, 1);
  };

  const removeRowIfEmpty = (bp: BitPlane, idx: number): boolean => {
    if (isRowEmpty(bp, idx)) {
      removeRow(bp, idx);
      return true;
    }
    return false;
  };

  const removeRowsFromTop = (bp: BitPlane, cropped: CroppedBitPlane) => {
    while (bp.length && removeRowIfEmpty(bp, 0)) {
      cropped.yOffs++;
    }
  };

  const removeRowsFromBottom = (bp: BitPlane) => {
    while (bp.length && removeRowIfEmpty(bp, bp.length - 1)) { 0; }
  };

  // Top
  let top = isRowSameColor(cropped.data, 0);
  while (top != -1) {
    if (top == 1) {
      cropped.rects.push({
        x: cropped.xOffs,
        y: cropped.yOffs,
        w: cropped.data[0].length,
        h: 1,
      });
    }
    cropped.yOffs++;
    removeRow(cropped.data, 0);
    top = cropped.data.length ? isRowSameColor(cropped.data, 0) : -1;
  }

  // Bottom
  let bottom = isRowSameColor(cropped.data, cropped.data.length - 1);
  while (bottom != -1) {
    if (bottom == 1) {
      cropped.rects.push({
        x: cropped.xOffs,
        y: cropped.yOffs + cropped.data.length - 1,
        w: cropped.data[0].length,
        h: 1,
      });
    }
    removeRow(cropped.data, cropped.data.length - 1);
    bottom = cropped.data.length
      ? isRowSameColor(cropped.data, cropped.data.length - 1)
      : -1;
  }

  // Left
  let left = isColSameColor(cropped.data, 0);
  while (left != -1) {
    if (left == 1) {
      cropped.rects.push({
        x: cropped.xOffs,
        y: cropped.yOffs,
        w: 1,
        h: cropped.data.length,
      });
    }
    cropped.xOffs++;
    removeCol(cropped.data, 0);
    left = cropped.data[0].length ? isColSameColor(cropped.data, 0) : -1;
  }

  // Right
  let right = isColSameColor(
    cropped.data,
    cropped.data[0].length - 1
  );
  while (right != -1) {
    if (right == 1) {
      cropped.rects.push({
        x: cropped.xOffs + cropped.data[0].length - 1,
        y: cropped.yOffs,
        w: 1,
        h: cropped.data.length,
      });
    }
    removeCol(cropped.data, cropped.data[0].length - 1);
    right = cropped.data[0].length
      ? isColSameColor(cropped.data, cropped.data[0].length - 1)
      : -1;
  }

  // Remove any remaining empty rows from top and bottom (0s only)
  removeRowsFromTop(cropped.data, cropped);
  removeRowsFromBottom(cropped.data);

  cropped.rects = mergeRects(cropped.rects);

  return cropped;
}

function mergeRects(rects: Rect[]): Rect[] {
  rects.sort((a, b) => a.y - b.y || a.x - b.x);

  const out: Rect[] = [];

  for (const r of rects) {
    const last = out[out.length - 1];
    if (!last) {
      out.push({ ...r });
      continue;
    }

    // vertical merge
    if (
      last.x === r.x &&
      last.w === r.w &&
      last.y + last.h === r.y
    ) {
      last.h += r.h;
      continue;
    }

    // horizontal merge
    if (
      last.y === r.y &&
      last.h === r.h &&
      last.x + last.w === r.x
    ) {
      last.w += r.w;
      continue;
    }

    out.push({ ...r });
  }

  return out;
}

function splitIntoTiles(bitplane: BitPlane, maxWidth: number, maxHeight: number): BitPlane[] {
  // If the bitplane is already within constraints, return it as a single tile
  if (bitplane.length === 0 || bitplane[0].length === 0) {
    return [];
  }
  
  const height = bitplane.length;
  const width = bitplane[0].length;
  
  // Check if the bitplane fits within the max dimensions
  if (height <= maxHeight && width <= maxWidth) {
    return [bitplane];
  }
  
  const tiles: BitPlane[] = [];
  
  // Split the bitplane into tiles
  for (let y = 0; y < height; y += maxHeight) {
    for (let x = 0; x < width; x += maxWidth) {
      // Calculate the actual tile dimensions (may be smaller at the edges)
      const tileHeight = Math.min(maxHeight, height - y);
      const tileWidth = Math.min(maxWidth, width - x);
      
      // Create the tile by extracting the appropriate subarray
      const tile: BitPlane = [];
      for (let row = y; row < y + tileHeight; row++) {
        const tileRow: Bit[] = [];
        for (let col = x; col < x + tileWidth; col++) {
          tileRow.push(bitplane[row][col]);
        }
        tile.push(tileRow);
      }
      
      tiles.push(tile);
    }
  }
  
  return tiles;
}

interface Atlas {

}
function combineIntoAtlas(cbps: CroppedBitPlane[]): Atlas {
  const complexity = (bp: BitPlane) => {
    let changes = 0;
    let last = 0;
    for (const row of bp) {
      for (const col of row) {
        if (col != last) changes++;
        last = col;
      }
    }
    return changes;
  };
  
  // Split into properly-sized bitplanes
  let newCbps: CroppedBitPlane[] = [];
  for (const c of cbps) {
    const add = splitIntoTiles(c.data, MAX_WIDTH, MAX_HEIGHT)
      .map(bp => {
        const cbp = cbpFromBp(bp, c.color);
        cbp.xOffs = c.xOffs;
        cbp.yOffs = c.yOffs;
        cropBitPlaneSides(cbp);
        return cbp;
      });
    add[0].rects = c.rects;
    newCbps.push(...add);
  }

  newCbps = newCbps
    .map((bp): [CroppedBitPlane, number] => [ bp, complexity(bp.data) ])
    .toSorted((a, b) => a[1] - b[1])
    .map(([bp, _]) => bp);

  for (const cbp of newCbps) {
    console.log({
      width: cbp.data[0].length, height: cbp.data.length
    });
    exportTestBitPlane(`testbp_${EXPORT_IDX++}.png`, cbp.data);
  }
  if (newCbps.length > 4) {
    console.log('well shit');
  }
  
  return {};
}

// function atlasToLua(, fnName: string): string {

//   // Get instructions
//   const ins: string[] = [];
//   return `function ${fnName}(x, y)\n${ins.map(i => '\t' + i).join('\n')}\nend`
// }


/** Export a bitplane as a PNG for testing */
async function exportTestBitPlane(name: string, bitplane: BitPlane) {
  const height = bitplane.length;
  const width = bitplane[0].length;
  const data = new Uint8Array(width * height * 4);
  
  // Convert bitplane (0/1) to RGBA pixels
  // 0 = black (0,0,0,255), 1 = white (255,255,255,255)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const value = bitplane[y][x] * 255;
      data[i] = value;     // R
      data[i + 1] = value; // G
      data[i + 2] = value; // B
      data[i + 3] = 255;   // A (fully opaque)
    }
  }
  
  const png = encode(data, width, height);
  await Deno.writeFile(name, png);
}

const MAX_WIDTH = 128;
const MAX_HEIGHT = 64;

// Dictionary of { filename: lua function name }
const files = {
  "../assets/intro_bg.png": "draw_ibg",
  "../assets/intro_main.png": "draw_imain",
  "../assets/intro_shad.png": "draw_ishad",
  "../assets/intro_fg.png": "draw_ifg",
};
/*
Example:
draw_ibg(x, y) => draws intro_bg at the given x, y position
*/

const cbps: CroppedBitPlane[] = [];
for (const [ filename, fnName ] of Object.entries(files)) {
  const fileData = await Deno.readFile(filename);
  const decoded = decode(fileData);

  const imageData: ImageData = {
    width: decoded.width,
    height: decoded.height,
    image: decoded.image,
  };
  
  // Get colors and bitplanes
  const colors = getColors(imageData);
  console.log(`Found ${colors.length} colors`);
  
  const bitplanes = getBitPlanes(imageData);
  console.log(`Generated ${bitplanes.length} bitplanes`);

  for (const { bitplane, color } of bitplanes) {
    const cbp = cropBitPlaneSides(cbpFromBp(bitplane, color));
    cbps.push(cbp);
  }
}
console.log(cbps.map(c => c.color));

combineIntoAtlas(cbps);

// Uncomment to run:
// main();
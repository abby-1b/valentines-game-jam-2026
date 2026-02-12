import { decode } from "https://deno.land/x/pngs/mod.ts";

const P8_COLORS: { color: [number, number, number], idx: number }[] = [
  { color: [ 0  , 0  , 0   ], idx: 0 },
  { color: [ 29 , 43 , 83  ], idx: 1 },
  { color: [ 126, 37 , 83  ], idx: 2 },
  { color: [ 0  , 135, 81  ], idx: 3 },
  { color: [ 171, 82 , 54  ], idx: 4 },
  { color: [ 95 , 87 , 79  ], idx: 5 },
  { color: [ 194, 195, 199 ], idx: 6 },
  { color: [ 255, 241, 232 ], idx: 7 },
  { color: [ 255, 0  , 77  ], idx: 8 },
  { color: [ 255, 163, 0   ], idx: 9 },
  { color: [ 255, 236, 39  ], idx: 10 },
  { color: [ 0  , 228, 54  ], idx: 11 },
  { color: [ 41 , 173, 255 ], idx: 12 },
  { color: [ 131, 118, 156 ], idx: 13 },
  { color: [ 255, 119, 168 ], idx: 14 },
  { color: [ 255, 204, 170 ], idx: 15 },

  { color: [ 41 , 24 , 20  ], idx: -16 },
  { color: [ 17 , 29 , 53  ], idx: -15 },
  { color: [ 66 , 33 , 54  ], idx: -14 },
  { color: [ 18 , 83 , 89  ], idx: -13 },
  { color: [ 116, 47 , 41  ], idx: -12 },
  { color: [ 73 , 51 , 59  ], idx: -11 },
  { color: [ 162, 136, 121 ], idx: -10 },
  { color: [ 243, 239, 125 ], idx: -9  },
  { color: [ 190, 18 , 80  ], idx: -8  },
  { color: [ 255, 108, 36  ], idx: -7  },
  { color: [ 168, 231, 46  ], idx: -6  },
  { color: [ 0  , 181, 67  ], idx: -5  },
  { color: [ 6  , 90 , 181 ], idx: -4  },
  { color: [ 117, 70 , 101 ], idx: -3  },
  { color: [ 255, 110, 89  ], idx: -2  },
  { color: [ 255, 157, 129 ], idx: -1  },
];
const closestIdx = (c: [number, number, number]) => {
  let closest = 0;
  let closestDist = Infinity;
  for (const { color, idx } of P8_COLORS) {
    const dist =
      (c[0] - color[0]) ** 2 +
      (c[1] - color[1]) ** 2 +
      (c[2] - color[2]) ** 2;
    if (dist < closestDist) {
      closest = idx;
      closestDist = dist;
    }
  }
  return closest;
};

interface ImageData {
  width: number;
  height: number;
  image: Uint8Array;
}

type PColor = number;

interface Layer {
  color: PColor;
  surfaceArea: number;
  mask: (0 | 1 | 2)[][];
}

interface RLEBlock {
  value: 0 | 1;
  length: number;
}

// Extended BitArrayWriter with VLE and optimizations
class OptimizedBitArrayWriter {
  private buffer: number[] = [];
  private currentByte = 0;
  private bitPosition = 0;

  private bits = 4;

  writeBit(bit: number): void {
    this.currentByte = (this.currentByte << 1) | (bit & 1);
    this.bitPosition++;
    
    if (this.bitPosition === this.bits) {
      this.buffer.push(this.currentByte);
      this.currentByte = 0;
      this.bitPosition = 0;
    }
  }

  writeBits(value: number, bitCount: number): void {
    for (let i = bitCount - 1; i >= 0; i--) {
      this.writeBit((value >> i) & 1);
    }
  }

  // Variable-Length Encoding (VLE) optimized for small values
  writeVLE(value: number): void {
    console.log('Wrote VLE:', value);
    // Encode: first bit indicates if value >= 128
    if (value < 128) {
      // Small value: store directly in 7 bits
      this.writeBit(0);
      this.writeBits(value, 7);
    } else {
      // Large value: use 7-bit chunks with continuation bit
      while (true) {
        this.writeBit(~~(value >= 128));
        this.writeBits(value & 0x7F, 7);
        if (value < 128) break;
        value >>= 7;
      }
    }
  }

  // Optimized VLE for RLE lengths (most runs are short)
  writeRunLength(value: number): void {
    if (value === 1) {
      // Most common case: single pixel, encode as 0
      this.writeBit(0);
    } else if (value <= 4) {
      // Short runs (2-4): encode as 10 + 2 bits
      this.writeBits(0b10, 2);
      this.writeBits(value - 2, 2); // 0=2, 1=3, 2=4
    } else if (value <= 32) {
      // Medium runs (5-32): encode as 110 + 5 bits
      this.writeBits(0b110, 3);
      this.writeBits(value - 5, 5); // 0=5, 31=36
    } else if (value <= 288) {
      // Long runs (33-288): encode as 1110 + 8 bits
      this.writeBits(0b1110, 4);
      this.writeBits(value - 33, 8); // 0=33, 255=288
    } else {
      // Very long runs: encode as 1111 + VLE
      this.writeBits(0b1111, 4);
      this.writeVLE(value);
    }
  }

  // Optimized block count encoding
  writeBlockCount(value: number): void {
    console.log('Wrote BlockCount:', value);
    if (value === 0) {
      this.writeBit(0); // No blocks
    } else if (value <= 3) {
      // 1-3 blocks: 10 + 2 bits
      this.writeBits(0b10, 2);
      this.writeBits(value - 1, 2);
    } else if (value <= 15) {
      // 4-15 blocks: 110 + 4 bits
      this.writeBits(0b110, 3);
      this.writeBits(value - 4, 4);
    } else {
      // Many blocks: 111 + VLE
      this.writeBits(0b111, 3);
      this.writeVLE(value);
    }
  }

  // Optimized color encoding - detect common colors
  writeColor(color: PColor): void {
    this.writeBits(color, 4);
  }

  finish(): number[] {
    if (this.bitPosition > 0) {
      // Pad with zeros to complete byte
      this.currentByte <<= (this.bits - this.bitPosition);
      this.buffer.push(this.currentByte);
    }
    return this.buffer;
  }
}

function to2DArray(image: ImageData): PColor[][] {
  const { width, height, image: data } = image;
  const result: PColor[][] = [];
  
  for (let y = 0; y < height; y++) {
    const row: PColor[] = [];
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      row.push(closestIdx([data[i], data[i + 1], data[i + 2]]));
    }
    result.push(row);
  }
  
  return result;
}

function extractLayers(image: PColor[][]): Layer[] {
  const height = image.length;
  const width = image[0].length;
  
  // Use Map for faster color counting
  const colorMap = new Map<PColor, { color: PColor; count: number; positions: [number, number][] }>();
  
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const color = image[y][x];
      if (color == 0) continue;

      let entry = colorMap.get(color);
      if (!entry) {
        entry = { color, count: 0, positions: [] };
        colorMap.set(color, entry);
      }
      entry.count++;
      entry.positions.push([x, y]);
    }
  }
  
  // Create layers
  const layers: Layer[] = [];
  
  for (const entry of colorMap.values()) {
    const mask: (0 | 1 | 2)[][] = Array.from({ length: height }, () => 
      Array(width).fill(0)
    );
    
    // Set positions for this color
    for (const [x, y] of entry.positions) {
      mask[y][x] = 1;
    }
    
    layers.push({
      color: entry.color,
      surfaceArea: entry.count,
      mask
    });
  }

  // Sort layers by surface area (descending)
  layers.sort((a, b) => b.surfaceArea - a.surfaceArea);
  
  // Mark overlapping pixels
  const isSet: boolean[][] = Array.from({ length: height }, () => 
    new Array(width).fill(false)
  );
  
  for (let i = layers.length - 1; i >= 0; i--) {
    const layer = layers[i];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (isSet[y][x]) {
          layer.mask[y][x] = 2; // Already set by previous layer
        } else if (layer.mask[y][x]) {
          isSet[y][x] = true;
        }
      }
    }
  }

  return layers;
}

// Optimized RLE with delta encoding for positions
function optimizedRLECompress(mask: (0 | 1 | 2)[][]): RLEBlock[] {
  const height = mask.length;
  const width = mask[0].length;
  const blocks: RLEBlock[] = [];
  
  // Flatten the mask, skipping "don't care" (2) pixels
  let lastValue: 0 | 1 | null = null;
  let currentLength = 0;
  
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const pixel = mask[y][x];
      // if (pixel === 2) continue; // here to test if "don't care pixels" work!

      if (pixel === lastValue || pixel === 2) {
        currentLength++;
      } else {
        if (lastValue !== null) {
          blocks.push({ value: lastValue, length: currentLength });
        }
        lastValue = pixel;
        currentLength = 1;
      }
    }
  }
  
  if (lastValue !== null && currentLength > 0) {
    blocks.push({ value: lastValue, length: currentLength });
  }
  
  // Post-process to combine small runs
  return optimizeRLEBlocks(blocks);
}

// Combine adjacent blocks with same value and optimize small runs
function optimizeRLEBlocks(blocks: RLEBlock[]): RLEBlock[] {
  if (blocks.length <= 1) return blocks;
  
  const optimized: RLEBlock[] = [];
  let current = { ...blocks[0] };
  
  for (let i = 1; i < blocks.length; i++) {
    if (blocks[i].value === current.value) {
      // Combine runs with same value
      current.length += blocks[i].length;
    } else {
      optimized.push(current);
      current = { ...blocks[i] };
    }
  }
  optimized.push(current);
  
  return optimized;
}

// Main compression function
function compressImage(image: ImageData): number[] {
  // Convert to 2D array
  const colorArray = to2DArray(image);
  
  // Extract layers sorted by area
  const layers = extractLayers(colorArray);
  
  // Create optimized writer
  const writer = new OptimizedBitArrayWriter();
  
  // First, write basic info: width and height (using VLE)
  writer.writeBits(image.width, 8);
  writer.writeBits(image.height, 8);
  
  // Write number of layers (optimized)
  writer.writeBlockCount(layers.length);
  
  // Compress and write each layer
  for (const layer of layers) {
    // Write color (optimized)
    writer.writeColor(layer.color);
    
    // Perform optimized RLE compression
    const rleBlocks = optimizedRLECompress(layer.mask);

    // Write block count (optimized)
    writer.writeBlockCount(rleBlocks.length);

    // Write RLE data
    for (const block of rleBlocks) {
      // Write value (1 bit)
      writer.writeBit(block.value);

      // Write length (optimized for runs)
      writer.writeRunLength(block.length);
    }
  }
  
  return writer.finish();
}

// Helper to analyze compression ratio
function analyzeCompression(original: ImageData, compressed: Uint8Array): void {
  const originalSize = original.image.length;
  const compressedSize = compressed.length;
  const ratio = (compressedSize / originalSize) * 100;
  
  console.log(`Original: ${originalSize} bytes`);
  console.log(`Compressed: ${compressedSize} bytes`);
  console.log(`Compression ratio: ${ratio.toFixed(2)}%`);
  console.log(`Space saved: ${(100 - ratio).toFixed(2)}%`);
}

// function toLua(fnName: string, cis: CompressedImage[]): string {
//   let data: string = '';

//   function outNum(num: number) { data += chr(num + 93); }

//   for (const ci of cis) {
//     outNum(closestIdx(ci.color));
//     outNum(ci.rects.length);
//     for (const r of ci.rects) {
//       outNum(r.x);
//       outNum(r.y);
//       outNum(r.w);
//       outNum(r.h);
//     }
//   }

//   // return `function ${fnName}(x, y)\n\tlocal d="${data}"\n\tdcmp(d,x,y)\nend`;
//   const ci = cis[1];
//   const ins = ci.rects.map(r => {
//     return `rectfill(${r.x},${r.y},${r.x+r.w-1},${r.y+r.h-1},${ci.color})`;
//   });
//   return `function ${fnName}(x, y)\n${ins.map(i => '\t' + i).join('\n')}\nend`;
// }


// Dictionary of { filename: lua function name }
const files = {
  "../assets/intro_bg.png": "draw_ibg",
  "../assets/intro_main.png": "draw_ibg",
  "../assets/intro_shad.png": "draw_ishad",
  "../assets/intro_fg.png": "draw_ifg",
};
/*
Example:
draw_ibg(x, y) => draws intro_bg at the given x, y position
*/

let out = '';

for (const [ filename, fnName ] of Object.entries(files)) {
  const fileData = await Deno.readFile(filename);
  const decoded = decode(fileData);

  // const colorArray = to2DArray({
  //   width: decoded.width,
  //   height: decoded.height,
  //   image: decoded.image,
  // });

  const compressed = compressImage(decoded);
  console.log(`Compressed size: ${compressed.length} bytes`);
  
  while (compressed.length % 128 != 0) compressed.push(0);
  for (let i = 0; i < compressed.length; i++) {
    if (i % 128 == 0) out += '\n';
    if (compressed[i] > 15) throw new Error('What the FUCK?? ' + compressed[i]);
    out += compressed[i].toString(16).toLowerCase();
  }
  // console.log(out);

  // console.log('=== Layer Analysis ===');
  // visualizeLayers(layers);


  
  // const compressed: CompressedImage[] = compress(imageData);
  // optimizeLayersAggressive(compressed, decoded.width, decoded.height);
  // // console.log('images:', compressed.length);
  // Deno.writeTextFileSync('out.txt', toLua(fnName, compressed));

  console.log(filename);
}

console.log(out);

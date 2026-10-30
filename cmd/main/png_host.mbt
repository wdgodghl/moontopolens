// PNG decoding is a bounded Node input adapter. Topology and image filtration
// remain in MoonBit. It converts supported PNG pixels to an ordinary P5 raster.

///|
extern "js" fn png_as_pgm(data : FixedArray[Int32]) -> FixedArray[Int32] =
  #|(source) => {
  #|  try {
  #|    const zlib = require("node:zlib");
  #|    const bytes = Buffer.from(source);
  #|    const signature = Buffer.from([137,80,78,71,13,10,26,10]);
  #|    if (bytes.length > 1000000 || !bytes.subarray(0,8).equals(signature)) return [];
  #|    let offset=8, width=0, height=0, channels=0, color=-1, seenIHDR=false, seenIEND=false;
  #|    const pieces=[];
  #|    const crcTable = new Uint32Array(256);
  #|    for (let n=0;n<256;n++) { let c=n; for(let k=0;k<8;k++) c=(c&1)?(0xedb88320^(c>>>1)):(c>>>1); crcTable[n]=c>>>0; }
  #|    while(offset+12<=bytes.length) {
  #|      const length=bytes.readUInt32BE(offset), start=offset+8, end=start+length;
  #|      if(length>1000000 || end+4>bytes.length) return [];
  #|      const type=bytes.toString("ascii",offset+4,offset+8);
  #|      let crc=0xffffffff;
  #|      for(let i=offset+4;i<end;i++) crc=crcTable[(crc^bytes[i])&255]^(crc>>>8);
  #|      if(((crc^0xffffffff)>>>0)!==bytes.readUInt32BE(end)) return [];
  #|      if(type==="IHDR") {
  #|        if(seenIHDR || length!==13 || offset!==8) return [];
  #|        seenIHDR=true; width=bytes.readUInt32BE(start); height=bytes.readUInt32BE(start+4);
  #|        color=bytes[start+9]; channels=({0:1,2:3,4:2,6:4})[color] || 0;
  #|        if(width<1 || height<1 || width>64 || height>64 || bytes[start+8]!==8 || !channels || bytes[start+10]!==0 || bytes[start+11]!==0 || bytes[start+12]!==0) return [];
  #|      } else if(type==="IDAT") {
  #|        if(!seenIHDR) return []; pieces.push(bytes.subarray(start,end));
  #|      } else if(type==="IEND") {
  #|        if(length!==0 || end+4!==bytes.length) return []; seenIEND=true; break;
  #|      } else if((bytes[offset+4]&32)===0) return [];
  #|      offset=end+4;
  #|    }
  #|    if(!seenIHDR || !seenIEND || !pieces.length) return [];
  #|    const rowBytes=width*channels, expected=height*(rowBytes+1);
  #|    const raw=zlib.inflateSync(Buffer.concat(pieces),{maxOutputLength:expected+1});
  #|    if(raw.length!==expected) return [];
  #|    const gray=Buffer.alloc(width*height); let previous=Buffer.alloc(rowBytes), pos=0;
  #|    for(let y=0;y<height;y++) {
  #|      const filter=raw[pos++], row=Buffer.alloc(rowBytes);
  #|      if(filter>4) return [];
  #|      for(let x=0;x<rowBytes;x++) {
  #|        const left=x>=channels?row[x-channels]:0, up=previous[x], upperLeft=x>=channels?previous[x-channels]:0;
  #|        let prediction=0;
  #|        if(filter===1) prediction=left;
  #|        if(filter===2) prediction=up;
  #|        if(filter===3) prediction=Math.floor((left+up)/2);
  #|        if(filter===4) { const p=left+up-upperLeft, a=Math.abs(p-left), b=Math.abs(p-up), c=Math.abs(p-upperLeft); prediction=a<=b && a<=c?left:b<=c?up:upperLeft; }
  #|        row[x]=(raw[pos++]+prediction)&255;
  #|      }
  #|      for(let x=0;x<width;x++) {
  #|        const at=x*channels;
  #|        let intensity=color===0 || color===4?row[at]:Math.round(0.2126*row[at]+0.7152*row[at+1]+0.0722*row[at+2]);
  #|        if(color===4 || color===6) { const alpha=row[at+channels-1]; intensity=Math.round((intensity*alpha+255*(255-alpha))/255); }
  #|        gray[y*width+x]=intensity;
  #|      }
  #|      previous=row;
  #|    }
  #|    return Array.from(Buffer.concat([Buffer.from(`P5\n${width} ${height}\n255\n`),gray]));
  #|  } catch (_) { return []; }
  #|}

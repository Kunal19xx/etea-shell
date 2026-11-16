.pragma library

// MD5 of a string's UTF-8 bytes, in lowercase hex: what Qt.md5 gives, without going
// through OpenSSL, which now takes milliseconds a call. Each answer is kept, since the same
// paths are hashed over and over.

const known = new Map();

const shifts = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];
const sines = [];
for (let i = 0; i < 64; i++)
    sines.push(Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296) | 0);

function utf8(text) {
    const bytes = [];
    for (const char of text) {
        const code = char.codePointAt(0);
        if (code < 0x80)
            bytes.push(code);
        else if (code < 0x800)
            bytes.push(0xc0 | code >> 6, 0x80 | code & 63);
        else if (code < 0x10000)
            bytes.push(0xe0 | code >> 12, 0x80 | code >> 6 & 63, 0x80 | code & 63);
        else
            bytes.push(0xf0 | code >> 18, 0x80 | code >> 12 & 63, 0x80 | code >> 6 & 63, 0x80 | code & 63);
    }
    return bytes;
}

function digest(text) {
    const bytes = utf8(text);
    const length = bytes.length;
    // Padded to 56 bytes mod 64, then the length in bits, little-endian
    bytes.push(0x80);
    while (bytes.length % 64 !== 56)
        bytes.push(0);
    const bits = length * 8;
    for (let i = 0; i < 8; i++)
        bytes.push(i < 4 ? bits >>> (8 * i) & 255 : Math.floor(bits / 4294967296) >>> (8 * (i - 4)) & 255);

    let a0 = 0x67452301, b0 = 0xefcdab89 | 0, c0 = 0x98badcfe | 0, d0 = 0x10325476;
    const words = new Array(16);
    for (let block = 0; block < bytes.length; block += 64) {
        for (let i = 0; i < 16; i++) {
            const at = block + i * 4;
            words[i] = bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16 | bytes[at + 3] << 24;
        }
        let a = a0, b = b0, c = c0, d = d0;
        for (let i = 0; i < 64; i++) {
            let f, g;
            if (i < 16) {
                f = b & c | ~b & d;
                g = i;
            } else if (i < 32) {
                f = d & b | ~d & c;
                g = (5 * i + 1) % 16;
            } else if (i < 48) {
                f = b ^ c ^ d;
                g = (3 * i + 5) % 16;
            } else {
                f = c ^ (b | ~d);
                g = 7 * i % 16;
            }
            const turned = (a + f + sines[i] + words[g]) | 0;
            a = d;
            d = c;
            c = b;
            b = (b + (turned << shifts[i] | turned >>> (32 - shifts[i]))) | 0;
        }
        a0 = (a0 + a) | 0;
        b0 = (b0 + b) | 0;
        c0 = (c0 + c) | 0;
        d0 = (d0 + d) | 0;
    }
    let hex = "";
    for (const word of [a0, b0, c0, d0])
        for (let i = 0; i < 4; i++)
            hex += (word >>> (8 * i) & 255).toString(16).padStart(2, "0");
    return hex;
}

function md5(text) {
    text = String(text);
    let hex = known.get(text);
    if (hex === undefined) {
        hex = digest(text);
        known.set(text, hex);
    }
    return hex;
}

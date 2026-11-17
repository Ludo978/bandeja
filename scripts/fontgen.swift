// Rasterizes a TrueType font at an em size into an AngelCode BMFont text descriptor (.fnt) and one
// PNG page (white glyphs, coverage in alpha), for Connect IQ's font resources.
// Usage: fontgen <font.ttf> <em px> <charset file (UTF-8)> <out dir> <name>
// Metrics follow Roboto's vertical metrics as the Connect IQ vector fonts use them: line height
// round(em * (ascender + descender) / unitsPerEm), base round(em * ascender / unitsPerEm).
import AppKit
import ImageIO
import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count == 6 else { print("usage: fontgen font.ttf em charset outdir name"); exit(2) }
let fontURL = URL(fileURLWithPath: args[1])
let em = CGFloat(Double(args[2])!)
let charset = try! String(contentsOfFile: args[3], encoding: .utf8)
let outDir = args[4]
let name = args[5]

let provider = CGDataProvider(url: fontURL as CFURL)!
let cgFont = CGFont(provider)!
let font = CTFontCreateWithGraphicsFont(cgFont, em, nil, nil)
let ascent = CTFontGetAscent(font)
let descent = CTFontGetDescent(font)
let lineHeight = Int((ascent + descent).rounded())
let base = Int(ascent.rounded())

struct Glyph { var code: UInt32; var glyph: CGGlyph; var rect: CGRect; var advance: CGFloat }
var glyphs: [Glyph] = []
var seen = Set<UInt32>()
for scalar in charset.unicodeScalars where scalar.value >= 0x20 && !seen.contains(scalar.value) {
    seen.insert(scalar.value)
    var utf16 = Array(String(scalar).utf16)
    var g = [CGGlyph](repeating: 0, count: utf16.count)
    guard CTFontGetGlyphsForCharacters(font, &utf16, &g, utf16.count), g[0] != 0 else { continue }
    var rect = CGRect.zero
    CTFontGetBoundingRectsForGlyphs(font, .horizontal, [g[0]], &rect, 1)
    var adv = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, [g[0]], &adv, 1)
    glyphs.append(Glyph(code: scalar.value, glyph: g[0], rect: rect, advance: adv.width))
}

// Each glyph's cell: its ink box grown to whole pixels, plus a pixel of padding for the antialiasing.
let pad = 1
struct Cell { var g: Glyph; var x = 0; var y = 0; var w = 0; var h = 0; var left = 0; var top = 0 }
var cells: [Cell] = glyphs.map { g in
    var c = Cell(g: g)
    if g.rect.isEmpty {
        c.w = 0; c.h = 0; c.left = 0; c.top = 0
    } else {
        let minX = Int(floor(g.rect.minX)) - pad
        let maxX = Int(ceil(g.rect.maxX)) + pad
        let minY = Int(floor(g.rect.minY)) - pad
        let maxY = Int(ceil(g.rect.maxY)) + pad
        c.left = minX; c.top = maxY
        c.w = maxX - minX; c.h = maxY - minY
    }
    return c
}

// Shelf packing into a page about as wide as it is high.
let area = cells.reduce(0) { $0 + ($1.w + 1) * ($1.h + 1) }
var pageW = max(64, Int(sqrt(Double(area)) * 1.15))
pageW = (pageW + 3) / 4 * 4
var x = 0, y = 0, shelf = 0
for i in cells.indices.sorted(by: { cells[$0].h > cells[$1].h }) {
    if x + cells[i].w > pageW { x = 0; y += shelf + 1; shelf = 0 }
    cells[i].x = x; cells[i].y = y
    x += cells[i].w + 1
    shelf = max(shelf, cells[i].h)
}
let pageH = y + shelf + 1

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pageW, pixelsHigh: pageH, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
let cg = ctx.cgContext
cg.clear(CGRect(x: 0, y: 0, width: pageW, height: pageH))
cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)
cg.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
for c in cells where c.w > 0 {
    // The context's origin is bottom-left: the cell's top-left (c.x, c.y) from the page's top.
    let originX = CGFloat(c.x - c.left)
    let originY = CGFloat(pageH - c.y - c.top)
    var glyph = c.g.glyph
    var pos = CGPoint(x: originX, y: originY)
    CTFontDrawGlyphs(font, &glyph, &pos, 1, cg)
}
cg.flush()
// The page as drawn: premultiplied white, so each pixel's red, green, blue and alpha are all its
// coverage. Written as they are (not unpremultiplied, which would make every touched pixel pure white):
// the resource compiler reads the coverage from the color, so an edge pixel stays partly lit.
let pngName = "\(name).png"
let bytes = Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * pageH)
let page = CGImage(width: pageW, height: pageH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rep.bytesPerRow,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                   provider: CGDataProvider(data: bytes as CFData)!, decode: nil, shouldInterpolate: false,
                   intent: .defaultIntent)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/\(pngName)") as CFURL,
                                           "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, page, nil)
CGImageDestinationFinalize(dest)

var fnt = "info face=\"\(name)\" size=\(Int(em)) bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1\n"
fnt += "common lineHeight=\(lineHeight) base=\(base) scaleW=\(pageW) scaleH=\(pageH) pages=1 packed=0\n"
fnt += "page id=0 file=\"\(pngName)\"\n"
fnt += "chars count=\(cells.count)\n"
for c in cells.sorted(by: { $0.g.code < $1.g.code }) {
    let xoffset = c.w > 0 ? c.left : 0
    let yoffset = c.w > 0 ? base - c.top : 0
    fnt += "char id=\(c.g.code) x=\(c.x) y=\(c.y) width=\(c.w) height=\(c.h) xoffset=\(xoffset) yoffset=\(yoffset) xadvance=\(Int(c.g.advance.rounded())) page=0 chnl=15\n"
}
try! fnt.write(toFile: "\(outDir)/\(name).fnt", atomically: true, encoding: .utf8)
print("\(name): \(cells.count) glyphs, page \(pageW)x\(pageH), line \(lineHeight), base \(base)")

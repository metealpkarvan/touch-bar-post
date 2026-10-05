import AppKit
import Foundation
let folder = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
for (pixels,name) in [(16,"icon_16x16"),(32,"icon_16x16@2x"),(32,"icon_32x32"),(64,"icon_32x32@2x"),(128,"icon_128x128"),(256,"icon_128x128@2x"),(256,"icon_256x256"),(512,"icon_256x256@2x"),(512,"icon_512x512"),(1024,"icon_512x512@2x")] {
    let size = CGFloat(pixels)
    let image = NSImage(size:NSSize(width:size,height:size)); image.lockFocus()
    NSColor(calibratedRed:0.065,green:0.085,blue:0.105,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:0,y:0,width:size,height:size),xRadius:size*0.22,yRadius:size*0.22).fill()
    let rect = NSRect(x:size*0.13,y:size*0.32,width:size*0.74,height:size*0.36)
    NSColor(calibratedRed:0.37,green:0.86,blue:0.84,alpha:1).setFill()
    NSBezierPath(roundedRect:rect,xRadius:size*0.065,yRadius:size*0.065).fill()
    NSColor(calibratedRed:0.05,green:0.14,blue:0.15,alpha:1).setStroke()
    let flap = NSBezierPath(); flap.move(to:NSPoint(x:rect.minX+size*0.04,y:rect.maxY-size*0.04)); flap.line(to:NSPoint(x:size*0.5,y:size*0.46)); flap.line(to:NSPoint(x:rect.maxX-size*0.04,y:rect.maxY-size*0.04)); flap.lineWidth = max(1,size*0.025); flap.stroke()
    NSColor(calibratedRed:1,green:0.72,blue:0.32,alpha:1).setFill(); NSBezierPath(ovalIn:NSRect(x:size*0.72,y:size*0.62,width:size*0.14,height:size*0.14)).fill()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
    try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(name+".png"))
}

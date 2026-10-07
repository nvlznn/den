import AppKit
let base = URL(fileURLWithPath:CommandLine.arguments[0]).deletingLastPathComponent()
let out=base.deletingLastPathComponent()
let sprites = try! JSONSerialization.jsonObject(with:Data(contentsOf:base.appendingPathComponent("sprites.json"))) as! [String:[String:Any]]
func col(_ s:String)->NSColor { let v=Int(s,radix:16)!; return NSColor(srgbRed:CGFloat(v>>16&255)/255,green:CGFloat(v>>8&255)/255,blue:CGFloat(v&255)/255,alpha:1) }
let ink=col("283429"), cream=col("F4F0E5"), green=col("A6B58D"), muted=col("65735A"), dark=col("171D18")
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ c:NSColor){c.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:r,yRadius:r).fill()}
func txt(_ t:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat,_ c:NSColor = ink,_ weight:NSFont.Weight = .bold,_ center:Bool=true){
 let p=NSMutableParagraphStyle();p.alignment=center ? .center : .left;p.lineSpacing = -2
 let f=NSFont.systemFont(ofSize:size,weight:weight);let font=NSFont(descriptor:f.fontDescriptor.withDesign(.rounded)!,size:size)!
 (t as NSString).draw(in:NSRect(x:x,y:y,width:w,height:250),withAttributes:[.font:font,.foregroundColor:c,.paragraphStyle:p])
}
func sprite(_ id:String,_ frame:String="idle",_ x:CGFloat,_ y:CGFloat,_ cell:CGFloat,_ c:NSColor=ink){
 let rows=sprites[id]![frame] as! [String];c.setFill()
 for (j,row) in rows.enumerated(){for(i,ch) in row.enumerated() where ch == "#" {NSRect(x:x+CGFloat(i)*cell,y:y+CGFloat(j)*cell,width:cell,height:cell).fill()}}
}
func sticker(_ id:String,_ frame:String,_ x:CGFloat,_ y:CGFloat,_ cell:CGFloat){
 let rows=sprites[id]![frame] as! [String];cream.setFill()
 for (j,row) in rows.enumerated(){for(i,ch) in row.enumerated() where ch == "#" {NSRect(x:x+CGFloat(i)*cell-3,y:y+CGFloat(j)*cell-3,width:cell+6,height:cell+6).fill()}}
 sprite(id,frame,x,y,cell)
}
func sparkle(_ x:CGFloat,_ y:CGFloat,_ s:CGFloat,_ c:NSColor=ink){box(x+s,y,s,s*3,0,c);box(x,y+s,s*3,s,0,c)}
func panel(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){box(x,y,w,h,28,green)}
func phone(_ name:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ angle:CGFloat=0){
 let h=w*2622/1206
 NSGraphicsContext.saveGraphicsState()
 NSGraphicsContext.current!.cgContext.translateBy(x:x+w/2,y:y+h/2)
 NSGraphicsContext.current!.cgContext.rotate(by:angle * .pi / 180)
 box(-w/2-9,-h/2-9,w+18,h+18,51,col("53634C"));box(-w/2-5,-h/2-5,w+10,h+10,47,col("111511"))
 NSBezierPath(roundedRect:NSRect(x:-w/2,y:-h/2,width:w,height:h),xRadius:43,yRadius:43).addClip()
 let im=NSImage(contentsOf:base.appendingPathComponent(name+".png"))!
 im.draw(in:NSRect(x:-w/2,y:-h/2,width:w,height:h),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
 // Current iPhone hardware silhouette: centered Dynamic Island above the app UI.
 box(-w*0.16,-h/2+16,w*0.32,16,8,col("050505"))
 NSGraphicsContext.restoreGraphicsState()
}
func heading(_ title:String,_ sub:String,_ darkMode:Bool=false){txt("den",40,42,523,23,darkMode ? green : muted);txt(title,30,103,543,57,darkMode ? cream : ink);txt(sub,42,247,519,21,darkMode ? green : muted,.medium)}
func canvas(_ file:String,_ darkMode:Bool=false,_ body:()->Void){
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1206,pixelsHigh:2622,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let ctx=NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=ctx
 ctx.cgContext.translateBy(x:0,y:2622);ctx.cgContext.scaleBy(x:2,y:-2);NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx.cgContext,flipped:true)
 box(0,0,603,1311,0,darkMode ? dark : cream)
 // A soft circular field ties the series to the app's LCD palette.
 (darkMode ? col("232D23") : col("E3E8D5")).setFill();NSBezierPath(ovalIn:NSRect(x:-135,y:360,width:870,height:870)).fill()
 body();NSGraphicsContext.restoreGraphicsState()
 let rgb=CGContext(data:nil,width:1206,height:2622,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 rgb.draw(rep.cgImage!,in:CGRect(x:0,y:0,width:1206,height:2622))
 let opaque=NSBitmapImageRep(cgImage:rgb.makeImage()!)
 try! opaque.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("screenshots/"+file+".png"))
}
canvas("01-choose-your-egg"){
 heading("Big journeys.\nLittle eggs.","Choose your first companion.")
 panel(92,326,192,199);sprite("egg.white","idle",119,345,9)
 panel(319,326,192,199);sprite("egg.black","idle",346,345,9)
 txt("White Egg",92,481,192,18,ink,.semibold);txt("Black Egg",319,481,192,18,ink,.semibold)
 phone("01-focus",134,557,335)
}
canvas("02-hatch-a-friend"){
 heading("A little focus.\nA new friend.","Hatch a surprise at level 1.")
 panel(102,335,154,160);sprite("egg.white","idle",120,351,7)
 txt("→",263,380,77,46,muted,.semibold)
 panel(348,335,154,160);sprite("mochi","happy",366,351,7)
 phone("03-celebration",134,522,335)
}
canvas("03-focus-together",true){
 heading("Better with\na little friend.","Keep each other company.",true)
 phone("02-focusing",134,400,335)
}
canvas("04-no-pressure"){
 heading("No streaks.\nNo pressure.","Your pace. Your little happy place.")
 phone("01-focus",134,400,335)
}
canvas("05-collect-companions"){
 heading("Small friends.\nBig collection.","Who will hatch next?")
 let ids=["fangfang","mochi","doudou","drop","orb","cloud"]
 for(i,id) in ids.enumerated(){
  let x=CGFloat(i%3)*177+40;let y=CGFloat(i/3)*214+370
  panel(x,y,169,184);sprite(id,"happy",x+36,y+20,6)
  txt(sprites[id]!["name"] as! String,x,y+143,169,18,ink,.semibold)
 }
 // Eggs reinforce discovery while leaving the collection tiles clear.
 sprite("egg.white","idle",179,956,5,muted)
 sprite("egg.black","idle",344,956,5,muted)
 txt("Collect at your own pace.",100,1070,403,21,muted,.medium)
}
canvas("06-focus-at-a-glance"){
 heading("Your focus.\nAll in one place.","A clearer picture of how you spend your time.")
 // Two true-to-app chart cards, composed from the six-tag demo dataset.
 box(34,329,535,428,31,col("202120"));txt("FOCUS TIME",58,350,487,16,muted,.bold,false)
 txt("September 2026",58,382,487,23,cream,.semibold,false)
 let vals:[CGFloat]=[4.7,3.8,1.0,4.0,2.9,4.6,2.1,3.5,3.9,1.3,2.5,4.7,3.8,1.0,4.0,2.9,4.6,2.1,3.5,3.9,1.3,2.5,4.7,3.8,1.0,4.0,2.9,4.6,2.1,3.5]
 let bx:CGFloat=83, by:CGFloat=444, bw:CGFloat=440, bh:CGFloat=225, gap:CGFloat=4
 for g in 0..<4 {let gy=by+CGFloat(g)*bh/3;col("3A4038").setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:bx,y:gy));p.line(to:NSPoint(x:bx+bw,y:gy));p.lineWidth=0.7;p.stroke()}
 for(i,v) in vals.enumerated(){let x=bx+CGFloat(i)*(bw/30)+gap/2;let h=CGFloat(v/6)*bh;box(x,by+bh-h,bw/30-gap,h,3,col("A6B58D"))}
 txt("1",bx-4,680,32,13,muted,.medium);txt("8",bx+CGFloat(7)*bw/30-10,680,32,13,muted,.medium);txt("15",bx+CGFloat(14)*bw/30-13,680,38,13,muted,.medium);txt("22",bx+CGFloat(21)*bw/30-13,680,38,13,muted,.medium);txt("29",bx+CGFloat(28)*bw/30-13,680,38,13,muted,.medium)
 box(34,779,535,482,31,col("202120"));txt("TAGS",58,801,487,16,muted,.bold,false)
 txt("95 hr 20 min",58,831,487,29,cream,.bold,false)
 let colors=["0A84FF","FF5A00","00A87A","E69A00","EB438B","17B719"]
 let names=["Study","Deep Work","Writing","Reading","Creative","Languages"]
 let mins:[CGFloat]=[1510,1430,1055,900,525,300]
 let centerX:CGFloat=175; let centerY:CGFloat=1053; let radius:CGFloat=84
 var angle:CGFloat = -.pi/2
 for(i,value) in mins.enumerated(){let sweep=value/5720 * 2 * CGFloat.pi;let path=NSBezierPath();path.lineWidth=23;path.lineCapStyle = .butt;path.appendArc(withCenter:NSPoint(x:centerX,y:centerY),radius:radius,startAngle:angle * 180 / CGFloat.pi,endAngle:(angle+sweep) * 180 / CGFloat.pi,clockwise:false);col(colors[i]).setStroke();path.stroke();angle += sweep}
 txt("95h",centerX-45,1041,90,21,cream,.bold)
 for i in 0..<6 {let y=925+CGFloat(i)*48;box(306,y+6,12,12,6,col(colors[i]));txt(names[i],329,y,155,17,cream,.medium,false);txt(["26%","25%","18%","16%","9%","5%"][i],486,y,57,17,muted,.semibold,false)}
}
canvas("07-widgets",true){
 heading("Little friends.\nRight here.","Home Screen & Lock Screen widgets.",true)
 // Faithful promotional compositions of the current widget families.
 box(42,365,519,240,32,col("222422"));panel(57,380,211,210);sprite("mochi","idle",75,397,11);txt("Lv 6",69,391,80,16,ink,.bold,false)
 txt("1 hr 40 min",288,416,253,32,cream,.bold,false);txt("3 sessions",288,464,230,20,green,.medium,false);box(290,528,237,6,3,col("474D43"));box(290,528,139,6,3,green)
 box(42,635,247,277,32,col("222422"));panel(58,650,215,182);sprite("fangfang","idle",86,655,10);txt("1 hr 40 min",57,850,215,24,cream)
 box(317,635,244,277,32,col("222422"));panel(332,650,214,182);sprite("cloud","idle",359,655,10);txt("3 sessions",333,850,213,24,cream)
 txt("9:41",65,958,473,107,cream,.medium)
 box(81,1095,132,132,66,col("354131"));sprite("mochi","idle",111,1099,4.5,cream);txt("1:40",100,1181,95,22,cream)
 box(238,1095,284,132,27,col("354131"));sprite("fangfang","idle",252,1125,5,cream);txt("1 hr 40 min",347,1124,165,23,cream,.bold,false);txt("3 sessions",347,1162,165,17,green,.medium,false)
}
// Contact sheet, kept outside the upload folder.
let files=try! FileManager.default.contentsOfDirectory(at:out.appendingPathComponent("screenshots"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2167,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep);box(0,0,2167,720,0,col("D8DDCC"))
for(i,f) in files.enumerated(){NSImage(contentsOf:f)!.draw(in:NSRect(x:CGFloat(i)*307+16,y:40,width:291,height:633))}
try! rep.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("overview.png"))

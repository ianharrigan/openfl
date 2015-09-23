package openfl._internal.renderer.dom;

import haxe.io.Bytes;
import js.Browser;
import lime.graphics.Image;
import lime.graphics.utils.ImageCanvasUtil;
import lime.utils.UInt8Array;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.GradientType;
import openfl.display.Stage;
import js.html.Element;


typedef StrokeOptions = {
	@:optional var lineThickness:Null<Float>;
	@:optional var lineColor:Null<Int>;
	@:optional var lineAlpha:Null<Float>;
	
	@:optional var lineGradientType:GradientType;
	@:optional var lineGradientColors:Array<Dynamic>;
	@:optional var lineGradientAlphas:Array<Dynamic>;
	@:optional var lineGradientRatios:Array<Dynamic>;
}

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(lime.graphics.ImageBuffer)

class DOMElements {
	public static var map:Map<DisplayObject, Element> = new Map<DisplayObject, Element>();
	
	public static inline function createElement(shape:DisplayObject):Element {
		createGlobalCss();
		
		var el:Element = Browser.document.createElement("div");
		var type:String = "shape";
		el.classList.add(type);
		if (Std.is(shape.parent, Stage)) {
			Browser.document.body.appendChild(el);
			map.set(shape, el);
		} else {
			var parentEl:Element = map.get(shape.parent);
			if (parentEl != null) {
				parentEl.appendChild(el);
				map.set(shape, el);
			}
		}
		applyStyle(shape);
		return el;
	}
	
	public static inline function destroyElement(shape:DisplayObject):Void {
		var el:Element = map.get(shape);
		if (el != null) {
			el.remove();
		}
	}
	
	public static inline function applyStyle(shape:DisplayObject):Void {
		var el:Element = map.get(shape);
		if (el == null) {
			return;
		}
		
		var cx:Float = shape.__graphics.__bounds.width;
		var cy:Float = shape.__graphics.__bounds.height;
		el.style.left = shape.x + "px";
		el.style.top = shape.y + "px";
		el.style.width = cx + "px";
		el.style.height = cy + "px";
		
		if (Std.is(shape.parent, Stage)) {
			el.style.left = shape.x + 400 + "px";
		}
	}
	
	public static inline function renderBorder(el:Element, x:Float, y:Float, cx:Float, cy:Float, strokeOptions:StrokeOptions) {
		if (strokeOptions.lineThickness != null) {
			cx += strokeOptions.lineThickness;
			cy += strokeOptions.lineThickness;
		}
		el.style.left = x + "px";
		el.style.top = y + "px";
		el.style.width = cx + "px";
		el.style.height = cy + "px";
		
		if (strokeOptions.lineThickness != null) {
			//sub.style.boxShadow = "inset 0px 0px 0px " + lineThickness + "px " + color(lineColor, lineAlpha);
			el.style.border = strokeOptions.lineThickness + "px solid " + color(strokeOptions.lineColor, strokeOptions.lineAlpha);
			var t = strokeOptions.lineThickness * 0.5;
			el.style.transform = "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -" + t + ", -" + t + ", 0, 1)";
			el.style.borderRadius = t + "px";
		}
		
		if (strokeOptions.lineGradientType != null) {
			el.style.borderImage = "linear-gradient(to bottom, "
				+ color(strokeOptions.lineGradientColors[0]) + " 0%, "
				+ color(strokeOptions.lineGradientColors[1]) + " 100%)";
			el.style.borderImageSlice = "1";
		}

	}
											 
	
	public static inline function renderGraphics(shape:DisplayObject):Void {
		var el:Element = map.get(shape);
		if (el == null) {
			return;
		}
		
		while (el.firstChild != null) { // remove all children (how does "graphics.clear" work??")
			el.removeChild(el.firstChild);
		}
		
		var data = new DrawCommandReader(shape.__graphics.__commands);
		var sub:Element = null;
		
		/*
		var lineThickness:Null<Float> = null;
		var lineColor:Null<Int> = null;
		var lineAlpha:Null<Float> = null;
		
		var lineGradientType:GradientType = null;
		var lineGradientColors:Array<Dynamic> = null;
		var lineGradientAlphas:Array<Dynamic> = null;
		var lineGradientRatios:Array<Dynamic> = null;
		*/
		
		var strokeOptions:StrokeOptions = {};
		
		for (type in shape.__graphics.__commands.types) {
			switch (type) {
				case LINE_STYLE:
					var c = data.readLineStyle();
					strokeOptions.lineThickness = c.thickness;
					strokeOptions.lineColor = c.color;
					strokeOptions.lineAlpha = c.alpha;
					/*
					strokeOptions = {
						lineThickness = c.thickness;
						lineColor = c.color;
						lineAlpha = c.alpha;
					};
					*/
				
				case LINE_GRADIENT_STYLE:	
					var c = data.readLineGradientStyle();
					strokeOptions.lineGradientType = c.type;
					strokeOptions.lineGradientColors = c.colors;
					strokeOptions.lineGradientAlphas = c.alphas;
					strokeOptions.lineGradientRatios = c.ratios;
					
				case LINE_BITMAP_STYLE:
					var c = data.readLineBitmapStyle ();
					//strokeCommands.lineBitmapStyle (c.bitmap, c.matrix, c.repeat, c.smooth);
					/*
					trace(c.bitmap);
					trace(ImageCanvasUtil.convertToData(c.bitmap.image));
					trace(c.bitmap);
					*/
					
					var x = createImageBase64(c.bitmap);
					var image = Browser.document.createImageElement();
					image.src = x;
					Browser.document.body.appendChild(image);
					image.style.position = "absolute";
					image.style.left = "0";
					image.style.top = "0";
					trace(x);
					
				case BEGIN_FILL:
				case DRAW_RECT:
					sub = Browser.document.createElement("div"); 
					sub.classList.add("shape");

					var c = data.readDrawRect();
					renderBorder(sub, c.x, c.y, c.width, c.height, strokeOptions);
				case DRAW_ROUND_RECT:	
					sub = Browser.document.createElement("div"); 
					sub.classList.add("shape");

					var c = data.readDrawRoundRect();
					renderBorder(sub, c.x, c.y, c.width, c.height, strokeOptions);
					
					if (c.rx == c.ry) {
						sub.style.borderRadius = Math.fceil(c.rx * 0.5) + "px";
					} else {
						var rx:Float = Math.fceil(c.rx * 0.5);
						var ry:Float = Math.fceil(c.ry * 0.5);
						
						var s = rx + "px " + ry + "px";
						sub.style.borderTopLeftRadius = s;
						sub.style.borderTopRightRadius = s;
						sub.style.borderBottomLeftRadius = s;
						sub.style.borderBottomRightRadius = s;
					}
					
				case END_FILL:
					if (sub != null) {
						el.appendChild(sub);
					}

				default:
					data.skip(type);
			}
		}
	}
	
	private static function createImageBase64(b:BitmapData):String {
		//trace(b);
		//return "";
		var b = b.clone(); // probably doesnt make sense, or to be creating images at all
		ImageCanvasUtil.convertToData(b.image);
		trace(b);
		//var ba:UInt8Array = new UInt8Array();
		//ba = b.image.buffer.data;
		trace(b.image.buffer.data.buffer);
		trace(b.image.buffer.__srcImageData.data.buffer);
		trace(Image.fromBytes(b.image.buffer.data.buffer));
		
		/*
		for (i in 0...b.image.buffer.data.buffer.byteLength) {
			trace(b.image.buffer.data.);
		}
		*/
		
		var bytes:Bytes = Bytes.ofData(b.image.buffer.data.buffer);
		//var bytes:Bytes = b.image.buffer.__srcImageData.data.buffer.toBytes();
		trace(bytes.length);
		var base64:String = haxe.crypto.Base64.encode(bytes);
		var imgSrc:String = "data:image/png;base64," + base64;
		return imgSrc;
	}
	
	public static inline function isComplexGraphics(shape:DisplayObject):Bool {
		var complex:Bool = false;
		
		var data = new DrawCommandReader(shape.__graphics.__commands);
		for (type in shape.__graphics.__commands.types) {
			switch (type) {
				case CUBIC_CURVE_TO
					| CURVE_TO
					| DRAW_TRIANGLES
					| DRAW_TILES
					| DRAW_PATH
					| LINE_TO:	
						complex = true;
				default:		
			}
			
			if (complex == true) {
				break;
			}
		}
		return complex;
	}
	
	private static var _globalStyleAdded:Bool = false;
	private static inline function createGlobalCss():Void {
		if (_globalStyleAdded == false) {
			_globalStyleAdded = true;
			
			var style = Browser.document.createElement("style");
			Browser.document.head.appendChild(style);
			style.innerHTML = ".shape { __background-color: red; position: absolute; box-sizing: border-box; pointer-events: none; }\n";
		}
	}
	
	private static inline function color(c:Int, opacity:Float = 1, forceRGB:Bool = false):String {
		var s:String = "";
		if (opacity >= 1) {
			if (forceRGB == true) {
				s = "rgb(" + r(c) + "," + g(c) + "," + b(c) + ")";
			} else {
				s = "#" + StringTools.hex(c, 6);
			}
		} else {
			s = "rgba(" + r(c) + "," + g(c) + "," + b(c) + "," + opacity + ")";
		}
		return s;
	}
	
	private static inline function r(c:Int):Float {
		return ((c >> 16) & 255) / 255;
	}
	
	private static inline function g(c:Int):Float {
		return ((c >> 8) & 255) / 255;
	}
	
	private static inline function b(c:Int):Float {
		return (c & 255) / 255;
	}
}

/*
UNKNOWN
OVERRIDE_MATRIX
MOVE_TO
LINE_TO
LINE_STYLE
LINE_GRADIENT_STYLE
LINE_BITMAP_STYLE
END_FILL
DRAW_TRIANGLES
DRAW_TILES
DRAW_ROUND_RECT
DRAW_RECT
DRAW_PATH
DRAW_ELLIPSE
DRAW_CIRCLE
CURVE_TO
CUBIC_CURVE_TO
BEGIN_GRADIENT_FILL
BEGIN_FILL
BEGIN_BITMAP_FILL
*/
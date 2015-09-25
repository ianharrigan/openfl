package openfl._internal.renderer.dom;

import js.Browser;
import js.html.Element;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.GradientType;
import openfl.display.Stage;

typedef ColorOptions = {
	@:optional var thickness:Null<Float>;
	@:optional var color:Null<Int>;
	@:optional var alpha:Null<Float>;
}

typedef GradientOptions = {
	@:optional var type:GradientType;
	@:optional var colors:Array<Dynamic>;
	@:optional var alphas:Array<Dynamic>;
	@:optional var ratios:Array<Dynamic>;
}

typedef BitmapOptions = {
	@:optional var base64:String;
	@:optional var width:Null<Int>;
	@:optional var height:Null<Int>;
}

typedef StrokeOptions = {
	@:optional var lineThickness:Null<Float>;
	@:optional var lineColor:Null<Int>;
	@:optional var lineAlpha:Null<Float>;
	
	@:optional var lineGradientType:GradientType;
	@:optional var lineGradientColors:Array<Dynamic>;
	@:optional var lineGradientAlphas:Array<Dynamic>;
	@:optional var lineGradientRatios:Array<Dynamic>;
	
	@:optional var lineBitmapBase64:String;
	@:optional var lineBitmapWidth:Null<Int>;
	@:optional var lineBitmapHeight:Null<Int>;

}

typedef FillOptions = {
	@:optional var fillColor:Null<Int>;
	@:optional var fillAlpha:Null<Float>;
	
	@:optional var fillGradientType:GradientType;
	@:optional var fillGradientColors:Array<Dynamic>;
	@:optional var fillGradientAlphas:Array<Dynamic>;
	@:optional var fillGradientRatios:Array<Dynamic>;
	
	@:optional var fillBitmapBase64:String;
	@:optional var fillBitmapWidth:Null<Int>;
	@:optional var fillBitmapHeight:Null<Int>;
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
	
	public static inline function renderBorder(primitive:String, el:Element, x:Float, y:Float, cx:Float, cy:Float, strokeOptions:StrokeOptions) {
		if (strokeOptions.lineThickness != null) {
			cx += strokeOptions.lineThickness;
			cy += strokeOptions.lineThickness;
		}
		el.style.left = x + "px";
		el.style.top = y + "px";
		el.style.width = cx + "px";
		el.style.height = cy + "px";
		
		var t:Float = 0;
		if (strokeOptions.lineThickness != null) {
			t = strokeOptions.lineThickness * 0.5;
			//sub.style.boxShadow = "inset 0px 0px 0px " + lineThickness + "px " + color(lineColor, lineAlpha);
			if (strokeOptions.lineGradientType == null && strokeOptions.lineBitmapBase64 == null) {
				el.style.border = strokeOptions.lineThickness + "px solid " + color(strokeOptions.lineColor, strokeOptions.lineAlpha);
			}
			
			if (primitive == "circle") {
				t = cx * 0.5;
			} else if (primitive == "ellipse") {
				el.style.borderRadius = "50%";
			}
		}
		
		if (strokeOptions.lineGradientType != null || strokeOptions.lineBitmapBase64 != null) {
			if (primitive == "rectangle") {
				var l:Float = strokeOptions.lineThickness; // 6
				var cx2:Float = cx - l;
				var cy2:Float = cy - l;
				el.style.setProperty("-webkit-clip-path", 'polygon(0 0,' 
																+ '0 ${cy}px,'
																+ '${l}px ${cy}px,'
																+ '${l}px ${l}px,'
																+ '${cx2}px ${l}px,'
																+ '${cx2}px ${cy2}px,'
																+ '0 ${cy2}px,'
																+ '0 ${cy}px,'
																+ '${cx}px ${cy}px,'
																+ '${cx}px 0)', null);
			
				if (strokeOptions.lineGradientType != null) {
					el.style.backgroundImage = "linear-gradient(to left, "
						+ color(strokeOptions.lineGradientColors[1]) + " -150%, "
						+ color(strokeOptions.lineGradientColors[0]) + " 250%)";
					//el.style.borderImageSlice = "1";
				} else if (strokeOptions.lineBitmapBase64 != null) {
					el.style.backgroundImage = "url(" + strokeOptions.lineBitmapBase64 + ")";
					el.style.backgroundPosition = '${t}px ${t}px';
				}
			} else if (primitive == "circle" || primitive == "ellipse") { // gradient/image circles are more complex so delegate to svg - probably not used that much
				var svg:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "svg");
				var defs:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "defs");
				svg.appendChild(defs);
				el.appendChild(svg);
				
				var strokeId:String = "id" + Std.random(0xFFFFFF);
				if (primitive == "circle") {
					var circle:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "circle");
					circle.setAttribute("cx", "" + (cx * 0.5));
					circle.setAttribute("cy", "" + (cy * 0.5));
					circle.setAttribute("r", "" + ((cx - strokeOptions.lineThickness) * 0.5));
					circle.setAttribute("stroke-width", "" + strokeOptions.lineThickness);
					circle.setAttribute("stroke", "url(#" + strokeId + ")");
					circle.setAttribute("fill", "transparent");
					svg.appendChild(circle);
				} else if (primitive == "ellipse") {
					var ellipse:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "ellipse");
					ellipse.setAttribute("cx", "" + (cx - strokeOptions.lineThickness));
					ellipse.setAttribute("cy", "" + (cy - strokeOptions.lineThickness));
					ellipse.setAttribute("rx", "" + ((cx - strokeOptions.lineThickness) / 2));
					ellipse.setAttribute("ry", "" + ((cy - strokeOptions.lineThickness) / 2));
					ellipse.setAttribute("stroke-width", "" + strokeOptions.lineThickness);
					ellipse.setAttribute("stroke", "url(#" + strokeId + ")");
					ellipse.setAttribute("fill", "transparent");
					svg.appendChild(ellipse);
				}
				
				if (strokeOptions.lineGradientType != null) {
					var linearGradient:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "linearGradient");
					defs.appendChild(linearGradient);
					linearGradient.setAttribute("id", strokeId);
					linearGradient.setAttribute("x1", "-150%");
					linearGradient.setAttribute("y1", "0%");
					linearGradient.setAttribute("x2", "200%");
					linearGradient.setAttribute("y2", "0%");
					
					var stop:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "stop");
					stop.setAttribute("offset", "-150%");
					stop.setAttribute("stop-color", color(strokeOptions.lineGradientColors[0]));
					linearGradient.appendChild(stop);
					
					var stop:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "stop");
					stop.setAttribute("offset", "200%");
					stop.setAttribute("stop-color", color(strokeOptions.lineGradientColors[1]));
					linearGradient.appendChild(stop);
				} else if (strokeOptions.lineBitmapBase64 != null) {
					var pattern:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "pattern");
					defs.appendChild(pattern);
					pattern.setAttribute("id", strokeId);
					pattern.setAttribute("patternUnits", "userSpaceOnUse");
					pattern.setAttribute("x", "-" + (strokeOptions.lineThickness * 0.5));
					pattern.setAttribute("y", "-" + (strokeOptions.lineThickness * 0.5));
					pattern.setAttribute("height", "" + strokeOptions.lineBitmapWidth);
					pattern.setAttribute("width", "" + strokeOptions.lineBitmapHeight);
					
					var image:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "image");
					image.setAttribute("height", "" + strokeOptions.lineBitmapWidth);
					image.setAttribute("width", "" + strokeOptions.lineBitmapHeight);
					image.setAttributeNS("http://www.w3.org/1999/xlink", "href", strokeOptions.lineBitmapBase64);
					pattern.appendChild(image);
				}
			}
		}
		
		
		if (t > 0) {
			el.style.transform = "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -" + t + ", -" + t + ", 0, 1)";
			if (primitive != "ellipse") {
				el.style.borderRadius = t + "px";
			} else if (strokeOptions.lineGradientType != null || strokeOptions.lineBitmapBase64 != null) {
				el.style.transform = "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -" + Math.ffloor((cx - strokeOptions.lineThickness) * 0.5) + ", -" + Math.ffloor((cy - strokeOptions.lineThickness) * 0.5) + ", 0, 1)";
			}
		}
	}
	
	public static inline function renderFill(primitive:String, el:Element, parent:Element, x:Float, y:Float, cx:Float, cy:Float, fillOptions:FillOptions, strokeOptions:StrokeOptions) {
		if (fillOptions.fillColor != null) {
			if (fillOptions.fillGradientType == null) {
				el.style.backgroundColor = color(fillOptions.fillColor, fillOptions.fillAlpha);
			}
		}

		if (strokeOptions.lineGradientType != null || strokeOptions.lineBitmapBase64 != null) {
			var fill:Element = Browser.document.createElement("div");
			fill.style.left = x + "px";
			fill.style.top = y + "px";
			fill.style.width = cx + "px";
			fill.style.height = cy + "px";
			fill.classList.add("shape");
			
			parent.appendChild(fill);
			el = fill;
		}
		
		var t:Float = 0;
		if (fillOptions.fillGradientType != null || fillOptions.fillBitmapBase64 != null) {
			if (fillOptions.fillGradientType != null) {
				el.style.backgroundImage = "linear-gradient(to left, "
					+ color(fillOptions.fillGradientColors[1]) + " -150%, "
					+ color(fillOptions.fillGradientColors[0]) + " 250%)";
			} else if (fillOptions.fillBitmapBase64 != null) {
				el.style.backgroundImage = "url(" + fillOptions.fillBitmapBase64 + ")";
				el.style.backgroundPosition = '${t}px ${t}px';
			}
		}
		
			
		if (primitive == "circle") {
			t = cx * 0.5;
			el.style.transform = "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -" + t + ", -" + t + ", 0, 1)";
			
			el.style.borderRadius = (cx * 0.5) + "px";
		} else if (primitive == "ellipse") {
			//t = cx * 0.5;
			el.style.transform = "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -" + t + ", -" + t + ", 0, 1)";
			
			el.style.borderRadius = "50%";
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
		var strokeOptions:StrokeOptions = { };
		var fillOptions:FillOptions = {};
		var primitive:String = null;
		
		for (type in shape.__graphics.__commands.types) {
			switch (type) {
				case LINE_STYLE:
					var c = data.readLineStyle();
					strokeOptions.lineThickness = c.thickness;
					strokeOptions.lineColor = c.color;
					strokeOptions.lineAlpha = c.alpha;
				
				case LINE_GRADIENT_STYLE:	
					var c = data.readLineGradientStyle();
					strokeOptions.lineGradientType = c.type;
					strokeOptions.lineGradientColors = c.colors;
					strokeOptions.lineGradientAlphas = c.alphas;
					strokeOptions.lineGradientRatios = c.ratios;
					
				case LINE_BITMAP_STYLE:
					var c = data.readLineBitmapStyle();
					strokeOptions.lineBitmapBase64 = getImageBase64(c.bitmap);
					strokeOptions.lineBitmapWidth = c.bitmap.width;
					strokeOptions.lineBitmapHeight = c.bitmap.height;
					
				case DRAW_RECT:
					if (sub == null) {
						sub = Browser.document.createElement("div"); 
						sub.classList.add("shape");
					}

					var c = data.readDrawRect();
					primitive = "rectangle";
					renderBorder(primitive, sub, c.x, c.y, c.width, c.height, strokeOptions);
					renderFill(primitive, sub, el, c.x, c.y, c.width, c.height, fillOptions, strokeOptions);

				case DRAW_ROUND_RECT:	
					if (sub == null) {
						sub = Browser.document.createElement("div"); 
						sub.classList.add("shape");
					}

					var c = data.readDrawRoundRect();
					primitive = "rectangle";
					renderBorder(primitive, sub, c.x, c.y, c.width, c.height, strokeOptions);
					renderFill(primitive, sub, el, c.x, c.y, c.width, c.height, fillOptions, strokeOptions);
					
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
					
				case DRAW_CIRCLE:	
					if (sub == null) {
						sub = Browser.document.createElement("div"); 
						sub.classList.add("shape");
					}

					var c = data.readDrawCircle();
					primitive = "circle";
					renderBorder(primitive, sub, c.x, c.y, c.radius * 2, c.radius * 2, strokeOptions);
					renderFill(primitive, sub, el, c.x, c.y, c.radius * 2, c.radius * 2, fillOptions, strokeOptions);
				
				case DRAW_ELLIPSE:	
					if (sub == null) {
						sub = Browser.document.createElement("div"); 
						sub.classList.add("shape");
					}
					
					var c = data.readDrawEllipse();
					primitive = "ellipse";
					renderBorder(primitive, sub, c.x, c.y, c.width, c.height, strokeOptions);
					renderFill(primitive, sub, el, c.x, c.y, c.width, c.height, fillOptions, strokeOptions);
					
				case BEGIN_FILL:
					var c = data.readBeginFill();
					fillOptions.fillColor = c.color;
					fillOptions.fillAlpha = c.alpha;
					
				case BEGIN_GRADIENT_FILL:
					var c = data.readLineGradientStyle();
					fillOptions.fillGradientType = c.type;
					fillOptions.fillGradientColors = c.colors;
					fillOptions.fillGradientAlphas = c.alphas;
					fillOptions.fillGradientRatios = c.ratios;
					
				case BEGIN_BITMAP_FILL:	
					var c = data.readLineBitmapStyle();
					fillOptions.fillBitmapBase64 = getImageBase64(c.bitmap);
					fillOptions.fillBitmapWidth = c.bitmap.width;
					fillOptions.fillBitmapHeight = c.bitmap.height;
					
				case END_FILL:
					if (sub != null) {
						el.appendChild(sub);
						sub = null;
					}

				default:
					data.skip(type);
			}
		}
	}
	
	private static function getImageBase64(b:BitmapData):String {
		return b.image.buffer.__srcCanvas.toDataURL();
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
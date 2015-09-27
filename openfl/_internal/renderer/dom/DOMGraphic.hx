package openfl._internal.renderer.dom;

import js.Browser;
import js.html.Element;
import openfl._internal.renderer.dom.DOMGraphics;

class DOMGraphic {
	private var _el:Element;
	private var _graphic:Element;
	
	public function new(el:Element) {
		_el = el;
	}
	
	public function render(options:GraphicsOptions) {
		if (options.w <= 0 || options.h <= 0) {
			return;
		}
		
		var x:Float = options.x;
		var y:Float = options.y;
		var w:Float = options.w;
		var h:Float = options.h;

		if (options.stroke != null && options.stroke.thickness != null) {
			w += options.stroke.thickness;
			h += options.stroke.thickness;
			options.w = w;
			options.h = h;
		}
		
		_graphic = Browser.document.createElement("div");
		_graphic.classList.add("shape");
		_graphic.style.left = '${x}px';
		_graphic.style.top = '${y}px';
		_graphic.style.width = '${w}px';
		_graphic.style.height = '${h}px';
		
		renderBorder(options);
		renderFill(options);
		
		if (options.radius != null) {
			if (options.radius.x == options.radius.y) {
				_graphic.style.borderRadius = '${Math.fceil(options.radius.x * 0.5)}px';
			} else {
				var rx:Float = Math.fceil(options.radius.x * 0.5);
				var ry:Float = Math.fceil(options.radius.y * 0.5);
				
				var s = '${rx}px ${ry}px';
				_graphic.style.borderTopLeftRadius = s;
				_graphic.style.borderTopRightRadius = s;
				_graphic.style.borderBottomLeftRadius = s;
				_graphic.style.borderBottomRightRadius = s;
			}
		}
		
		_el.appendChild(_graphic);
	}
	
	private function renderBorder(options:GraphicsOptions) {
		if (options.stroke == null) {
			return;
		}
		
		if (options.stroke.thickness != null) {
			var t:Float = options.stroke.thickness * 0.5;
			if (options.stroke.gradient == null && options.stroke.bitmap == null) {
				_graphic.style.border = '${options.stroke.thickness}px solid ${color(options.stroke.color, options.stroke.alpha)}';
				_graphic.style.transform = 'translate(-${t}px, -${t}px)';
				_graphic.style.borderRadius = '${t}px';
			}
			
			if (options.primitive == Primitive.CIRCLE) {
				t = options.w * 0.5;
				_graphic.style.transform = 'translate(-${t}px, -${t}px)';
				_graphic.style.borderRadius = '${t}px';
			} else if (options.primitive == Primitive.ELLIPSE) {
				_graphic.style.transform = 'translate(-${t}px, -${t}px)';
				_graphic.style.borderRadius = "50%";
			}
		}
		
		if (options.stroke.gradient != null || options.stroke.bitmap != null) {
			if (options.primitive == Primitive.RECTANGLE) {
				var t:Float = options.stroke.thickness * 0.5;
				_graphic.style.setProperty("-webkit-clip-path", frameClip(options.w, options.h, options.stroke.thickness), null);
				if (options.stroke.gradient != null) {
					_graphic.style.backgroundImage = gradient(options.stroke.gradient);
				} else if (options.stroke.bitmap != null) {
					_graphic.style.backgroundImage = 'url(${options.stroke.bitmap.base64})';
					_graphic.style.backgroundPosition = '${t}px ${t}px';
				}
				_graphic.style.transform = 'translate(-${t}px, -${t}px)';
				_graphic.style.borderRadius = '${t}px';
			} else if (options.primitive == Primitive.CIRCLE || options.primitive == Primitive.ELLIPSE) {
				var svg:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "svg");
				var strokeId = svgStroke(svg, options.stroke);
				svg.appendChild(svgPrimitive(options.primitive, options.w, options.h, options.stroke.thickness, strokeId));
				
				if (options.primitive == Primitive.ELLIPSE) {
					var t1:Float = Math.ffloor((options.w - options.stroke.thickness) * 0.5);
					var t2:Float = Math.ffloor((options.h - options.stroke.thickness) * 0.5);
					_graphic.style.transform = 'translate(-${t1}px, -${t2}px)';
				} else {
					var t:Float = options.stroke.thickness * 0.5;
					_graphic.style.borderRadius = '${t}px';
				}
				
				_graphic.appendChild(svg);
			}
		}
	}

	private function renderFill(options:GraphicsOptions) {
		if (options.fill == null) {
			return;
		}
		
		if (options.fill.color != null && options.fill.gradient == null) {
			_graphic.style.backgroundColor = color(options.fill.color, options.fill.alpha);
		}
		
		var temp:Element = _graphic;
		if (options.stroke != null) {
			if (options.stroke.gradient != null || options.stroke.bitmap != null) {
				var fill:Element = Browser.document.createElement("div");
				fill.classList.add("shape");
				fill.style.left = '${options.x}px';
				fill.style.top = '${options.y}px';
				fill.style.width = '${options.w}px';
				fill.style.height = '${options.h}px';
				_el.appendChild(fill);
				temp = fill;
			}
		}
		
		if (options.fill.gradient != null) {
			temp.style.backgroundImage = gradient(options.fill.gradient);
		} else if (options.fill.bitmap != null) {
			var t:Float = options.stroke.thickness * 0.5;
			temp.style.backgroundImage = 'url(${options.fill.bitmap.base64})';
			temp.style.backgroundPosition = '${t}px ${t}px';
		}
		
		if (options.primitive == Primitive.CIRCLE) {
			var t:Float = options.w * 0.5;
			temp.style.transform = 'translate(-${t}px, -${t}px)';
			temp.style.borderRadius = '${(options.w * 0.5)}px';
		} else if (options.primitive == Primitive.ELLIPSE) {
			var t:Float = options.stroke.thickness * 0.5;
			// probably not -1 and should be related to transform and border size
			temp.style.transform = 'translate(-1px, -1px)';
			temp.style.borderRadius = '50%';
		} else {
			var t:Float = options.stroke.thickness * 0.5;
			temp.style.transform = 'translate(-${t}px, -${t}px)';
			temp.style.borderRadius = '${t}px';
		}
	}
	
	private static inline function svgPrimitive(primitive:Primitive, w:Float, h:Float, thickness:Float, strokeId:String = null):Element {
		var el:Element = null;
		
		if (primitive == Primitive.CIRCLE) {
			el = Browser.document.createElementNS("http://www.w3.org/2000/svg", "circle");
			el.setAttribute("cx", "" + (w * 0.5));
			el.setAttribute("cy", "" + (h * 0.5));
			el.setAttribute("r", "" + ((w - thickness) * 0.5));
		} else if (primitive == Primitive.ELLIPSE) {
			el = Browser.document.createElementNS("http://www.w3.org/2000/svg", "ellipse");
			el.setAttribute("cx", "" + (w - thickness));
			el.setAttribute("cy", "" + (h - thickness));
			el.setAttribute("rx", "" + ((w - thickness) / 2));
			el.setAttribute("ry", "" + ((h - thickness) / 2));
		}

		el.setAttribute("stroke-width", "" + thickness);
		el.setAttribute("fill", "transparent");
		if (strokeId != null) {
			el.setAttribute("stroke", "url(#" + strokeId + ")");
		}
		
		return el;
	}
	
	private static inline function svgStroke(svg:Element, stroke:StrokeOptions):String {
		var strokeId:String = "stroke" + Std.random(0xFFFFFF);
		var defs:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "defs");
		svg.appendChild(defs);
		
		if (stroke.gradient != null) {
			var linearGradient:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "linearGradient");
			defs.appendChild(linearGradient);
			linearGradient.setAttribute("id", strokeId);
			linearGradient.setAttribute("x1", "-150%");
			linearGradient.setAttribute("y1", "0%");
			linearGradient.setAttribute("x2", "200%");
			linearGradient.setAttribute("y2", "0%");
			
			var stop:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "stop");
			stop.setAttribute("offset", "-150%");
			stop.setAttribute("stop-color", color(stroke.gradient.colors[0], stroke.gradient.alphas[0]));
			linearGradient.appendChild(stop);
			
			var stop:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "stop");
			stop.setAttribute("offset", "200%");
			stop.setAttribute("stop-color", color(stroke.gradient.colors[1], stroke.gradient.alphas[1]));
			linearGradient.appendChild(stop);
		} else if (stroke.bitmap != null) {
			var pattern:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "pattern");
			defs.appendChild(pattern);
			pattern.setAttribute("id", strokeId);
			pattern.setAttribute("patternUnits", "userSpaceOnUse");
			var t:Float = stroke.thickness * 0.5;
			pattern.setAttribute("x", '-${t}');
			pattern.setAttribute("y", '-${t}');
			pattern.setAttribute("height", '${stroke.bitmap.width}');
			pattern.setAttribute("width", '${stroke.bitmap.height}');
			
			var image:Element = Browser.document.createElementNS("http://www.w3.org/2000/svg", "image");
			image.setAttribute("height", '${stroke.bitmap.width}');
			image.setAttribute("width", '${stroke.bitmap.height}');
			image.setAttributeNS("http://www.w3.org/1999/xlink", "href", stroke.bitmap.base64);
			pattern.appendChild(image);
		}
		
		return strokeId;
	}
	
	// TODO: need to beef this function up to handle complex gradients
	private static inline function gradient(g:GradientOptions):String {
		var s = 'linear-gradient(to left, '
				+ '${color(g.colors[1], g.alphas[1])} -150%,'
				+ '${color(g.colors[0], g.alphas[0])} 250%)';
		return s;
	}
	
	private static inline function frameClip(cx:Float, cy:Float, l:Float):String {
		if (l <= 0) {
			return "";
		}
		var cx2:Float = cx - l;
		var cy2:Float = cy - l;
		return 'polygon(0 0,' 
				+ '0 ${cy}px,'
				+ '${l}px ${cy}px,'
				+ '${l}px ${l}px,'
				+ '${cx2}px ${l}px,'
				+ '${cx2}px ${cy2}px,'
				+ '0 ${cy2}px,'
				+ '0 ${cy}px,'
				+ '${cx}px ${cy}px,'
				+ '${cx}px 0)';
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
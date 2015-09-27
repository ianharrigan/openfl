package openfl._internal.renderer.dom;

import js.Browser;
import js.html.Element;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.GradientType;
import openfl.display.Stage;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl._internal.renderer.dom.DOMElement)
@:access(lime.graphics.ImageBuffer)

class DOMHelper {
	public static inline function isComplexGraphics(shape:DisplayObject):Bool {
		var complex:Bool = false;
		if (shape.cacheAsBitmap == true) {
			return true;
		}
		
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
	
	public static inline function createElement(shape:DisplayObject):DOMElement {
		createGlobalCss();
		
		var el:Element = Browser.document.createElement("div");
		var type:String = "shape";
		el.classList.add(type);
		if (Std.is(shape.parent, Stage)) {
			Browser.document.body.appendChild(el);
		} else { // NMEPreloader is an issue here
			if (shape.parent.__element != null) {
				var parentEl:Element = shape.parent.__element._el;
				if (parentEl != null) {
					parentEl.appendChild(el);
				}
			}
		}
		return new DOMElement(el);
	}
	
	public static inline function applyStyle(shape:DisplayObject) {
		var domElement:DOMElement = shape.__element;
		if (domElement != null) {
			domElement.applyStyle(shape);
		}
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
	
	public static function getImageBase64(b:BitmapData):String {
		return b.image.buffer.__srcCanvas.toDataURL();
	}
}
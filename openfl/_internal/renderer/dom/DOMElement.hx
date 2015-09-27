package openfl._internal.renderer.dom;

import js.html.Element;
import openfl.display.DisplayObject;
import openfl.display.Stage;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
class DOMElement {
	public var parent:DOMElement;
	
	private var _el:Element;
	
	private var _x:Float;
	private var _y:Float;
	private var _width:Float;
	private var _height:Float;
	
	private var _graphics:DOMGraphics;
	
	public function new(el:Element) {
		_el = el;
		_graphics = new DOMGraphics();
	}
	
	public function applyStyle(shape:DisplayObject):Void {
		if (_el == null) {
			return;
		}
		
		var x:Float = shape.x;
		var y:Float = shape.y;
		var cx:Float = shape.__graphics.__bounds.width;
		var cy:Float = shape.__graphics.__bounds.height;
		// TODO: see if we can work out graphics changing also
		if (x == _x && y == _y && cx == _width && cy == _height) { // nothings changed?
			trace("nothings changed?");
		}
		
		if (x != _x) {
			_el.style.left = '${x}px';
			_x = x;
		}
		
		if (y != _y) {
			_el.style.top = '${y}px';
			_y = y;
		}
		
		if (cx != _width) {
			_el.style.width = '${cx}px';
			_width = cx;
		}
		
		if (cy != _height) {
			_el.style.height = '${cy}px';
			_height = cy;
		}

		// just for testing
		if (Std.is(shape.parent, Stage)) {
			_el.style.left = shape.x + 400 + "px";
		}
		
		_graphics.render(shape);
	}
}